import 'api_client.dart';
import 'chat_api.dart' show MessageKind;

/// 열람용 대화방 (서버 `ChatAuditRoomOut`)
///
/// 사내톡 화면의 [ChatRoom] 과 **일부러 다른 모델이다.** 그쪽은 '내 기준' 값
/// (안읽음 수·알림 끔)을 들고 있는데 열람에는 뜻이 없고, 여기는 나간 사람과
/// 전송 취소분까지 세야 한다.
class ChatAuditRoom {
  ChatAuditRoom({
    required this.id,
    required this.isGroup,
    required this.ownerId,
    required this.memberIds,
    required this.leftMemberIds,
    required this.messageCount,
    required this.createdAt,
    this.name,
    this.lastMessageAt,
  });

  factory ChatAuditRoom.fromJson(Map<String, dynamic> json) => ChatAuditRoom(
    id: json['id'] as String,
    name: json['name'] as String?,
    isGroup: json['isGroup'] as bool? ?? false,
    ownerId: json['ownerId'] as String? ?? '',
    memberIds: [
      for (final id in (json['memberIds'] as List? ?? [])) id as String,
    ],
    leftMemberIds: [
      for (final id in (json['leftMemberIds'] as List? ?? [])) id as String,
    ],
    messageCount: json['messageCount'] as int? ?? 0,
    lastMessageAt: switch (json['lastMessageAt']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  /// 그룹방 이름. DM 은 비어 있어서 화면이 사람 이름으로 만든다
  final String? name;

  final bool isGroup;
  final String ownerId;

  /// 지금 방에 있는 사람
  final List<String> memberIds;

  /// 나간 사람 — 지금 없어도 그때 대화에는 있었다
  final List<String> leftMemberIds;

  /// 전송 취소분까지 포함한 수
  final int messageCount;

  final DateTime? lastMessageAt;
  final DateTime createdAt;

  /// 그때 그 방에 있던 사람 전부
  List<String> get everyone => [...memberIds, ...leftMemberIds];
}

/// 열람용 메시지 (서버 `ChatAuditMessageOut`)
class ChatAuditMessage {
  ChatAuditMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.body,
    required this.kind,
    required this.attachments,
    required this.createdAt,
    this.replyToId,
    this.deletedAt,
  });

  factory ChatAuditMessage.fromJson(Map<String, dynamic> json) =>
      ChatAuditMessage(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        senderId: json['senderId'] as String? ?? '',
        body: json['body'] as String? ?? '',
        kind: MessageKind.parse(json['kind'] as String?),
        attachments: [
          for (final url in (json['attachments'] as List? ?? [])) '$url',
        ],
        replyToId: json['replyToId'] as String?,
        deletedAt: switch (json['deletedAt']) {
          final String at => DateTime.parse(at).toLocal(),
          _ => null,
        },
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  final String id;
  final String roomId;
  final String senderId;
  final String body;
  final MessageKind kind;
  final List<String> attachments;
  final String? replyToId;

  /// 값이 있으면 **보낸 사람이 전송 취소한** 메시지다. 본문은 그대로 남아 있다
  final DateTime? deletedAt;

  final DateTime createdAt;

  bool get canceled => deletedAt != null;
  bool get isSystem => kind == MessageKind.system;
}

/// `/audit/chat` — 사내톡 열람 (읽기 전용)
///
/// **MASTER · ADMIN 만.** 사내톡 화면이 쓰는 `/chat/*` 과 다른 길이다 —
/// 그쪽은 방 멤버만 통과하고, 이쪽은 멤버가 아니어도 본다.
/// 읽음 처리를 안 하므로 방 사람들의 안읽음 수가 안 엉킨다.
class ChatAuditApi {
  ChatAuditApi._();

  static final _client = ApiClient.instance;

  /// 전사 대화방 — 최근 대화가 있는 방부터
  static Future<List<ChatAuditRoom>> rooms() async {
    final rows = await _client.getList('/audit/chat/rooms');
    return [
      for (final row in rows)
        ChatAuditRoom.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 그 방의 대화 — 오래된 것부터. **전송 취소된 것도 온다**
  static Future<List<ChatAuditMessage>> messages(
    String roomId, {
    DateTime? before,
    int limit = 100,
  }) async {
    final rows = await _client.getList(
      '/audit/chat/rooms/$roomId/messages',
      query: {'before': ?before?.toUtc().toIso8601String(), 'limit': '$limit'},
    );
    return [
      for (final row in rows)
        ChatAuditMessage.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 전사 메시지 검색 — 방을 몰라도 말로 찾는다. 최신순
  static Future<List<ChatAuditMessage>> search({
    String? q,
    String? employeeId,
    String? roomId,
    int limit = 200,
  }) async {
    final rows = await _client.getList(
      '/audit/chat/messages',
      query: {
        'q': ?q,
        'employeeId': ?employeeId,
        'roomId': ?roomId,
        'limit': '$limit',
      },
    );
    return [
      for (final row in rows)
        ChatAuditMessage.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
