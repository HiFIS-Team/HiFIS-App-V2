import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../client/api_client.dart';
import 'chat_api.dart';
import '../client/token_store.dart';

/// 서버가 보내오는 실시간 사건
sealed class ChatEvent {
  const ChatEvent(this.roomId);

  final String roomId;
}

/// 새 메시지 — **내가 보낸 것도 온다** (다른 기기와 맞추려고 서버가 전원에게 보낸다)
class ChatMessageEvent extends ChatEvent {
  const ChatMessageEvent(super.roomId, this.message);

  final ChatMessage message;
}

/// 전송 취소 — 화면에서 그 말풍선을 빼라는 뜻
class ChatDeleteEvent extends ChatEvent {
  const ChatDeleteEvent(super.roomId, this.messageId);

  final String messageId;
}

/// 상대가 입력 중 — **본인에게는 안 온다**
class ChatTypingEvent extends ChatEvent {
  const ChatTypingEvent(super.roomId, this.employeeId, this.isTyping);

  final String employeeId;
  final bool isTyping;
}

/// 상대가 여기까지 읽었다
class ChatReadEvent extends ChatEvent {
  const ChatReadEvent(super.roomId, this.employeeId, this.lastReadAt);

  final String employeeId;
  final DateTime? lastReadAt;
}

/// 사내톡 실시간 연결
///
/// 로그인해 있는 동안 **하나만** 열어 두고 모든 방이 같이 쓴다. 방마다 열면
/// 방이 늘어난 만큼 연결이 늘고, 목록 화면에서 안 열어 둔 방의 새 메시지를
/// 놓친다.
///
/// 서버 주소는 `apiBaseUrl` 을 그대로 바꿔 쓴다 (`http`→`ws`, `https`→`wss`).
/// **토큰은 쿼리로 넘긴다** — WebSocket 은 헤더를 못 싣는다.
///
/// 끊기면 스스로 다시 붙는다. 붙는 동안에도 메시지 전송은 REST 로 나가므로
/// (`ChatApi.send`) 글이 막히지는 않는다 — 남의 글이 늦게 올 뿐이다.
class ChatSocket {
  ChatSocket._();

  static final ChatSocket instance = ChatSocket._();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;

  /// 다시 붙기까지 기다리는 시간 — 실패할수록 늘린다 (최대 30초)
  Duration _backoff = const Duration(seconds: 1);

  /// 일부러 끊은 것인지 — 로그아웃하면 다시 붙지 않는다
  bool _closed = true;

  final _events = StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _events.stream;

  bool get connected => _socket != null;

  /// 로그인 직후 부른다. 이미 붙어 있으면 아무것도 안 한다.
  Future<void> connect() async {
    _closed = false;
    if (_socket != null) return;

    final token = TokenStore.instance.accessToken;
    if (token == null || token.isEmpty) return;

    final base = apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    try {
      // 서버가 안 받으면 OS 타임아웃(수십 초)까지 매달린다 — 짧게 끊고
      // 백오프로 다시 시도한다
      final socket = await WebSocket.connect(
        '$base/ws/chat?token=${Uri.encodeQueryComponent(token)}',
      ).timeout(const Duration(seconds: 6));
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _backoff = const Duration(seconds: 1);
      _sub = socket.listen(
        _onFrame,
        onDone: _onDropped,
        onError: (_) => _onDropped(),
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('사내톡 연결 실패: $error');
      _scheduleRetry();
    }
  }

  /// 로그아웃 — 다시 붙지 않는다
  Future<void> disconnect() async {
    _closed = true;
    _retry?.cancel();
    _retry = null;
    await _sub?.cancel();
    _sub = null;
    await _socket?.close();
    _socket = null;
  }

  void _onDropped() {
    _sub?.cancel();
    _sub = null;
    _socket = null;
    if (!_closed) _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(_backoff, () {
      _backoff = _backoff * 2;
      if (_backoff > const Duration(seconds: 30)) {
        _backoff = const Duration(seconds: 30);
      }
      connect();
    });
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> data;
    try {
      data = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return; // 못 읽는 프레임은 버린다 — 연결은 살려 둔다
    }
    final roomId = data['roomId'] as String?;
    if (roomId == null) return;

    switch (data['type']) {
      case 'message':
        if (data['message'] case final Map<dynamic, dynamic> body) {
          _events.add(
            ChatMessageEvent(
              roomId,
              ChatMessage.fromJson(body.cast<String, dynamic>()),
            ),
          );
        }
      case 'delete':
        if (data['messageId'] case final String id) {
          _events.add(ChatDeleteEvent(roomId, id));
        }
      case 'typing':
        if (data['employeeId'] case final String who) {
          _events.add(
            ChatTypingEvent(roomId, who, data['isTyping'] as bool? ?? true),
          );
        }
      case 'read':
        if (data['employeeId'] case final String who) {
          _events.add(
            ChatReadEvent(
              roomId,
              who,
              DateTime.tryParse(data['lastReadAt'] as String? ?? '')?.toLocal(),
            ),
          );
        }
    }
  }

  void _send(Map<String, dynamic> frame) {
    final socket = _socket;
    if (socket == null) return; // 끊겨 있으면 조용히 버린다
    try {
      socket.add(jsonEncode(frame));
    } catch (_) {
      _onDropped();
    }
  }

  /// 입력 중이라고 알린다 — 안 가도 그만인 신호라 실패를 무시한다
  void typing(String roomId, {required bool isTyping}) =>
      _send({'type': 'typing', 'roomId': roomId, 'isTyping': isTyping});

  /// 읽음 — REST(`ChatApi.markRead`)와 달리 **소켓이 있을 때만** 간다.
  /// 확실히 남겨야 하는 자리에서는 REST 를 쓴다.
  void read(String roomId) => _send({'type': 'read', 'roomId': roomId});
}
