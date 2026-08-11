import '../client/api_client.dart';

/// 알림 종류 (서버 `NotificationOut.type`)
///
/// 서버가 문자열로 주고 종류가 늘 수 있어서, 모르는 값은 [other] 로 떨어진다.
/// 화면은 이 값으로 아이콘·색을 고른다.
enum NotificationKind {
  attendance('ATTENDANCE'),
  leave('LEAVE'),
  notice('NOTICE'),
  chat('CHAT'),
  approval('APPROVAL'),
  project('PROJECT'),
  payroll('PAYROLL'),
  schedule('SCHEDULE'),
  ranking('RANKING'),
  // 아래 둘은 **대표·관리자만** 받는다 (회의록 작성 · 직원 가입·퇴사)
  meeting('MEETING'),
  staff('STAFF'),
  other('');

  const NotificationKind(this.wire);

  final String wire;

  static NotificationKind parse(String? value) => NotificationKind.values
      .firstWhere((k) => k.wire == value, orElse: () => NotificationKind.other);
}

/// 알림 한 건 (서버 `NotificationOut`)
///
/// 이름을 `Notification` 으로 두면 Flutter 위젯 알림과 겹쳐서 앞에 `App` 을 붙였다.
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.read,
    required this.createdAt,
    this.body,
    this.link,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.parse(json['type'] as String?),
        title: json['title'] as String,
        body: json['body'] as String?,
        link: json['link'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  final String id;
  final NotificationKind kind;
  final String title;

  /// 한 줄 더 붙는 설명 (`삭제테스트 · 테스트매니저` 처럼)
  final String? body;

  /// 눌렀을 때 갈 곳 — `/notices/{id}` `/projects` 처럼 앱 안 주소다.
  /// 서버가 공지·사내톡·결재는 **id 까지** 실어 준다
  final String? link;

  /// 읽음 — 화면에서 바꾸므로 가변
  bool read;

  final DateTime createdAt;
}

/// `/notifications` — 개인 알림함
///
/// **본인 것만 온다.** 남의 알림을 읽거나 지울 방법은 없다.
class NotificationApi {
  NotificationApi._();

  static final _client = ApiClient.instance;

  /// 최신순. [read] 를 주면 그 상태만 걸러서 준다
  static Future<List<AppNotification>> list({bool? read}) async {
    final rows = await _client.getList(
      '/notifications',
      query: {'read': ?read},
    );
    return [
      for (final row in rows)
        AppNotification.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 한 건 읽음 처리
  static Future<void> markRead(String id) =>
      _client.post('/notifications/$id/read').then((_) {});

  /// 전부 읽음 처리 — 안 읽은 것만 바뀐다
  static Future<void> markAllRead() =>
      _client.post('/notifications/read-all').then((_) {});

  /// 이 기기로 푸시를 보내 달라고 등록한다 — 켤 때마다 불러도 된다 (갱신만 됨)
  ///
  /// [sandbox] 는 애플의 **개발용 푸시 서버**를 쓰는 빌드인가다. 네이티브가
  /// 서명에 박힌 값을 읽어 넘겨 준다 (디버그 빌드인지와 다르다).
  static Future<void> registerDevice({
    required String token,
    required String platform,
    required bool sandbox,
  }) => _client
      .post(
        '/push/devices',
        body: {'token': token, 'platform': platform, 'sandbox': sandbox},
      )
      .then((_) {});

  /// 로그아웃할 때 지운다 — 안 지우면 이 기기로 앞사람 알림이 계속 간다
  static Future<void> unregisterDevice(String token) =>
      _client.delete('/push/devices/$token');
}
