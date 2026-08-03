import 'api_client.dart';

/// 일정 한 건 (서버 `EventOut`)
///
/// 이름을 `Event` 로 두면 화면 쪽 모델과 겹쳐서 `Calendar` 를 붙였다.
///
/// [category] · [scope] · [color] 는 **서버가 enum 이 아니라 자유 문자열로**
/// 받는다. 앱은 종류 이름(`회의` `수업` …)을 그대로 넣는다 — 서버에 이미
/// 그렇게 쌓인 값이 있어서 표기를 맞췄다.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.category,
    required this.scope,
    required this.color,
    required this.attendeeIds,
    required this.ownerId,
    required this.createdAt,
    this.place,
    this.memo,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    startAt: _time(json['startAt'])!,
    endAt: _time(json['endAt'])!,
    allDay: json['allDay'] as bool? ?? false,
    category: json['category'] as String? ?? '',
    scope: json['scope'] as String? ?? '',
    color: json['color'] as String? ?? '',
    place: json['place'] as String?,
    attendeeIds: [
      for (final id in (json['attendeeIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
    memo: json['memo'] as String?,
    ownerId: json['ownerId'] as String,
    createdAt: _time(json['createdAt'])!,
  );

  final String id;
  final String title;

  final DateTime startAt;
  final DateTime endAt;

  /// 종일 일정인지 — 예전에는 `00:00 ~ 23:59` 로 흉내 냈는데 이제 서버가 담는다
  final bool allDay;

  /// 종류 (`회의` `수업` `이벤트` `휴무` `기타`)
  final String category;

  /// 공개 범위 — 앱에는 아직 개념이 없어서 `전사` 로만 보낸다
  final String scope;

  /// `#RRGGBB`. 앱은 종류에서 색을 뽑아 쓰므로 보낼 때만 채운다
  final String color;

  /// 회의실·GX룸 같은 자리
  final String? place;

  /// 참석자 uuid — 프로젝트 `assigneeIds` 와 같은 모양이다
  final List<String> attendeeIds;

  final String? memo;

  /// 만든 사람 — **본인이나 관리자만 고치고 지울 수 있다**
  final String ownerId;

  final DateTime createdAt;
}

DateTime? _time(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

/// `/events` — 일정
///
/// 작성은 전 직원, 수정·삭제는 **만든 사람 또는 관리자·점장**이다.
/// 앱도 같은 기준으로 폼을 잠근다 — 안 그러면 저장할 때 403 이 난다.
class EventApi {
  EventApi._();

  static final _client = ApiClient.instance;

  /// 시작 시각순. [from]·[to] 는 **겹치는 것**을 다 준다 —
  /// 7월에 시작해 8월까지 가는 일정도 8월 조회에 잡힌다
  static Future<List<CalendarEvent>> list({
    DateTime? from,
    DateTime? to,
    String? scope,
  }) async {
    final rows = await _client.getList(
      '/events',
      query: {
        'from': ?from?.toUtc().toIso8601String(),
        'to': ?to?.toUtc().toIso8601String(),
        'scope': ?scope,
      },
    );
    return [
      for (final row in rows)
        CalendarEvent.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<CalendarEvent> create({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required String category,
    required String scope,
    required String color,
    bool allDay = false,
    String? place,
    List<String> attendeeIds = const [],
    String? memo,
  }) async {
    final data = await _client.post(
      '/events',
      body: {
        'title': title,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        'allDay': allDay,
        'category': category,
        'scope': scope,
        'color': color,
        'place': ?place,
        'attendeeIds': attendeeIds,
        'memo': ?memo,
      },
    );
    return CalendarEvent.fromJson(data!);
  }

  /// 고치기 — 넘긴 값만 바뀐다
  static Future<CalendarEvent> update(
    String id, {
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    String? category,
    String? scope,
    String? color,
    String? place,
    List<String>? attendeeIds,
    String? memo,
  }) async {
    final data = await _client.patch(
      '/events/$id',
      body: {
        'title': ?title,
        'startAt': ?startAt?.toUtc().toIso8601String(),
        'endAt': ?endAt?.toUtc().toIso8601String(),
        'allDay': ?allDay,
        'category': ?category,
        'scope': ?scope,
        'color': ?color,
        'place': ?place,
        'attendeeIds': ?attendeeIds,
        'memo': ?memo,
      },
    );
    return CalendarEvent.fromJson(data!);
  }

  static Future<void> delete(String id) => _client.delete('/events/$id');
}
