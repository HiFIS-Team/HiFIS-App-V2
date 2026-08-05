import '../client/api_client.dart';
import 'reaction_api.dart';

export 'reaction_api.dart' show ReactionAgg, ReactionApi, ReactionTarget;

/// 공지 (서버 `NoticeOut`)
class Notice {
  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.authorId,
    required this.createdAt,
    required this.readByMe,
    required this.readCount,
    required this.reactions,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    pinned: json['pinned'] as bool? ?? false,
    authorId: json['authorId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    readByMe: json['readByMe'] as bool? ?? false,
    readCount: json['readCount'] as int? ?? 0,
    reactions: reactionsFromJson(json['reactions']),
  );

  final String id;
  final String title;
  final String body;

  /// 목록 맨 위에 고정
  final bool pinned;

  /// 작성자 uuid — 이름은 `StaffDirectory` 에서 찾는다
  final String authorId;

  final DateTime createdAt;

  /// 내가 열어 봤는지 — 목록에서 안 읽음 점·필터가 이 값을 쓴다
  final bool readByMe;

  /// 확인한 사람 수. 전체 인원은 `/notices/{id}/readers` 가 준다
  final int readCount;

  /// 이모지별 누른 사람 — 목록 응답에 같이 실려 온다
  final List<ReactionAgg> reactions;
}

/// 확인 현황 한 사람 (서버 `NoticeReaderOut`)
class NoticeReader {
  NoticeReader({
    required this.employeeId,
    required this.name,
    this.avatarColor,
    this.readAt,
  });

  factory NoticeReader.fromJson(Map<String, dynamic> json) => NoticeReader(
    employeeId: json['employeeId'] as String,
    name: json['name'] as String,
    avatarColor: json['avatarColor'] as String?,
    readAt: json['readAt'] == null
        ? null
        : DateTime.parse(json['readAt'] as String).toLocal(),
  );

  final String employeeId;
  final String name;
  final String? avatarColor;

  /// 확인한 시각 — **null 이면 아직 안 읽은 사람**이다
  final DateTime? readAt;

  bool get read => readAt != null;
}

/// 공지 확인 현황 (서버 `NoticeReadersOut`)
class NoticeReaders {
  NoticeReaders({
    required this.total,
    required this.readCount,
    required this.people,
  });

  factory NoticeReaders.fromJson(Map<String, dynamic> json) => NoticeReaders(
    total: json['total'] as int? ?? 0,
    readCount: json['readCount'] as int? ?? 0,
    people: [
      for (final row in (json['people'] as List<dynamic>? ?? const []))
        NoticeReader.fromJson((row as Map).cast<String, dynamic>()),
    ],
  );

  /// 봐야 하는 전체 인원
  final int total;
  final int readCount;

  /// 읽은 사람이 앞, 안 읽은 사람이 뒤로 온다
  final List<NoticeReader> people;
}

/// `/notices` — 공지
///
/// **쓰기 권한이 갈린다.** 작성은 전 직원이 할 수 있고(공지로 서로 요청·알림을
/// 주고받는 구조라 그렇다), 고치거나 지우는 건 **작성자 본인 또는 관리자·점장**이다.
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

  /// 지우기 (작성자 본인·ADMIN·MANAGER) — 달려 있던 이모지 반응도 같이 지워진다
  static Future<void> delete(String id) => _client.delete('/notices/$id');

  /// 열어 봤다고 찍기 — 멱등하므로 같은 공지를 여러 번 열어도 된다
  static Future<void> markRead(String id) =>
      _client.post('/notices/$id/read').then((_) {});

  /// 확인 현황 — 누가 읽었고 누가 안 읽었는지
  static Future<NoticeReaders> readers(String id) async {
    final data = await _client.get('/notices/$id/readers');
    return NoticeReaders.fromJson(data);
  }
}
