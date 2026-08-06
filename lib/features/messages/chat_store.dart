import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/chat/chat_socket.dart';
import '../../core/api/notice/reaction_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff_directory.dart';
import '../../core/util/photo.dart';

/// 사내톡 상태 한 곳
///
/// 목록 화면·채팅방·데스크톱 2단 화면이 **같은 방 목록과 같은 메시지**를 본다.
/// 화면마다 따로 받아 두면 한쪽에서 보낸 글이 다른 쪽에 안 뜬다
/// (데스크톱은 목록과 방이 한 화면에 같이 떠 있다).
///
/// 실시간 사건은 [ChatSocket] 하나를 듣고 여기서 나눠 준다.
class ChatStore extends ChangeNotifier {
  ChatStore._() {
    _sub = ChatSocket.instance.events.listen(_onEvent);
  }

  static final ChatStore instance = ChatStore._();

  late final StreamSubscription<ChatEvent> _sub;

  List<ChatRoom> _rooms = const [];
  List<ChatRoom> get rooms => _rooms;

  /// 방마다 받아 둔 메시지 — 오래된 것부터
  final Map<String, List<ChatMessage>> _messages = {};

  /// 지금 입력 중인 사람 (방별)
  final Map<String, Set<String>> _typing = {};

  /// 위로 더 불러올 게 남았는지 (방별)
  final Map<String, bool> _hasMore = {};

  bool _loadingRooms = false;
  bool get loadingRooms => _loadingRooms;

  /// 방 목록을 한 번이라도 받아 봤는가 — 처음에만 로딩을 그린다
  bool loaded = false;

  List<ChatMessage> messagesOf(String roomId) => _messages[roomId] ?? const [];

  Set<String> typingIn(String roomId) => _typing[roomId] ?? const {};

  bool hasMore(String roomId) => _hasMore[roomId] ?? false;

  ChatRoom? roomOf(String? id) {
    for (final room in _rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  /// 안 읽은 방이 몇 개인지 — 헤더 버튼·사내톡 필의 빨간 점에 쓴다
  ///
  /// 알림 배지(`unreadNotifications`)와 같은 방식으로 내보낸다 — 셸이
  /// 스토어 전체를 듣지 않고 이 값만 보면 된다.
  final unreadRooms = ValueNotifier<int>(0);

  void _syncUnread() =>
      unreadRooms.value = _rooms.where((r) => r.unreadCount > 0).length;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /// 로그아웃할 때 비운다 — 다음 사람에게 남의 대화가 보이면 안 된다
  void clear() {
    _rooms = const [];
    _messages.clear();
    _typing.clear();
    _hasMore.clear();
    _localCopies.clear();
    loaded = false;
    unreadRooms.value = 0;
    notifyListeners();
  }

  Future<void> loadRooms() async {
    _loadingRooms = true;
    try {
      _rooms = await ChatApi.rooms();
      loaded = true;
      _syncUnread();
    } finally {
      _loadingRooms = false;
      notifyListeners();
    }
  }

  /// 방을 열 때 — 지난 메시지를 받고 읽음으로 표시한다
  Future<void> openRoom(String roomId) async {
    final history = await ChatApi.messages(roomId);
    _messages[roomId] = history;
    // 서버가 최대 30개씩 준다 — 꽉 찼으면 위에 더 있을 수 있다
    _hasMore[roomId] = history.length >= 30;
    notifyListeners();
    await markRead(roomId);
  }

  /// 위로 더 불러오기
  Future<void> loadOlder(String roomId) async {
    final current = _messages[roomId];
    if (current == null || current.isEmpty) return;
    final older = await ChatApi.messages(
      roomId,
      before: current.first.createdAt,
    );
    if (older.isEmpty) {
      _hasMore[roomId] = false;
    } else {
      _messages[roomId] = [...older, ...current];
      _hasMore[roomId] = older.length >= 30;
    }
    notifyListeners();
  }

  /// 여기까지 읽었다고 알리고 방 목록의 배지를 지운다
  Future<void> markRead(String roomId) async {
    _setUnread(roomId, 0);
    try {
      await ChatApi.markRead(roomId);
    } catch (_) {
      // 못 알려도 화면은 읽은 것으로 둔다 — 다음에 목록을 받으면 맞춰진다
    }
  }

  /// 메시지 보내기 — **화면에 먼저 올리고** 서버 응답으로 갈아끼운다
  ///
  /// 네트워크를 기다리는 동안 아무것도 안 보이면 안 보낸 줄 알고 또 누른다.
  Future<void> send(
    String roomId, {
    required String body,
    ChatMessage? replyTo,
  }) async {
    final myId = currentUser?.id;
    if (myId == null) return;

    final draft = ChatMessage.sending(
      roomId: roomId,
      senderId: myId,
      body: body,
      replyTo: replyTo == null
          ? null
          : MessageRef(
              id: replyTo.id,
              senderId: replyTo.senderId,
              body: replyTo.body,
              deleted: false,
            ),
    );
    _append(roomId, draft);

    try {
      final sent = await ChatApi.send(
        roomId,
        body: body,
        replyToId: replyTo?.id,
      );
      _replaceDraft(roomId, draft.id, sent);
    } catch (error) {
      // 실패하면 임시 말풍선을 걷어낸다 — 안 간 글이 간 것처럼 남으면 안 된다
      _remove(roomId, draft.id);
      rethrow;
    }
  }

  /// 파일 보내기 — 올린 뒤 그 주소를 붙여 메시지 한 건으로 보낸다
  ///
  /// 본문은 비워 둔다. 서버가 빈 본문을 받아 주고, 목록 미리보기는
  /// '파일을 보냈어요' 로 떨어진다.
  Future<void> sendFiles(
    String roomId,
    List<(String path, String name)> files,
  ) async {
    if (files.isEmpty) return;
    final myId = currentUser?.id;
    if (myId == null) return;

    // 올라가기 전에 기기 안 사진으로 먼저 그린다 — 사진은 글보다 한참 오래
    // 걸려서(LTE 에서 몇 초), 안 그리면 누른 게 먹은 건지 알 수가 없다.
    // 글을 보낼 때와 같은 방식이라 흐리게 뜨다가 또렷해진다.
    final draft = ChatMessage.sending(
      roomId: roomId,
      senderId: myId,
      body: '',
      attachments: [for (final (path, _) in files) '$localFilePrefix$path'],
    );
    _append(roomId, draft);

    try {
      // **한꺼번에 올린다.** 하나씩 기다리면 장수만큼 시간이 곱해진다.
      // 올리기 전에 줄인다 — 사진첩 원본은 3~5MB 라 LTE 에서 장당 10초가 넘는다
      final uploaded = await Future.wait([
        for (final (path, name) in files)
          shrinkPhoto(path, name).then((small) async {
            final at = await ChatApi.uploadAttachment(
              roomId,
              small.$1,
              filename: small.$2,
            );
            return (at.url, small.$1);
          }),
      ]);
      // 올린 사진은 기기에 그대로 있다 — 서버 주소로 바뀐 뒤에도 이걸로 그린다
      for (final (url, local) in uploaded) {
        _rememberLocal(url, local);
      }
      final sent = await ChatApi.send(
        roomId,
        body: '',
        attachments: [for (final (url, _) in uploaded) url],
      );
      _replaceDraft(roomId, draft.id, sent);
    } catch (error) {
      // 실패하면 임시 말풍선을 걷어낸다 — 안 간 사진이 간 것처럼 남으면 안 된다
      _remove(roomId, draft.id);
      rethrow;
    }
  }

  /// 방금 올린 사진의 기기 파일 — 서버 주소 → 기기 경로
  ///
  /// 올라가는 순간 말풍선이 `Image.file` 에서 `Image.network` 로 갈리는데,
  /// 그러면 **방금 보이던 사진이 잠깐 사라졌다가** 서버에서 다시 받아 온 뒤에
  /// 뜬다. 올린 파일이 기기에 그대로 있으니 그걸 계속 쓴다.
  final Map<String, String> _localCopies = {};

  /// 무한정 쌓이지 않게 이만큼만 들고 있는다 (넘으면 오래된 것부터 버린다)
  static const _localCopyKeep = 40;

  String? localCopyOf(String url) => _localCopies[url];

  void _rememberLocal(String url, String path) {
    _localCopies[url] = path;
    while (_localCopies.length > _localCopyKeep) {
      _localCopies.remove(_localCopies.keys.first);
    }
  }

  /// 이 방 알림 끄기/켜기
  Future<ChatRoom> setMuted(String roomId, bool muted) async {
    final room = await ChatApi.setMuted(roomId, muted);
    _upsertRoom(room);
    return room;
  }

  /// 내가 나간 방들 — '최근 나간 항목'
  Future<List<ChatRoom>> leftRooms() => ChatApi.leftRooms();

  /// 전송 취소 — 서버가 지우면 소켓으로 모두에게 사라진다
  Future<void> deleteMessage(String roomId, String messageId) async {
    await ChatApi.deleteMessage(roomId, messageId);
    _remove(roomId, messageId);
  }

  /// 말풍선 이모지 — 같은 걸 다시 누르면 빠진다 (서버가 토글로 처리)
  ///
  /// 공지·회의록과 같은 `/reactions` 를 쓴다. 서버가 **토글 뒤 집계 전체**를
  /// 돌려주므로 그대로 갈아끼우면 된다.
  Future<void> toggleReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {
    final fresh = await ReactionApi.toggle(
      target: ReactionTarget.message,
      targetId: messageId,
      emoji: emoji,
    );
    final list = _messages[roomId];
    if (list == null) return;
    final at = list.indexWhere((m) => m.id == messageId);
    if (at < 0) return;
    list[at] = list[at].copyWith(reactions: fresh);
    notifyListeners();
  }

  Future<ChatRoom> createRoom(List<String> memberIds, {String? name}) async {
    final room = await ChatApi.createRoom(
      memberIds: memberIds,
      name: name,
      isGroup: memberIds.length > 1,
    );
    _upsertRoom(room);
    return room;
  }

  Future<ChatRoom> rename(String roomId, String name) async {
    final room = await ChatApi.rename(roomId, name);
    _upsertRoom(room);
    return room;
  }

  Future<ChatRoom> addMembers(String roomId, List<String> memberIds) async {
    final room = await ChatApi.addMembers(roomId, memberIds);
    _upsertRoom(room);
    return room;
  }

  Future<void> leave(String roomId) async {
    await ChatApi.leave(roomId);
    _rooms = [
      for (final room in _rooms)
        if (room.id != roomId) room,
    ];
    _messages.remove(roomId);
    _typing.remove(roomId);
    _syncUnread();
    notifyListeners();
  }

  /// 입력 중 신호 — 소켓이 끊겨 있으면 조용히 버려진다
  void typing(String roomId, {required bool isTyping}) =>
      ChatSocket.instance.typing(roomId, isTyping: isTyping);

  // ---------------------------------------------------------------------
  // 실시간
  // ---------------------------------------------------------------------

  void _onEvent(ChatEvent event) {
    switch (event) {
      case ChatMessageEvent(:final roomId, :final message):
        _onIncoming(roomId, message);
      case ChatDeleteEvent(:final roomId, :final messageId):
        _remove(roomId, messageId);
      case ChatTypingEvent(:final roomId, :final employeeId, :final isTyping):
        final who = _typing.putIfAbsent(roomId, () => <String>{});
        isTyping ? who.add(employeeId) : who.remove(employeeId);
        notifyListeners();
      case ChatReadEvent(:final roomId):
        // 남이 읽었으면 내 말풍선의 '읽음'이 바뀐다 — 그 수는 서버가 센다
        _refreshReadCounts(roomId);
    }
  }

  void _onIncoming(String roomId, ChatMessage message) {
    final mine = message.senderId == currentUser?.id;
    final list = _messages[roomId];

    // 내가 보낸 것은 REST 응답으로 이미 넣었을 수 있다 — 중복을 막는다
    if (list != null && list.any((m) => m.id == message.id)) return;

    if (list != null) {
      // 내 말풍선이 화면에 떠 있으면 아직 안 채운 자리(임시)를 먼저 채운다
      final draft = mine
          ? list.indexWhere((m) => m.pending && m.body == message.body)
          : -1;
      if (draft >= 0) {
        list[draft] = message;
      } else {
        list.add(message);
      }
    }

    _bumpRoom(roomId, message, countUnread: !mine);
    notifyListeners();
  }

  /// 상대가 읽으면 이 방 메시지의 `readCount` 가 달라진다 — 다시 받아 맞춘다
  Future<void> _refreshReadCounts(String roomId) async {
    if (!_messages.containsKey(roomId)) return;
    try {
      final fresh = await ChatApi.messages(roomId);
      final current = _messages[roomId];
      if (current == null) return;
      final byId = {for (final m in fresh) m.id: m};
      _messages[roomId] = [
        for (final m in current) byId[m.id]?.copyWith() ?? m,
      ];
      notifyListeners();
    } catch (_) {
      // 못 맞춰도 대화는 계속된다 — 읽음 표시만 늦는다
    }
  }

  // ---------------------------------------------------------------------
  // 목록·리스트 손질
  // ---------------------------------------------------------------------

  void _append(String roomId, ChatMessage message) {
    _messages.putIfAbsent(roomId, () => []).add(message);
    notifyListeners();
  }

  void _replaceDraft(String roomId, String draftId, ChatMessage sent) {
    final list = _messages[roomId];
    if (list == null) return;
    final at = list.indexWhere((m) => m.id == draftId);
    if (at >= 0) {
      list[at] = sent;
    } else if (!list.any((m) => m.id == sent.id)) {
      list.add(sent);
    }
    _bumpRoom(roomId, sent, countUnread: false);
    notifyListeners();
  }

  void _remove(String roomId, String messageId) {
    final list = _messages[roomId];
    if (list == null) return;
    list.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// 새 메시지가 오면 그 방을 목록 맨 위로 올린다
  void _bumpRoom(
    String roomId,
    ChatMessage message, {
    required bool countUnread,
  }) {
    final at = _rooms.indexWhere((r) => r.id == roomId);
    if (at < 0) {
      // 처음 보는 방이다 (남이 나를 새 방에 넣었다) — 목록을 다시 받는다
      loadRooms();
      return;
    }
    final old = _rooms[at];
    // 시스템 안내는 안읽음으로 세지 않는다 (서버 기준과 같게 맞춘다)
    final bump = countUnread && !message.isSystem ? 1 : 0;
    final updated = ChatRoom(
      id: old.id,
      name: old.name,
      isGroup: old.isGroup,
      ownerId: old.ownerId,
      memberIds: old.memberIds,
      lastMessage: message,
      unreadCount: old.unreadCount + bump,
      muted: old.muted,
      updatedAt: message.createdAt,
    );
    _rooms = [updated, ...(_rooms..removeAt(at))];
    _syncUnread();
  }

  void _setUnread(String roomId, int count) {
    final at = _rooms.indexWhere((r) => r.id == roomId);
    if (at < 0 || _rooms[at].unreadCount == count) return;
    final old = _rooms[at];
    _rooms = [..._rooms]
      ..[at] = ChatRoom(
        id: old.id,
        name: old.name,
        isGroup: old.isGroup,
        ownerId: old.ownerId,
        memberIds: old.memberIds,
        lastMessage: old.lastMessage,
        unreadCount: count,
        updatedAt: old.updatedAt,
      );
    notifyListeners();
  }

  void _upsertRoom(ChatRoom room) {
    final at = _rooms.indexWhere((r) => r.id == room.id);
    if (at >= 0) {
      _rooms = [..._rooms]..[at] = room;
    } else {
      _rooms = [room, ..._rooms];
    }
    _syncUnread();
    notifyListeners();
  }
}

/// 방 이름 — **DM 은 서버가 이름을 안 준다**
///
/// 둘만 있는 방에 '이름'을 붙일 이유가 없어서(상대가 곧 방 이름이다)
/// 서버는 null 로 두고, 앱이 상대 이름을 찾아 쓴다.
/// 그룹인데 이름이 없으면 멤버 이름을 이어 붙인다.
String chatRoomTitle(ChatRoom room) {
  if (room.name case final name? when name.isNotEmpty) return name;

  final others = room.othersOf(currentUser?.id);
  final names = [
    for (final id in others) ?StaffDirectory.instance.byId(id)?.name,
  ];
  if (names.isEmpty) return room.isGroup ? '대화방' : '알 수 없음';
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} 외 ${names.length - 3}명';
}

/// 방 아바타에 쓸 상대 — DM 이면 그 사람, 그룹이면 null
Employee? chatRoomPeer(ChatRoom room) {
  if (room.isGroup) return null;
  final others = room.othersOf(currentUser?.id);
  if (others.isEmpty) return null;
  return StaffDirectory.instance.byId(others.first);
}
