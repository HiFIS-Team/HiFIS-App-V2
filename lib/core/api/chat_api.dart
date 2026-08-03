import 'package:dio/dio.dart';

import 'api_client.dart';
import 'reaction_api.dart';

/// 메시지 종류 — 서버 `MessageKind`
///
/// `SYSTEM` 은 사람이 쓴 말이 아니라 서버가 남긴 안내다 (초대·나가기·이름 변경).
/// 말풍선이 아니라 가운데 회색 한 줄로 그린다.
enum MessageKind {
  text('TEXT'),
  system('SYSTEM');

  const MessageKind(this.wire);

  final String wire;

  static MessageKind parse(String? value) => MessageKind.values.firstWhere(
    (k) => k.wire == value,
    orElse: () => MessageKind.text,
  );
}

/// 답글이 가리키는 원문 (서버 `MessageRef`)
///
/// 원문이 전송 취소됐으면 [deleted] 가 true 이고 [body] 는 비어 온다.
/// 지운 내용이 인용으로 되살아나지 않게 서버가 본문을 빼고 준다.
class MessageRef {
  MessageRef({
    required this.id,
    required this.senderId,
    required this.body,
    required this.deleted,
  });

  factory MessageRef.fromJson(Map<String, dynamic> json) => MessageRef(
    id: json['id'] as String,
    senderId: json['senderId'] as String? ?? '',
    body: json['body'] as String? ?? '',
    deleted: json['deleted'] as bool? ?? false,
  );

  final String id;
  final String senderId;
  final String body;
  final bool deleted;

  /// 말풍선 위에 인용할 한 줄
  String get preview => deleted ? '삭제된 메시지' : body;
}

/// 서버가 준 중첩 객체를 안전하게 읽는다 — 없으면 null
MessageRef? _ref(dynamic value) =>
    value is Map ? MessageRef.fromJson(value.cast<String, dynamic>()) : null;

/// 메시지 한 줄 (서버 `MessageOut`)
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.kind = MessageKind.text,
    this.attachments = const [],
    this.reactions = const [],
    this.replyTo,
    this.readCount = 0,
    this.pending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String? ?? '',
    kind: MessageKind.parse(json['kind'] as String?),
    attachments: [
      for (final a in (json['attachments'] as List<dynamic>? ?? const []))
        a as String,
    ],
    reactions: [
      for (final r in (json['reactions'] as List<dynamic>? ?? const []))
        ReactionAgg.fromJson((r as Map).cast<String, dynamic>()),
    ],
    replyTo: _ref(json['replyTo']),
    readCount: json['readCount'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String roomId;
  final String senderId;
  final String body;
  final MessageKind kind;
  final List<String> attachments;
  final List<ReactionAgg> reactions;
  final MessageRef? replyTo;

  /// 나 말고 이 메시지를 읽은 사람 수
  ///
  /// DM 은 1 이면 읽은 것이고, 그룹은 숫자를 그대로 보여주면 된다.
  final int readCount;

  final DateTime createdAt;

  /// 아직 서버 응답을 못 받은 내 메시지 (낙관적 표시)
  ///
  /// 보내자마자 화면에 올리고, 서버가 준 진짜 메시지가 오면 갈아끼운다.
  /// 네트워크를 기다리는 동안 입력창이 빈 채로 멈춰 있으면 안 보낸 줄 안다.
  final bool pending;

  bool get isSystem => kind == MessageKind.system;

  ChatMessage copyWith({List<ReactionAgg>? reactions, int? readCount}) =>
      ChatMessage(
        id: id,
        roomId: roomId,
        senderId: senderId,
        body: body,
        kind: kind,
        attachments: attachments,
        reactions: reactions ?? this.reactions,
        replyTo: replyTo,
        readCount: readCount ?? this.readCount,
        createdAt: createdAt,
        pending: pending,
      );

  /// 보내는 중인 임시 메시지 — id 가 서버 것이 아니라 시각으로 만든 것이다
  static ChatMessage sending({
    required String roomId,
    required String senderId,
    required String body,
    MessageRef? replyTo,
  }) => ChatMessage(
    id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
    roomId: roomId,
    senderId: senderId,
    body: body,
    replyTo: replyTo,
    createdAt: DateTime.now(),
    pending: true,
  );
}

ChatMessage? _last(dynamic value) =>
    value is Map ? ChatMessage.fromJson(value.cast<String, dynamic>()) : null;

/// 사내톡에 올린 파일 하나 (서버 `AttachmentOut`)
class ChatAttachment {
  ChatAttachment({
    required this.url,
    required this.name,
    required this.ext,
    required this.size,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    url: json['url'] as String,
    name: json['name'] as String? ?? '',
    ext: json['ext'] as String? ?? '',
    size: json['size'] as int? ?? 0,
  );

  /// 서명이 붙은 상대 경로 — 그대로 메시지 `attachments` 에 넣는다
  final String url;

  final String name;
  final String ext;
  final int size;
}

/// 첨부 주소가 사진인지 — 말풍선에 미리보기를 띄울지 가른다
const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'};

bool isImageAttachment(String url) {
  // `/files/2026/08/xxx.png?exp=..&sig=..` 에서 확장자만 본다
  final path = url.split('?').first;
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExts.contains(path.substring(dot + 1).toLowerCase());
}

/// 대화방 (서버 `ChatRoomOut`)
class ChatRoom {
  ChatRoom({
    required this.id,
    required this.isGroup,
    required this.ownerId,
    required this.memberIds,
    required this.updatedAt,
    this.name,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    name: json['name'] as String?,
    isGroup: json['isGroup'] as bool? ?? false,
    ownerId: json['ownerId'] as String? ?? '',
    memberIds: [
      for (final id in (json['memberIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
    lastMessage: _last(json['lastMessage']),
    unreadCount: json['unreadCount'] as int? ?? 0,
    updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
  );

  final String id;

  /// 그룹방 이름 — **DM 은 null 이다** (상대 이름으로 보여준다)
  final String? name;

  final bool isGroup;
  final String ownerId;
  final List<String> memberIds;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  /// 목록을 세울 때 쓰는 시각 — 마지막 메시지가 있으면 그 시각
  DateTime get sortAt => lastMessage?.createdAt ?? updatedAt;

  /// 나 말고 이 방에 있는 사람들
  List<String> othersOf(String? myId) => [
    for (final id in memberIds)
      if (id != myId) id,
  ];
}

/// `/chat` — 사내톡 방·메시지
///
/// 실시간 수신·타이핑은 WebSocket 이 맡는다 (`chat_socket.dart`).
/// 여기는 방 관리·히스토리·전송처럼 **남아야 하는 것**을 다룬다.
class ChatApi {
  ChatApi._();

  static final _client = ApiClient.instance;

  static Future<List<ChatRoom>> rooms() async {
    final rows = await _client.getList('/chat/rooms');
    return [
      for (final row in rows)
        ChatRoom.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 방 만들기 — **1:1 은 이미 있으면 그 방을 돌려준다** (서버가 찾아 준다)
  static Future<ChatRoom> createRoom({
    required List<String> memberIds,
    String? name,
    bool isGroup = false,
  }) async {
    final row = await _client.post(
      '/chat/rooms',
      body: {'memberIds': memberIds, 'name': ?name, 'isGroup': isGroup},
    );
    return ChatRoom.fromJson(row!);
  }

  /// 방 이름 바꾸기 — **그룹방만** 된다 (DM 은 400)
  static Future<ChatRoom> rename(String roomId, String name) async {
    final row = await _client.patch(
      '/chat/rooms/$roomId',
      body: {'name': name},
    );
    return ChatRoom.fromJson(row!);
  }

  /// 멤버 초대 — **DM 에 초대하면 그룹방이 된다**
  static Future<ChatRoom> addMembers(
    String roomId,
    List<String> memberIds,
  ) async {
    final row = await _client.post(
      '/chat/rooms/$roomId/members',
      body: {'memberIds': memberIds},
    );
    return ChatRoom.fromJson(row!);
  }

  /// 방 나가기 — 마지막 사람이 나가면 서버가 방을 지운다
  static Future<void> leave(String roomId) =>
      _client.delete('/chat/rooms/$roomId/members/me');

  /// 지난 메시지 — 오래된 것부터 온다
  ///
  /// [before] 를 주면 그 시각보다 **이전** 것을 준다 (위로 더 불러오기).
  static Future<List<ChatMessage>> messages(
    String roomId, {
    DateTime? before,
    int limit = 30,
  }) async {
    final rows = await _client.getList(
      '/chat/rooms/$roomId/messages',
      query: {'before': ?before?.toUtc().toIso8601String(), 'limit': limit},
    );
    return [
      for (final row in rows)
        ChatMessage.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 메시지 보내기 (영속)
  ///
  /// 실시간 경로는 WebSocket 이지만, **소켓이 끊겨 있어도 보낼 수 있어야 해서**
  /// REST 를 기본 경로로 쓴다. 서버가 저장 후 방 멤버에게 브로드캐스트하므로
  /// 어느 쪽으로 보내든 남들이 받는 건 같다.
  static Future<ChatMessage> send(
    String roomId, {
    required String body,
    String? replyToId,
    List<String> attachments = const [],
  }) async {
    final row = await _client.post(
      '/chat/rooms/$roomId/messages',
      body: {'body': body, 'attachments': attachments, 'replyToId': ?replyToId},
    );
    return ChatMessage.fromJson(row!);
  }

  /// 전송 취소 — **본인이 보낸 것만** (남의 것은 403)
  static Future<void> deleteMessage(String roomId, String messageId) =>
      _client.delete('/chat/rooms/$roomId/messages/$messageId');

  /// 여기까지 읽었다고 서버에 알린다
  static Future<void> markRead(String roomId) =>
      _client.post('/chat/rooms/$roomId/read');

  /// 파일 올리기 — 돌려받은 [ChatAttachment.url] 을 [send] 의 `attachments` 에 넣는다
  ///
  /// 문서함 업로드와 나눠 쓴다. 대화에 붙는 사진 한 장은 문서 트리에
  /// 들어갈 것이 아니라서 서버도 다른 엔드포인트를 준다.
  static Future<ChatAttachment> uploadAttachment(
    String roomId,
    String path, {
    String? filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final data = await _client.post(
      '/chat/rooms/$roomId/attachments',
      body: form,
    );
    return ChatAttachment.fromJson(data!);
  }

  /// 나간 방 목록 — '최근 나간 항목'
  static Future<List<ChatRoom>> leftRooms() async {
    final rows = await _client.getList('/chat/rooms', query: {'left': true});
    return [
      for (final row in rows)
        ChatRoom.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
