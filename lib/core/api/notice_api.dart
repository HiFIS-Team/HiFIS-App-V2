import 'api_client.dart';

/// 공지 (서버 `NoticeOut`)
///
/// **읽음 상태가 없다.** 누가 확인했는지, 내가 읽었는지를 서버가 안 준다
/// (backend-gap.md 35번). 앱이 화면 안에서만 들고 있다가 껐다 켜면 지워진다.
class Notice {
  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.authorId,
    required this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    pinned: json['pinned'] as bool? ?? false,
    authorId: json['authorId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String title;
  final String body;

  /// 목록 맨 위에 고정
  final bool pinned;

  /// 작성자 uuid — 이름은 `StaffDirectory` 에서 찾는다
  final String authorId;

  final DateTime createdAt;
}

/// `/notices` — 공지
///
/// **쓰기 권한이 갈린다.** 작성은 전 직원이 할 수 있는데(공지로 서로 요청·알림을
/// 주고받는 구조라 그렇다) 남의 글을 고치거나 지우는 건 관리자·점장만 된다.
/// 앱도 같은 기준으로 버튼을 감춘다 — 안 그러면 눌렀을 때 403 이 난다.
class NoticeApi {
  NoticeApi._();

  static final _client = ApiClient.instance;

  /// 전체 목록 — 서버가 고정 먼저, 그 안에서 최신순으로 정렬해 준다
  static Future<List<Notice>> list() async {
    final rows = await _client.getList('/notices');
    return [
      for (final row in rows)
        Notice.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 새 공지 — 작성자를 뺀 재직자 전원에게 알림이 나간다
  static Future<Notice> create({
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    final data = await _client.post(
      '/notices',
      body: {'title': title, 'body': body, 'pinned': pinned},
    );
    return Notice.fromJson(data!);
  }

  /// 고치기 (ADMIN·MANAGER) — 넘긴 값만 바뀐다
  static Future<Notice> update(
    String id, {
    String? title,
    String? body,
    bool? pinned,
  }) async {
    final data = await _client.patch(
      '/notices/$id',
      body: {'title': ?title, 'body': ?body, 'pinned': ?pinned},
    );
    return Notice.fromJson(data!);
  }

  /// 지우기 (ADMIN·MANAGER) — 달려 있던 이모지 반응도 같이 지워진다
  static Future<void> delete(String id) => _client.delete('/notices/$id');
}
