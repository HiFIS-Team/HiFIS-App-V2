import '../../data/data_signal.dart';
import '../client/api_client.dart';

/// 문서 전체의 진행 상태 (서버 `ApprovalStatus`)
enum ApprovalStatus {
  inProgress('IN_PROGRESS'),
  approved('APPROVED'),
  rejected('REJECTED'),

  /// 신청자가 스스로 물린 것 — 결재선 이력은 남는다
  withdrawn('WITHDRAWN');

  const ApprovalStatus(this.wire);

  final String wire;

  static ApprovalStatus parse(String? value) =>
      ApprovalStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ApprovalStatus.inProgress,
      );
}

/// 결재선 한 칸의 상태 (서버 `ApprovalStepStatus`)
enum ApprovalStepStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const ApprovalStepStatus(this.wire);

  final String wire;

  static ApprovalStepStatus parse(String? value) =>
      ApprovalStepStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ApprovalStepStatus.pending,
      );
}

/// 어느 함에서 꺼낼지 (서버 `box` 쿼리)
///
/// **서버는 '전체 결재'를 주지 않는다.** 남의 결재를 들여다볼 수 없어서
/// 내가 얽힌 것만 세 갈래로 준다. 앱 목록은 셋을 합쳐서 쓴다.
enum ApprovalBox {
  /// 내가 올린 것
  mine('mine'),

  /// 내 결재 차례인 것
  inbox('inbox'),

  /// 내가 승인·반려한 것
  decided('decided');

  const ApprovalBox(this.wire);

  final String wire;
}

/// 결재선 한 칸 (서버 `ApprovalStep`)
class ApprovalStep {
  ApprovalStep({
    required this.approverId,
    required this.status,
    this.comment,
    this.actedAt,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> json) => ApprovalStep(
    approverId: json['approverId'] as String,
    status: ApprovalStepStatus.parse(json['status'] as String?),
    comment: json['comment'] as String?,
    actedAt: _time(json['actedAt']),
  );

  final String approverId;
  final ApprovalStepStatus status;

  /// 처리하며 남긴 의견
  final String? comment;
  final DateTime? actedAt;
}

/// 결재 문서에 달린 댓글 (서버 `ApprovalComment`)
class ApprovalComment {
  ApprovalComment({
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  factory ApprovalComment.fromJson(Map<String, dynamic> json) =>
      ApprovalComment(
        authorId: json['authorId'] as String,
        body: json['body'] as String? ?? '',
        createdAt: _time(json['createdAt'])!,
      );

  final String authorId;
  final String body;
  final DateTime createdAt;
}

/// 결재 문서 (서버 `ApprovalOut`)
class Approval {
  Approval({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.requesterId,
    required this.approverIds,
    required this.steps,
    required this.status,
    required this.comments,
    required this.createdAt,
    this.amount,
    this.startDate,
    this.endDate,
    this.place,
    this.currentApproverId,
  });

  factory Approval.fromJson(Map<String, dynamic> json) => Approval(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    amount: json['amount'] as int?,
    startDate: _time(json['startDate']),
    endDate: _time(json['endDate']),
    place: json['place'] as String?,
    requesterId: json['requesterId'] as String,
    approverIds: [
      for (final id in (json['approverIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
    steps: [
      for (final row in (json['steps'] as List<dynamic>? ?? const []))
        ApprovalStep.fromJson((row as Map).cast<String, dynamic>()),
    ],
    status: ApprovalStatus.parse(json['status'] as String?),
    currentApproverId: json['currentApproverId'] as String?,
    comments: [
      for (final row in (json['comments'] as List<dynamic>? ?? const []))
        ApprovalComment.fromJson((row as Map).cast<String, dynamic>()),
    ],
    createdAt: _time(json['createdAt'])!,
  );

  final String id;

  /// 결재 종류 — 서버가 enum 이 아니라 자유 문자열로 받는다
  final String kind;

  final String title;
  final String content;

  final int? amount;

  /// 외근·출장처럼 기간이 있는 결재에 쓴다
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;

  final String requesterId;

  /// **순서대로** 결재하는 사람들. 앞사람이 승인해야 뒷사람 차례가 온다
  final List<String> approverIds;

  final List<ApprovalStep> steps;
  final ApprovalStatus status;

  /// 지금 결재할 차례인 사람 — 끝났으면 null
  final String? currentApproverId;

  /// 옛 결재 댓글 — **새 앱은 안 읽는다** (2026-08-31)
  ///
  /// 결재 댓글이 공용 `/comments` 로 옮겨 갔다. 서버는 이 칸을 옛 빌드용으로
  /// 그대로 두고 새 댓글은 안 쌓는다. 새로 붙은 것은 늘 비어 있다.
  final List<ApprovalComment> comments;
  final DateTime createdAt;

  /// 내가 지금 승인·반려할 수 있는가
  bool myTurn(String? myId) =>
      myId != null &&
      status == ApprovalStatus.inProgress &&
      currentApproverId == myId;

  /// 내가 물릴 수 있는가 — 신청자 본인이고 아직 진행 중일 때
  bool canWithdraw(String? myId) =>
      myId != null &&
      status == ApprovalStatus.inProgress &&
      requesterId == myId;

  /// 마지막으로 처리된 결재선 칸 — 승인·반려 사유를 여기서 꺼낸다
  ApprovalStep? get lastActed {
    ApprovalStep? last;
    for (final step in steps) {
      if (step.status == ApprovalStepStatus.pending) continue;
      if (last == null ||
          (step.actedAt != null &&
              last.actedAt != null &&
              step.actedAt!.isAfter(last.actedAt!))) {
        last = step;
      }
    }
    return last;
  }
}

DateTime? _time(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

/// `/approvals` — 전자결재
///
/// **당사자만 본다.** 신청자·결재선에 있는 사람과 관리자(ADMIN·MASTER)만
/// 열람하고 댓글을 달 수 있다 (서버 `_require_participant`).
class ApprovalApi {
  ApprovalApi._();

  static final _client = ApiClient.instance;

  /// 함 하나를 받는다 — 최신순
  static Future<List<Approval>> list(ApprovalBox box) async {
    final rows = await _client.getList('/approvals', query: {'box': box.wire});
    return [
      for (final row in rows)
        Approval.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 결재 올리기 — [approverIds] 는 **순서가 곧 결재선**이고 최소 한 명이다
  static Future<Approval> create({
    required String kind,
    required String title,
    required String content,
    required List<String> approverIds,
    int? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? place,
  }) async {
    final data = await _client.post(
      '/approvals',
      body: {
        'kind': kind,
        'title': title,
        'content': content,
        'approverIds': approverIds,
        'amount': ?amount,
        'startDate': ?_date(startDate),
        'endDate': ?_date(endDate),
        'place': ?place,
      },
    );
    notifyApprovalChanged();
    return Approval.fromJson(data!);
  }

  /// 승인 — **내 차례가 아니면 403**(`NOT_YOUR_TURN`).
  /// 마지막 결재자면 문서가 최종 승인되고, 아니면 다음 사람에게 넘어간다
  static Future<Approval> approve(String id, {String? comment}) async {
    final data = await _client.post(
      '/approvals/$id/approve',
      body: {'comment': ?comment},
    );
    notifyApprovalChanged();
    return Approval.fromJson(data!);
  }

  /// 반려 — 한 명이라도 반려하면 거기서 끝난다
  static Future<Approval> reject(String id, {String? comment}) async {
    final data = await _client.post(
      '/approvals/$id/reject',
      body: {'comment': ?comment},
    );
    notifyApprovalChanged();
    return Approval.fromJson(data!);
  }

  /// 회수 — **신청자 본인만**, 진행 중일 때만
  static Future<Approval> withdraw(String id) async {
    final data = await _client.post('/approvals/$id/withdraw');
    notifyApprovalChanged();
    return Approval.fromJson(data!);
  }
}

/// 서버가 `startDate`·`endDate` 를 날짜(`YYYY-MM-DD`)로만 받는다
String? _date(DateTime? time) => time == null
    ? null
    : '${time.year.toString().padLeft(4, '0')}-'
          '${time.month.toString().padLeft(2, '0')}-'
          '${time.day.toString().padLeft(2, '0')}';
