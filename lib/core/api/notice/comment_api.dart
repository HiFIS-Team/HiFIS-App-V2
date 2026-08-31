import '../client/api_client.dart';

/// 댓글이 달릴 수 있는 글 (서버 `CommentTargetType`)
///
/// 반응([ReactionTarget])과 따로다 — 저쪽에는 사내톡 메시지가 있는데
/// 메시지에는 댓글이 아니라 **답글**이 달린다.
enum CommentTarget {
  notice('NOTICE'),
  meeting('MEETING'),
  project('PROJECT'),
  // 전자결재 (2026-08-31) — 예전에는 결재 행의 JSONB 에 따로 쌓였다.
  // 줄마다 id 가 없어 고치고 지울 수가 없어서 결재만 댓글 창이 달랐다
  approval('APPROVAL');

  const CommentTarget(this.wire);

  final String wire;
}

/// 댓글 한 줄 (서버 `CommentOut`)
class PostComment {
  PostComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
  );

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 고친 적이 있나 — 초 단위 차이는 만들 때의 오차라 무시한다
  bool get edited => updatedAt.difference(createdAt).inSeconds > 1;
}

/// `/comments` — 공지·회의록 공통 댓글
///
/// 볼 수 있는 글인지는 서버가 **그 글의 규칙 그대로** 가른다 —
/// 비공개(`PEOPLE`) 회의록의 댓글은 참석자가 아니면 403 이다.
class CommentApi {
  CommentApi._();

  static final _client = ApiClient.instance;

  /// **오래된 것부터** 온다 — 글 아래 이야기가 위에서 아래로 흐른다
  static Future<List<PostComment>> list({
    required CommentTarget target,
    required String targetId,
  }) async {
    final rows = await _client.getList(
      '/comments',
      query: {'targetType': target.wire, 'targetId': targetId},
    );
    return [
      for (final row in rows)
        PostComment.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<PostComment> add({
    required CommentTarget target,
    required String targetId,
    required String body,
  }) async {
    final data = await _client.post(
      '/comments',
      body: {'targetType': target.wire, 'targetId': targetId, 'body': body},
    );
    return PostComment.fromJson(data!);
  }

  /// 본인 댓글만
  static Future<PostComment> update(String id, {required String body}) async {
    final data = await _client.patch('/comments/$id', body: {'body': body});
    return PostComment.fromJson(data!);
  }

  /// 본인 댓글 또는 관리자
  static Future<void> remove(String id) => _client.delete('/comments/$id');
}
