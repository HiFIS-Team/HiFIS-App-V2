part of 'schedule_screen.dart';

// ── 데이터 ──

/// 일정 종류 — 색으로 종류를 구분한다
///
/// 서버는 종류를 enum 이 아니라 **자유 문자열**로 받는다. [label] 을 그대로
/// 주고받으므로 라벨을 고치면 이미 쌓인 일정이 '기타'로 떨어진다.
enum Kind {
  meeting('회의'),
  lesson('수업'),
  event('이벤트'),
  off('휴무'),
  etc('기타');

  const Kind(this.label);

  final String label;

  static Kind parse(String? value) =>
      Kind.values.firstWhere((k) => k.label == value, orElse: () => Kind.etc);

  Color get color => switch (this) {
    Kind.meeting => AppColors.primary,
    Kind.lesson => AppColors.success,
    Kind.event => AppColors.warning,
    Kind.off => AppColors.gray400,
    Kind.etc => AppColors.violet,
  };
}

/// 일정 한 건
class Event {
  Event({
    required this.title,
    required this.date,
    DateTime? until,
    this.id,
    this.ownerId,
    this.kind = Kind.meeting,
    this.start,
    this.end,
    this.place = '',
    this.memo = '',
    this.members = const [],
    this.pending = false,
  }) : until = until ?? date;

  /// 서버 uuid — null 이면 아직 안 올린 것 (폼이 막 돌려준 값)
  final String? id;

  /// 만든 사람 — 본인이나 관리자만 고칠 수 있다 ([canEdit])
  final String? ownerId;

  final String title;

  /// 시작하는 날 (시각은 start/end)
  final DateTime date;

  /// 끝나는 날 — 하루짜리면 [date]와 같다
  final DateTime until;

  final Kind kind;

  /// null이면 종일 일정
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// 장소 (회의실·GX룸 같은 것)
  final String place;

  /// 참석자 **이름** — 서버에는 uuid 로 오간다 (`_idsOf` · `_namesOf`)
  final List<String> members;

  final String memo;

  /// 승인 대기 중인지 — MASTER·ADMIN 이 아닌 사람이 올리면 켜진다.
  /// 서버가 걸러 주므로 **올린 사람과 MASTER·ADMIN 에게만** 온다.
  final bool pending;

  /// 수정 폼에서 삭제를 눌렀다는 표시
  bool deleted = false;

  /// 수정 폼에서 승인·반려를 눌렀다는 표시 ([deleted] 와 같은 전달용 값)
  EventDecision? decision;

  /// 반려 사유 — 신청자에게 알림으로 간다
  String? rejectReason;

  bool get allDay => start == null;

  /// 여러 날에 걸치는지
  bool get spans => !_isSameDay(date, until);

  /// 하루짜리는 예전 그대로 시각만, 걸치는 것만 날짜를 붙인다
  String get timeLabel {
    if (!spans) {
      return allDay ? '종일' : '${_time(start!)} ~ ${_time(end ?? start!)}';
    }
    final from = '${date.month}.${date.day}';
    final to = '${until.month}.${until.day}';
    if (allDay) return '$from ~ $to';
    return '$from ${_time(start!)} ~ $to ${_time(end ?? start!)}';
  }

  /// 고치거나 지울 수 있는지 — 서버 `_get_owned` 와 같은 기준이다
  bool get canEdit =>
      id == null ||
      ownerId == null ||
      ownerId == currentUser?.id ||
      myRole.strong;
}

/// 받아 둔 일정. 달을 옮겨도 유지되도록 모듈 전역으로 둔다.
final events = <Event>[];

/// 받아 본 달 (`2026-8`) — 오갈 때마다 다시 받지 않는다
final _loadedMonths = <String>{};

/// 그 달 달력에 그려질 것들을 받는다 — 한 번 받은 달은 넘어간다
///
/// 달력이 **그 달 1일이 낀 주부터** 그려서 앞뒤 달 며칠이 같이 보인다.
/// 그 칸이 비지 않게 앞뒤로 한 주씩 넓혀 받는다.
Future<void> _loadMonth(DateTime month) async {
  final key = '${month.year}-${month.month}';
  if (_loadedMonths.contains(key)) return;
  final rows = await EventApi.list(
    from: DateTime(month.year, month.month).subtract(Duration(days: 7)),
    to: DateTime(
      month.year,
      month.month + 1,
      0,
      23,
      59,
      59,
    ).add(Duration(days: 7)),
  );
  // 넓혀 받은 만큼 옆 달과 겹친다 — 같은 걸 두 번 넣지 않게 id 로 거른다
  final known = {for (final event in events) ?event.id};
  events.addAll([
    for (final row in rows)
      if (!known.contains(row.id)) _fromServer(row),
  ]);
  _loadedMonths.add(key);
}

/// 서버 일정 → 화면 모델
///
/// 색은 서버 값을 안 쓴다 — 앱은 종류에서 색을 뽑는다
Event _fromServer(CalendarEvent row) {
  final start = row.startAt;
  final end = row.endAt;
  return Event(
    id: row.id,
    ownerId: row.ownerId,
    title: row.title,
    date: DateTime(start.year, start.month, start.day),
    until: DateTime(end.year, end.month, end.day),
    kind: Kind.parse(row.category),
    start: row.allDay ? null : TimeOfDay.fromDateTime(start),
    end: row.allDay ? null : TimeOfDay.fromDateTime(end),
    place: row.place ?? '',
    members: _namesOf(row.attendeeIds),
    memo: row.memo ?? '',
    pending: row.pending,
  );
}

/// 참석자 uuid → 이름
///
/// 폼과 아바타 줄이 아직 이름을 사람 키로 쓴다 (backend-gap.md 10번).
/// 명단에 없는 사람(퇴사 등)은 뺀다 — 이름을 모르면 아바타를 못 그린다.
List<String> _namesOf(List<String> ids) => [
  for (final id in ids) ?StaffDirectory.instance.byId(id)?.name,
];

/// 이름 → 참석자 uuid
///
/// 서버 명단에 없는 이름(목업으로 남은 사람)은 보낼 id 가 없어서 빠진다.
List<String> _idsOf(List<String> names) => [
  for (final name in names) ?StaffDirectory.instance.byName(name)?.id,
];

/// 화면 모델 → 서버가 받는 시작·끝
///
/// 종일은 `allDay` 로 따로 보내지만 시각 자체는 여전히 있어야 한다
/// (서버가 `startAt`·`endAt` 을 필수로 받고, 달력도 그날에 그린다).
(DateTime, DateTime) _range(Event event) {
  final from = event.date;
  final to = event.until;
  if (event.allDay) {
    return (
      DateTime(from.year, from.month, from.day),
      DateTime(to.year, to.month, to.day, 23, 59),
    );
  }
  final start = event.start!;
  final end = event.end ?? start;
  return (
    DateTime(from.year, from.month, from.day, start.hour, start.minute),
    DateTime(to.year, to.month, to.day, end.hour, end.minute),
  );
}

/// 서버는 색을 `#RRGGBB` 로 받는다
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 공개 범위 — 앱에 아직 개념이 없다. 서버가 필수로 받아서 한 값으로만 보낸다
const _scope = '전사';

/// 새 일정을 올린다
Future<Event> _createEvent(Event draft) async {
  final (startAt, endAt) = _range(draft);
  final created = await EventApi.create(
    title: draft.title,
    startAt: startAt,
    endAt: endAt,
    allDay: draft.allDay,
    category: draft.kind.label,
    scope: _scope,
    color: _hexOf(draft.kind.color),
    place: draft.place.isEmpty ? null : draft.place,
    attendeeIds: _idsOf(draft.members),
    memo: draft.memo.isEmpty ? null : draft.memo,
  );
  return _fromServer(created);
}

/// 고친 내용을 올린다 — 서버가 돌려준 값으로 갈아끼운다
Future<Event> _updateEvent(String id, Event edited) async {
  final (startAt, endAt) = _range(edited);
  final saved = await EventApi.update(
    id,
    title: edited.title,
    startAt: startAt,
    endAt: endAt,
    allDay: edited.allDay,
    category: edited.kind.label,
    color: _hexOf(edited.kind.color),
    // 비운 장소·메모도 넘겨야 지워진다 (안 넘기면 서버가 그대로 둔다)
    place: edited.place,
    attendeeIds: _idsOf(edited.members),
    memo: edited.memo,
  );
  return _fromServer(saved);
}

/// 그날 일정 — 종일이 먼저, 그다음 시작 시각순
///
/// 여러 날에 걸치는 일정은 **걸치는 날마다** 나온다.
List<Event> eventsOn(DateTime date) =>
    events.where((e) => _covers(e, date)).toList()..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      if (a.allDay) return 0;
      return _minutes(a.start!).compareTo(_minutes(b.start!));
    });

// ── 표시용 계산 ──

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 그 일정이 이 날을 덮는지 — 시작일과 종료일 사이(양끝 포함)
bool _covers(Event event, DateTime day) {
  final target = _dayOf(day);
  return !target.isBefore(_dayOf(event.date)) &&
      !target.isAfter(_dayOf(event.until));
}

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// '8.10 (월)' 형태 — 폼의 날짜 버튼
String _dayLabel(DateTime date) =>
    '${date.month}.${date.day} (${_weekdays[date.weekday % 7]})';

/// '09:30' 형태
String _time(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
