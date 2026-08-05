part of 'approval_screen.dart';

// ── 데이터 ──

/// 결재 종류
///
/// 서버는 종류를 enum 이 아니라 **자유 문자열**로 받는다. [label] 을 그대로
/// 주고받으므로 라벨을 고치면 이미 올라간 결재가 '기타 품의'로 떨어진다.
enum _Kind {
  expense('지출결의', Icons.credit_card_rounded),
  purchase('구매 요청', Icons.shopping_cart_rounded),
  supply('비품 신청', Icons.inventory_2_rounded),
  trip('외근·출장', Icons.flight_rounded, needsWhen: true),
  shift('근무 변경', Icons.schedule_rounded, needsWhen: true),
  etc('기타 품의', Icons.description_rounded);

  const _Kind(this.label, this.icon, {this.needsWhen = false});

  final String label;
  final IconData icon;

  /// 언제·어디로 가는지를 받아야 하는 종류인가
  ///
  /// 지출결의·구매 요청에는 기간이 없다. 모든 종류에 칸을 세우면
  /// 안 쓰는 자리가 늘 비어 있게 된다.
  final bool needsWhen;

  static _Kind parse(String? value) =>
      _Kind.values.firstWhere((k) => k.label == value, orElse: () => _Kind.etc);
}

/// 처리 상태 (목록 탭 순서와 같다)
enum _State {
  pending('대기'),
  approved('승인'),
  rejected('반려'),

  /// 신청자가 스스로 물린 것 — 반려와 섞이면 안 돼서 따로 둔다
  withdrawn('회수');

  const _State(this.label);

  final String label;

  /// 목록 탭에 올리는 것 — 회수는 흔치 않아 탭을 늘리지 않고 '반려' 칸에 같이 둔다
  static const tabs = [_State.pending, _State.approved, _State.rejected];

  Color get color => switch (this) {
    _State.pending => AppColors.warning,
    _State.approved => AppColors.success,
    _State.rejected => AppColors.error,
    _State.withdrawn => AppColors.gray400,
  };

  static _State of(ApprovalStatus status) => switch (status) {
    ApprovalStatus.inProgress => _State.pending,
    ApprovalStatus.approved => _State.approved,
    ApprovalStatus.rejected => _State.rejected,
    ApprovalStatus.withdrawn => _State.withdrawn,
  };
}

/// 결재선 기본값 — 대표에게 올린다
///
/// 서버는 여러 명을 순서대로 세울 수 있지만 앱에는 아직 결재선을 짜는 자리가
/// 없다 (backend-gap.md 48번). 명단에 대표가 없으면 못 올린다.
Employee? get _defaultApprover {
  final people = StaffDirectory.instance.employees;
  for (final person in people) {
    if (person.role == Role.master) return person;
  }
  return null;
}

/// 폼이 돌려주는 것 — 아직 서버에 없어서 id·결재선이 없다
class _Draft {
  _Draft({
    required this.kind,
    required this.title,
    required this.amount,
    required this.body,
    this.startDate,
    this.endDate,
    this.place,
  });

  final _Kind kind;
  final String title;
  final int amount;
  final String body;

  /// 외근·출장, 근무 변경일 때만 채워진다
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;
}

/// 결재 문서 한 건
class _Doc {
  _Doc({
    required this.id,
    required this.kind,
    required this.title,
    required this.amount,
    required this.body,
    required this.writerId,
    required this.date,
    required this.state,
    required this.approverIds,
    required this.steps,
    this.currentApproverId,
    this.startDate,
    this.endDate,
    this.place,
  });

  final String id;
  final _Kind kind;
  final String title;
  final int amount;
  final String body;

  /// 외근·출장, 근무 변경에만 있다 (없으면 상세에서 그 줄을 안 그린다)
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;

  /// 신청자 uuid
  final String writerId;

  final DateTime date;

  /// 처리 상태 — 결재선을 다 돌면 바뀐다
  final _State state;

  final List<String> approverIds;
  final List<ApprovalStep> steps;
  final String? currentApproverId;

  String get writer => _nameOf(writerId);

  /// 마지막으로 처리한 사람이 남긴 의견
  ApprovalStep? get lastActed {
    ApprovalStep? last;
    for (final step in steps) {
      if (step.status == ApprovalStepStatus.pending) continue;
      last = step;
    }
    return last;
  }

  bool get myTurn =>
      state == _State.pending && currentApproverId == currentUser?.id;

  bool get canWithdraw =>
      state == _State.pending && writerId == currentUser?.id;
}

/// 받아 둔 결재. 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _docs = <_Doc>[];

bool _docsLoaded = false;

/// 서버는 '전체 결재'를 안 준다 — 내가 얽힌 세 함을 합쳐서 목록을 만든다
///
/// 그래서 이 목록은 '모든 결재'가 아니라 **내가 올렸거나 내가 결재하는 것**이다.
/// 남의 결재는 애초에 열람 권한이 없다 (서버 `_require_participant`).
Future<void> _loadDocs() async {
  final boxes = await Future.wait([
    for (final box in ApprovalBox.values) ApprovalApi.list(box),
  ]);
  // 함끼리 겹친다 — 내가 올리고 내가 결재하는 문서는 mine·inbox 둘 다에 있다
  final merged = <String, Approval>{};
  for (final rows in boxes) {
    for (final row in rows) {
      merged[row.id] = row;
    }
  }
  _docs
    ..clear()
    ..addAll([for (final row in merged.values) _fromServer(row)]);
  _docsLoaded = true;
}

_Doc _fromServer(Approval row) => _Doc(
  id: row.id,
  kind: _Kind.parse(row.kind),
  title: row.title,
  amount: row.amount ?? 0,
  body: row.content,
  writerId: row.requesterId,
  date: row.createdAt,
  state: _State.of(row.status),
  approverIds: row.approverIds,
  steps: row.steps,
  currentApproverId: row.currentApproverId,
  startDate: row.startDate,
  endDate: row.endDate,
  place: row.place,
);

/// 목록에서 바뀐 한 건만 갈아끼운다
void _replace(_Doc doc) {
  final index = _docs.indexWhere((d) => d.id == doc.id);
  if (index >= 0) _docs[index] = doc;
}

/// uuid → 이름. 명단에 없으면(퇴사자 등) '알 수 없음'
String _nameOf(String? id) {
  if (id == null) return '알 수 없음';
  final name = StaffDirectory.instance.byId(id)?.name;
  return name == null || name.isEmpty ? '알 수 없음' : name;
}

/// uuid → 직급 라벨. 이름 옆에 붙인다
String _rankOf(String? id) {
  if (id == null) return '';
  return StaffDirectory.instance.byId(id)?.rank.label ?? '';
}

/// 처리한 사람과 처리한 날 — '대표 · 8.3' 꼴
///
/// 회수는 결재선에 안 남으니 올린 사람을 쓴다
String _decidedBy(_Doc doc) {
  if (doc.state == _State.withdrawn) {
    return '${doc.writer} ${_rankOf(doc.writerId)}';
  }
  final step = doc.lastActed;
  if (step == null) return '';
  final who = '${_nameOf(step.approverId)} ${_rankOf(step.approverId)}'.trim();
  final when = step.actedAt;
  return when == null ? who : '$who · ${_date(when)}';
}

// ── 표시용 계산 ──

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';

/// 기간 한 줄 — 하루짜리면 날짜 하나만
String _period(DateTime start, DateTime? end) {
  final from = '${start.year}. ${start.month}. ${start.day}.';
  if (end == null ||
      (end.year == start.year &&
          end.month == start.month &&
          end.day == start.day)) {
    return from;
  }
  return '$from ~ ${end.year}. ${end.month}. ${end.day}.';
}

/// '1,240,000원' 형태
String _won(int amount) => '${_comma(amount)}원';

String _comma(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
