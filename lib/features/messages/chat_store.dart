import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/chat/chat_socket.dart';
import '../../core/api/notice/reaction_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff_directory.dart';
import '../../core/util/photo.dart';
import '../../core/util/photo_cache.dart';
import '../../core/util/platform.dart' show isDesktop;
import '../../core/util/screen_refresh.dart' show appResumed;

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
    // 끊겼다 다시 붙었거나 앱이 다시 앞으로 나왔다 — 그 사이 온 메시지를 맞춘다
    ChatSocket.instance.connects.addListener(resync);
    appResumed.addListener(_onResumed);
  }

  /// 앱이 다시 앞으로 나왔다 — **폰만** 맞춘다
  ///
  /// 폰은 뒤로 가면 소켓이 끊겨 그 사이 메시지를 놓친다. PC 는 창 포커스만
  /// 바뀌어도 이 신호가 와서(`macos.md` 3번) 그때마다 목록을 받게 되는데,
  /// 소켓은 그대로 붙어 있다 — 끊겼다면 다시 붙을 때([ChatSocket.connects]) 맞춘다.
  void _onResumed() {
    if (isDesktop) return;
    resync();
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
    ChatSocket.instance.connects.removeListener(resync);
    appResumed.removeListener(_onResumed);
    super.dispose();
  }

  /// 로그아웃할 때 비운다 — 다음 사람에게 남의 대화가 보이면 안 된다
  void clear() {
    _rooms = const [];
    _messages.clear();
    _typing.clear();
    _hasMore.clear();
    _localCopies.clear();
    _bumpedAt.clear();
    _resyncedAt = null;
    loaded = false;
    unreadRooms.value = 0;
    notifyListeners();
  }

  Future<void> loadRooms() async {
    _loadingRooms = true;
    final asked = DateTime.now();
    try {
      _rooms = _keepNewer(await ChatApi.rooms(), since: asked);
      loaded = true;
      _syncUnread();
    } finally {
      _loadingRooms = false;
      notifyListeners();
    }
  }

  /// 받아 온 목록에 **그 사이 소켓으로 온 메시지**를 살린다 (2026-10-27)
  ///
  /// 목록을 부른 뒤 응답이 오기 전에 새 메시지가 오면, 늦게 온 응답이 그걸
  /// 덮어서 **미리보기가 한 칸 앞 대화로 돌아갔다.** 그 사이([since] 뒤)에
  /// 들어온 메시지가 더 새것이면 그 방은 내 것을 남긴다.
  ///
  /// **그 사이에 온 것만 본다.** 그 전부터 들고 있던 것까지 이기게 두면
  /// 다른 기기에서 전송 취소한 메시지가 미리보기에 영영 남는다.
  List<ChatRoom> _keepNewer(List<ChatRoom> fresh, {required DateTime since}) {
    final mine = {for (final room in _rooms) room.id: room};
    var changed = false;
    final merged = <ChatRoom>[];
    for (final room in fresh) {
      final local = mine[room.id]?.lastMessage;
      final server = room.lastMessage;
      final newer =
          local != null &&
          !local.pending &&
          (_bumpedAt[room.id]?.isAfter(since) ?? false) &&
          (server == null || local.createdAt.isAfter(server.createdAt));
      if (!newer) {
        merged.add(room);
        continue;
      }
      changed = true;
      final localUnread = mine[room.id]!.unreadCount;
      merged.add(
        ChatRoom(
          id: room.id,
          name: room.name,
          isGroup: room.isGroup,
          ownerId: room.ownerId,
          memberIds: room.memberIds,
          lastMessage: local,
          // 새 글을 이미 세어 뒀다 — 서버 값이 그보다 적으면 그 글이 빠진 것이다
          unreadCount: localUnread > room.unreadCount
              ? localUnread
              : room.unreadCount,
          muted: room.muted,
          updatedAt: room.updatedAt,
        ),
      );
    }
    if (changed) merged.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return merged;
  }

  /// 방마다 마지막으로 새 메시지를 올린 때 — [_keepNewer] 가 본다
  final Map<String, DateTime> _bumpedAt = {};

  /// 다시 맞추는 중 — 소켓과 앱 복귀가 한꺼번에 오면 두 번 돈다
  bool _resyncing = false;

  /// 마지막으로 맞춘 때 — 맥은 창 포커스만 바뀌어도 '다시 앞으로' 가 와서 자주 돈다
  DateTime? _resyncedAt;

  /// 서버와 다시 맞춘다 — **끊겨 있던 사이에 온 메시지**를 채운다 (2026-10-27)
  ///
  /// 소켓은 끊긴 동안의 메시지를 다시 보내 주지 않는다. 앱을 뒤에 뒀다 오면
  /// 목록 미리보기와 열어 둔 방이 **그 전 대화에 멈춰** 있었다.
  ///
  /// 목록은 통째로, 메시지는 **받아 둔 방만** 최근 것을 다시 받아 붙인다.
  /// 로그인 전이거나 목록을 한 번도 안 받았으면 아무것도 안 한다.
  Future<void> resync() async {
    if (!loaded || currentUser == null || _resyncing) return;
    final now = DateTime.now();
    if (_resyncedAt case final last?
        when now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _resyncing = true;
    _resyncedAt = now;
    try {
      await loadRooms();
      // **마지막 메시지가 달라진 방만** 다시 받는다 — 연 방이 많으면 앞으로
      // 나올 때마다 그 수만큼 요청이 나간다
      for (final roomId in [..._messages.keys]) {
        if (!_behind(roomId)) continue;
        try {
          await _refreshLatest(roomId);
        } catch (_) {
          // 한 방이 실패해도(나간 방 등) 나머지는 맞춘다
        }
      }
    } catch (_) {
      // 목록을 못 받았다 — 다음에 다시 붙거나 방을 열 때 맞춰진다
    } finally {
      _resyncing = false;
    }
  }

  /// 받아 둔 메시지가 목록의 마지막 메시지보다 뒤처졌나
  bool _behind(String roomId) {
    final latest = roomOf(roomId)?.lastMessage;
    final sent = [
      for (final m in _messages[roomId] ?? const <ChatMessage>[])
        if (!m.pending) m,
    ];
    if (latest == null) return sent.isNotEmpty; // 다 지워졌다
    return sent.isEmpty || sent.last.id != latest.id;
  }

  /// 받아 둔 방의 **최근 메시지**를 다시 받아 붙인다
  ///
  /// | 받아 온 것과 겹치나 | 하는 일 |
  /// |---|---|
  /// | 겹친다 | 빠진 것을 끼우고, 그 구간에서 사라진 것(전송 취소)은 뺀다 |
  /// | 안 겹친다 | 그 사이가 30개를 넘었다 — 최근 것으로 **갈아끼운다** |
  ///
  /// 보내는 중인 내 말풍선(`pending`)은 그대로 맨 뒤에 둔다 — 응답이 오면 제자리를
  /// 찾는다. 받아 온 구간보다 **새 메시지**(응답이 온 뒤 소켓으로 들어온 것)도 남긴다 —
  /// 구간 밖이라 받아 온 목록에 없는 것뿐이지 지워진 게 아니다.
  Future<void> _refreshLatest(String roomId) async {
    final asked = DateTime.now();
    final fresh = await ChatApi.messages(roomId);
    // **받아 온 뒤에** 읽는다 — 기다리는 동안 소켓으로 들어온 것까지 본다
    final current = _messages[roomId];
    if (current == null) return;
    // 방에 남은 메시지가 없다(다 전송 취소)고 왔는데 **기다리는 사이 새 글이
    // 왔으면 손대지 않는다** — 그 글이 받아 온 목록에 없을 뿐 지워진 게 아니다
    if (fresh.isEmpty && (_bumpedAt[roomId]?.isAfter(asked) ?? false)) return;
    final merged = mergeLatestMessages(current, fresh);
    if (merged.hasMore case final more?) _hasMore[roomId] = more;
    _messages[roomId] = merged.messages;
    notifyListeners();
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
      // 압축은 메인 isolate에서 큰 버퍼를 만들기 때문에 한 장씩 처리한다.
      // 동시에 돌리면 여러 장의 원본·디코드·JPEG 버퍼가 겹쳐 UI가 끊긴다.
      final prepared = <(String original, String path, String name)>[];
      try {
        for (final (path, name) in files) {
          final small = await shrinkPhoto(path, name);
          prepared.add((path, small.$1, small.$2));
        }

        // 압축이 끝난 작은 파일만 동시에 올려 네트워크 대기 시간을 줄인다.
        final uploaded = await Future.wait([
          for (final (original, path, name) in prepared)
            ChatApi.uploadAttachment(
              roomId,
              path,
              filename: name,
            ).then((at) => (at.url, original)),
        ]);
        // 서버 전송에는 압축본을 쓰고, 전송 뒤에도 미리보기는 원본을 유지한다.
        for (final (url, local) in uploaded) {
          _rememberLocal(url, local);
        }
        final sent = await ChatApi.send(
          roomId,
          body: '',
          attachments: [for (final (url, _) in uploaded) url],
        );
        _replaceDraft(roomId, draft.id, sent);
      } finally {
        for (final (original, path, _) in prepared) {
          if (path != original) {
            try {
              await File(path).delete();
            } catch (_) {}
          }
        }
      }
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

  /// **파일 이름으로 찾는다** — 주소를 그대로 키로 쓰면 안 된다.
  /// 서버가 내려줄 때마다 서명(`?exp&sig`)을 새로 붙여서, 올릴 때 받은 주소와
  /// 보낸 뒤 돌려받은 주소가 글자로는 다르다. 이름은 uuid 라 겹치지 않는다
  String? localCopyOf(String url) => _localCopies[PhotoCache.keyOf(url)];

  void _rememberLocal(String url, String path) {
    _localCopies[PhotoCache.keyOf(url)] = path;
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
    _bumpedAt[roomId] = DateTime.now();
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
        muted: old.muted,
        updatedAt: old.updatedAt,
      );
    // 여기서 다시 세야 헤더 배지가 그 자리에서 꺼진다 — 안 부르면 방을 읽고
    // 나와도 빨간 점이 남고, 목록을 다시 받을 때(`loadRooms`)에야 사라진다
    _syncUnread();
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

/// 들고 있던 메시지([current])에 서버에서 다시 받은 **최근 구간**([fresh])을 합친다
///
/// [ChatStore] 가 앱이 앞으로 나오거나 소켓이 다시 붙을 때 쓴다 (2026-10-27).
/// 둘 다 오래된 것부터다. 서버는 최근 30개까지 준다 — 다 못 채웠으면 방의
/// 처음부터 지금까지 전부다.
///
/// | 들고 있던 것 | 하는 일 |
/// |---|---|
/// | 받아 온 구간에 있다 | 받아 온 것으로 바꾼다 (읽음 수·공감이 바뀌었을 수 있다) |
/// | 구간 **안**인데 없다 | 뺀다 — 전송 취소됐다 |
/// | 구간보다 **새것** | 남긴다 — 받아 온 뒤에 소켓으로 들어왔다 |
/// | 구간보다 **옛것** | 겹치면 남기고, 안 겹치면 버린다 (사이가 30개를 넘어 비어 있다) |
/// | 보내는 중(`pending`) | 맨 뒤에 그대로 — 응답이 오면 제자리를 찾는다 |
///
/// [hasMore] 는 옛 구간을 버렸을 때만 채운다 (위로 더 받을 것이 있다).
@visibleForTesting
({List<ChatMessage> messages, bool? hasMore}) mergeLatestMessages(
  List<ChatMessage> current,
  List<ChatMessage> fresh,
) {
  final drafts = [
    for (final m in current)
      if (m.pending) m,
  ];
  final sent = [
    for (final m in current)
      if (!m.pending) m,
  ];
  if (fresh.isEmpty) return (messages: drafts, hasMore: null);
  final byId = {for (final m in fresh) m.id: m};
  final known = {for (final m in sent) m.id};
  final from = fresh.length >= 30 ? fresh.first.createdAt : null;
  final until = fresh.last.createdAt;
  final overlaps = sent.any((m) => byId.containsKey(m.id));
  final dropsOld = !overlaps && sent.any((m) => !m.createdAt.isAfter(until));
  final kept = [
    for (final m in sent)
      if (byId[m.id] case final updated?)
        updated
      else if (m.createdAt.isAfter(until))
        m
      else if (overlaps && from != null && m.createdAt.isBefore(from))
        m,
    for (final m in fresh)
      if (!known.contains(m.id)) m,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return (
    messages: [...kept, ...drafts],
    hasMore: dropsOld ? fresh.length >= 30 : null,
  );
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
