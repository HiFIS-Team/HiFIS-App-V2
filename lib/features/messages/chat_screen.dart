import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:gal/gal.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/client/api_client.dart' show ApiClient, fileUrl;
import '../../core/api/client/api_exception.dart';
import '../../core/api/notice/reaction_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/photo_cache.dart';
import '../../core/util/platform.dart';
import '../../core/util/when.dart';
import '../../core/widgets/editor/reaction_row.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_input_bar.dart';
import '../../core/widgets/glass/glass_surface.dart';
import '../../core/widgets/glass/top_frost.dart';
import '../../core/widgets/input/pressable.dart';
import 'chat_detail_screen.dart';
import 'chat_store.dart';
import '../../core/theme/app_shadows.dart';
part 'chat_bubbles.dart';
part 'chat_photo_viewer.dart';
part 'chat_reactions.dart';

/// 리액션으로 고를 수 있는 이모지 목록
const _reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

/// 이모지 텍스트 — 애플 이모지 글리프가 자기 폭 안에서 왼쪽으로 치우쳐
/// 그려지므로(시뮬레이터 픽셀 측정 결과 폰트 크기의 약 10%) 오른쪽으로 보정한다.
class _EmojiText extends StatelessWidget {
  _EmojiText(this.emoji, {required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(size * 0.10, 0),
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, height: 1),
      ),
    );
  }
}

/// 채팅방 화면 (인스타그램 DM 스타일)
///
/// 메시지는 [ChatStore] 가 들고 있다 — 목록 화면과 같은 것을 본다.
/// 말풍선 더블탭 → ❤️ 토글, 길게 누르기 → 이모지 피커.
///
/// **방 id 로 연다.** 이름·색은 서버 명단에서 찾아 쓰므로 넘길 필요가 없고,
/// 이름이 바뀌어도(그룹방 이름 변경) 한 곳만 고치면 다 따라온다.
class ChatScreen extends StatefulWidget {
  ChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  final _store = ChatStore.instance;

  /// PC에서 커서가 올라가 있는 말풍선 (호버 액션 아이콘 표시용)
  ///
  /// **setState 로 두면 안 된다** — `MouseRegion.onEnter` 안에서 트리를 다시
  /// 만들면 마우스 추적 중에 트리가 바뀌어 `_debugDuringDeviceUpdate` 단언에
  /// 걸린다 (실제 발생). 아이콘만 다시 그리도록 값 알림으로 둔다.
  final _hovered = ValueNotifier<String?>(null);

  /// 답글 작성 대상 메시지 (없으면 일반 전송)
  ChatMessage? _replyTarget;

  /// 사라지는 중인 말풍선 — 줄어드는 애니메이션을 그리는 동안만 들어 있다.
  /// 서버가 지우면 스토어에서 빠지면서 실제로 사라진다.
  final _removingIds = <String>{};

  /// 마지막으로 보낸 '입력 중' 신호 — 글자마다 보내지 않으려고 기억해 둔다
  bool _typingSent = false;
  Timer? _typingStop;

  String get _roomId => widget.roomId;

  ChatRoom? get _room => _store.roomOf(_roomId);

  List<ChatMessage> get _messages => _store.messagesOf(_roomId);

  /// 헤더에 적을 방 이름 — DM 은 상대 이름, 그룹은 방 이름(없으면 멤버 이름)
  String get _title {
    final room = _room;
    return room == null ? '대화' : chatRoomTitle(room);
  }

  bool get _isGroup => _room?.isGroup ?? false;

  Color get _headColor {
    final room = _room;
    if (room == null) return AppColors.primary;
    return chatRoomPeer(room)?.color ?? staffOf(chatRoomTitle(room)).color;
  }

  /// 이전 대화를 받아오는 중 — 스크롤 한 번에 여러 번 부르지 않게 잠근다
  bool _loadingOlder = false;

  /// 바닥(=최신 메시지)에 한 번 섬 뒤에만 true
  ///
  /// 목록은 오래된 것이 위라 아무것도 안 하면 **맨 위(가장 오래된 메시지)**에 선다.
  /// 그 사이에 `_onScroll` 이 돌면 위쪽 끝이라고 판단해 이전 대화를 더 붙이고,
  /// 그 위치를 그대로 유지해버려서 **알림을 누르면 예날 대화에 서 있었다**.
  /// 자리를 잡기 전까지는 더 불러오지도, 따라가지도 않는다.
  bool _settled = false;

  /// 바닥에 앉히기 전에는 목록을 **감춘다**
  ///
  /// 어디가 바닥인지는 한 번 그려 봐야 안다 (사진 높이가 그때 정해진다).
  /// 그래서 그린 다음 프레임에 옮기는데, **그 한 프레임이 눈에 띈다** —
  /// 글만 있는 방은 마지막 줄이 입력바에 가렸다가 올라오고, 사진이 있는 방은
  /// 맨 위가 보였다가 아래로 내려간다 (2026-08-31 대표가 짚었다).
  ///
  /// 감추는 것은 목록뿐이다 — 헤더·입력바는 [Stack] 의 다른 자식이라 그대로 있다.
  bool _placed = false;

  /// 파일을 올리는 중 — 두 번 눌러 두 번 보내지 않게 잠근다
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // 키보드가 오르내리는 것을 알아야 대화를 따라 올릴 수 있다 ([didChangeMetrics])
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStore);
    _scrollController.addListener(_onScroll);
    _open();
  }

  /// 키보드가 오르내릴 때 — 바닥을 보고 있었으면 계속 바닥을 보게 한다
  ///
  /// 안 하면 키보드가 마지막 말풍선을 덮어버리고, 앞서 쓰던 타이머 방식으로
  /// 따라가면 **50ms 마다 한 칸씩 튀어서 사진이 흔들리며 올라간다**
  /// (실기기에서 실제로 났다). [_pinToBottom] 이 프레임마다 따라간다.
  @override
  void didChangeMetrics() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 위를 보고 있으면 붙잡지 않는다
    if (position.pixels < position.maxScrollExtent - 80) return;
    _pinToBottom(after: Duration.zero, hold: _keyboardPinFor);
  }

  /// 위로 끝까지 올리면 이전 대화를 더 받아온다
  ///
  /// **버튼을 두지 않는다** — 화면에 없던 요소를 새로 만들지 않고, 카톡·인스타처럼
  /// 위로 당기면 알아서 이어 붙는다.
  void _onScroll() {
    if (!_settled) return;
    if (_loadingOlder || !_store.hasMore(_roomId)) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 80) return;
    _loadOlder();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    _loadingOlder = true;
    // 이어 붙기 전 위치를 기억해 뒀다가, 늘어난 만큼 내려서 화면이 안 튀게 한다
    final before = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      await _store.loadOlder(_roomId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final grew = _scrollController.position.maxScrollExtent - before;
        if (grew > 0) {
          _scrollController.jumpTo(_scrollController.position.pixels + grew);
        }
      });
    } catch (_) {
      // 못 받아오면 다음 스크롤에서 다시 시도한다
    }
    _loadingOlder = false;
  }

  Future<void> _open() async {
    try {
      await _store.openRoom(_roomId);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    // 들어가자마자 바닥이어야 한다 — 위에서 스르륵 내려오면 어수선하다
    _scrollToBottom(animate: false);
    // 바닥에 섬을 확인한 뒤에야 위로 더 불러오기를 푸다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settled = true;
      // 안전망 — 빈 방이거나 못 받아왔으면 위에서 안 켜진다
      if (!_placed && mounted) setState(() => _placed = true);
    });
  }

  /// 새 메시지가 들어오면 아래에 붙어 있던 화면은 따라 내려간다
  void _onStore() {
    if (!mounted) return;
    // 아직 자리를 안 잡았으면 무조건 바닥이다 — 첫 목록이 들어올 때 화면은
    // offset 0(맨 위)이라 그대로 두면 예날 대화에 멈춰 버린다
    final atBottom =
        !_settled ||
        !_scrollController.hasClients ||
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80;
    setState(() {});
    // 첫 목록이 들어올 때는 **옮긴다** — 스르륵 내리면 맨 위에서 아래로
    // 미끄러지는 게 그대로 보인다. 그 뒤에 오는 새 글만 스르륵 내려간다
    if (atBottom) _scrollToBottom(animate: _settled);
    // 열어 둔 방에 새 글이 오면 바로 읽은 것으로 친다
    if (_room?.unreadCount case final unread? when unread > 0) {
      _store.markRead(_roomId);
    }
  }

  @override
  void dispose() {
    _hovered.dispose();
    _pinUntil = null;
    WidgetsBinding.instance.removeObserver(this);
    _typingStop?.cancel();
    if (_typingSent) _store.typing(_roomId, isTyping: false);
    _store.removeListener(_onStore);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  /// 입력 중 신호 — 켤 때 한 번만 보내고 2초 쉬면 끈다
  void _onTyping() {
    if (!_typingSent) {
      _typingSent = true;
      _store.typing(_roomId, isTyping: true);
    }
    _typingStop?.cancel();
    _typingStop = Timer(Duration(seconds: 2), () {
      _typingSent = false;
      _store.typing(_roomId, isTyping: false);
    });
  }

  /// 파일 붙이기 — 입력바의 링크 아이콘이 부른다 (원래 비어 있던 버튼이다)
  ///
  /// **폰은 사진첩을 연다.** 기본값(`FileType.any`)은 iOS 에서 '파일' 앱을
  /// 여는데, 거기서는 사진첩을 못 뒤진다 — 사진을 고를 길이 아예 없었다
  /// (실기기에서 실제로 났다). PC 는 문서를 붙이는 자리라 파일 고르개 그대로다.
  ///
  /// **열기 전에 키보드를 내린다.** 안 내리면 네이티브 고르개가 떴다 사라진 뒤
  /// 키보드가 화면에 눌어붙어서, 방을 나가 홈으로 가도 안 내려간다
  /// (역시 실기기에서 났다 — 시뮬레이터는 키보드를 안 띄워서 안 보였다).
  ///
  /// **`compressionQuality` 를 0 보다 크게 준다.** 아이폰 사진은 HEIC 인데
  /// 기본값 0 이면 사진첩이 원본을 그대로 준다. HEIC 는 서버에 올라가긴 해도
  /// **Flutter 가 못 그려서 말풍선에서 깨진다** (지원 포맷에 HEIC 가 없다).
  /// 0 보다 크면 사진첩이 호환 포맷(JPEG)으로 바꿔서 준다.
  Future<void> _attach() async {
    _inputFocus.unfocus();
    final picked = await FilePicker.pickFiles(
      allowMultiple: true,
      type: isDesktop ? FileType.any : FileType.image,
      compressionQuality: isDesktop ? 0 : 100,
    );
    final files = [
      for (final f in picked?.files ?? const <PlatformFile>[])
        if (f.path case final path?) (path, f.name),
    ];
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      // 부르는 즉시 임시 말풍선이 붙는다 — 그걸 먼저 보여주고,
      // 다 올라간 뒤 사진이 뜨면서 길어지는 만큼 한 번 더 따라 내려간다
      final sending = _store.sendFiles(_roomId, files);
      _scrollToBottom();
      await sending;
      _scrollToBottom();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _send(String text) async {
    final reply = _replyTarget;
    setState(() => _replyTarget = null);
    _typingStop?.cancel();
    if (_typingSent) {
      _typingSent = false;
      _store.typing(_roomId, isTyping: false);
    }
    _scrollToBottom();
    try {
      await _store.send(_roomId, body: text, replyTo: reply);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    _scrollToBottom();
  }

  /// 바닥으로 내린 뒤 **잠깐 붙여 둔다**
  ///
  /// 사진은 받아오기 전에는 높이를 모른다. 한 번만 내리면 그 뒤에 사진이 뜨면서
  /// 목록이 길어져 **화면이 중간에 선다** — 방에 들어갈 때도, 사진을 보낸
  /// 직후에도 실제로 났다. [_pinFor] 동안 늘어나는 만큼 따라 내려간다.
  ///
  /// **사용자가 스크롤을 잡으면 즉시 그만둔다** — 위로 올려 보는 것을 붙잡으면 안 된다.
  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final bottom = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          bottom,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(bottom);
      }
      // 자리를 잡았으니 이제 보여준다 — 빈 목록에는 안 켠다 (아직 받는 중이라
      // 켜 두면 날짜 구분선 한 줄만 떴다가 대화가 채워지는 게 보인다)
      if (!_placed && _messages.isNotEmpty) setState(() => _placed = true);
      _pinToBottom(
        after: animate ? Duration(milliseconds: 260) : Duration.zero,
      );
    });
  }

  /// 바닥에 붙여 두는 시간 — 사진 몇 장이 뜨는 데 걸리는 만큼
  static const _pinFor = Duration(milliseconds: 1500);

  /// 키보드를 따라갈 때 붙여 두는 시간 — 올라오는 동안 계속 갱신되므로
  /// 애니메이션이 끝난 뒤 조금만 더 버티면 된다
  static const _keyboardPinFor = Duration(milliseconds: 300);

  /// 이 시각까지 매 프레임 바닥을 따라간다 (null 이면 안 따라간다)
  DateTime? _pinUntil;

  /// 이 시각 전에는 따라가지 않는다 — 스르륵 내려가는 중에 붙잡으면
  /// 그 애니메이션이 중간에 끊긴다 (`jumpTo` 가 진행 중인 이동을 취소한다)
  DateTime _pinFrom = DateTime.fromMillisecondsSinceEpoch(0);

  /// 다음 프레임 콜백을 이미 걸어 뒀는지 — 한 프레임에 하나만 건다
  bool _pinQueued = false;

  /// 붙잡는 동안 본 목록 길이 — 사진이 뛰어 길어졌는지 보려고 기억해 둔다 (-1 이면 안 재다)
  double _pinExtent = -1;

  /// 이 시각을 넘기면 더 늘어나도 놓아준다 — 사진이 줄줄이 들어오는 방에서
  /// 영영 못 놓는 일이 없게 한다
  DateTime _pinDeadline = DateTime.fromMillisecondsSinceEpoch(0);

  /// 늘어난 뒤에도 붙잡을 수 있는 최대 시간
  static const _pinMax = Duration(seconds: 8);

  /// **타이머가 아니라 프레임마다** 따라간다
  ///
  /// 50ms 타이머로 하면 초당 20번만 따라가서, 키보드처럼 60번 움직이는 것을
  /// 쫓을 때 **계단처럼 튄다** — 사진이 흔들리며 올라가 보였다.
  void _pinToBottom({required Duration after, Duration hold = _pinFor}) {
    final now = DateTime.now();
    final until = now.add(after + hold);
    if (_pinUntil == null) {
      _pinExtent = -1;
      _pinDeadline = now.add(after + _pinMax);
    }
    // 이미 따라가는 중이면 마감만 늦춘다 (연달아 부르면 더 오래 붙어 있는다)
    if (_pinUntil == null || until.isAfter(_pinUntil!)) _pinUntil = until;
    final from = now.add(after);
    if (from.isAfter(_pinFrom)) _pinFrom = from;
    _queuePin();
  }

  void _queuePin() {
    if (_pinQueued) return;
    _pinQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinQueued = false;
      if (_pinUntil == null) return;
      if (!mounted || !_scrollController.hasClients) {
        _releasePin();
        return;
      }
      final position = _scrollController.position;
      // 손으로 스크롤을 잡았으면 놓아 준다
      if (position.userScrollDirection != ScrollDirection.idle) {
        _releasePin();
        return;
      }
      final now = DateTime.now();
      final extent = position.maxScrollExtent;
      // 늦게 뜬 사진 때문에 목록이 길어졌으면 그만큼 더 붙잡는다 — 안 하면
      // 1.5초 안에 사진이 안 뜨는 느린 망에서 화면이 중간에 선다
      if (_pinExtent >= 0 &&
          extent > _pinExtent + 0.5 &&
          now.isBefore(_pinDeadline)) {
        final extended = now.add(_pinFor);
        if (extended.isAfter(_pinUntil!)) _pinUntil = extended;
      }
      _pinExtent = extent;
      if (now.isAfter(_pinFrom) && (position.pixels - extent).abs() > 0.5) {
        _scrollController.jumpTo(extent);
      }
      if (now.isAfter(_pinUntil!) || now.isAfter(_pinDeadline)) {
        _releasePin();
        return;
      }
      _queuePin();
    });
    // 화면이 그대로면 프레임이 안 도니까 직접 부른다 —
    // 사진이 늦게 떠서 목록이 길어지는 것을 기다리는 자리다
    WidgetsBinding.instance.scheduleFrame();
  }

  void _releasePin() {
    _pinUntil = null;
    _pinExtent = -1;
  }

  Future<void> _openDetail() async {
    final left = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => ChatDetailScreen(roomId: _roomId)),
    );
    // 방을 나갔으면 이 화면도 닫는다 — 없는 방에 남아 있을 수 없다
    if (left == true && mounted) Navigator.pop(context);
  }

  /// 더블탭 ❤️ — 이미 내가 눌렀으면 뺀다 (서버가 토글로 처리)
  void _toggleHeart(ChatMessage message) => _react(message, '❤️');

  Future<void> _react(ChatMessage message, String emoji) async {
    if (message.pending) return; // 아직 서버 id 가 없다
    try {
      await _store.toggleReaction(_roomId, message.id, emoji);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 내가 이 말풍선에 단 이모지 (없으면 null) — 피커의 선택 표시에 쓴다
  String? _myReaction(ChatMessage message) {
    final myId = currentUser?.id;
    for (final agg in message.reactions) {
      if (agg.minePressed(myId)) return agg.emoji;
    }
    return null;
  }

  bool _isMine(ChatMessage message) => message.senderId == currentUser?.id;

  /// 말풍선 길게 누르기 메뉴: 위 이모지 피커 + 아래 답글/전송 취소
  Future<void> _openMessageMenu(ChatMessage message) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '메시지 메뉴',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _MessageMenu(selected: _myReaction(message), mine: _isMine(message)),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
          ),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case _MessageMenu.reply:
        _replyTo(message);
      case _MessageMenu.unsend:
        _unsend(message);
      default:
        // 같은 이모지를 다시 고르면 서버가 알아서 뺀다 (토글)
        _react(message, result);
    }
  }

  void _replyTo(ChatMessage message) {
    setState(() => _replyTarget = message);
    _inputFocus.requestFocus();
  }

  /// 전송 취소 — 줄어드는 애니메이션을 먼저 보여주고 서버에 알린다
  Future<void> _unsend(ChatMessage message) async {
    setState(() => _removingIds.add(message.id));
    try {
      await _store.deleteMessage(_roomId, message.id);
    } catch (error) {
      // 못 지웠으면 되돌린다 — 지워진 것처럼 보이면 안 된다
      if (mounted) {
        setState(() => _removingIds.remove(message.id));
        AppToast.show(context, messageOf(error));
      }
    }
  }

  /// 호버 아이콘의 이모지 버튼 — 누른 아이콘 위에 이모지 캡슐만 띄운다
  /// (화면 가운데가 아니라 말풍선 곁에 뜨는 인스타그램 방식)
  Future<void> _openEmojiPicker(ChatMessage message, Offset anchor) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '이모지 피커',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(context);
        // 캡슐 크기(이모지 6개 기준)에 맞춰 화면 밖으로 나가지 않게 클램프
        const width = 286.0;
        const height = 62.0;
        final left = (anchor.dx - width / 2).clamp(
          12.0,
          size.width - width - 12.0,
        );
        final top = (anchor.dy - height - 12).clamp(
          60.0,
          size.height - height - 12.0,
        );
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                type: MaterialType.transparency,
                child: _EmojiCapsule(selected: _myReaction(message)),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (result == null || !mounted) return;
    _react(message, result);
  }

  /// PC: 말풍선에 커서를 올리면 옆에 뜨는 작은 액션 아이콘들 (삭제·답글·이모지)
  Widget _hoverActions(ChatMessage message) {
    return ValueListenableBuilder<String?>(
      valueListenable: _hovered,
      builder: (context, hovered, _) {
        final visible = hovered == message.id;
        return AnimatedOpacity(
          duration: Duration(milliseconds: 120),
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _isMine(message)
                  // 말풍선 왼쪽에 붙으므로 바깥부터 삭제 → 답글 → 이모지 순
                  ? [
                      _hoverIcon(
                        Icons.delete_outline_rounded,
                        (_) => _unsend(message),
                      ),
                      _hoverIcon(Icons.reply_rounded, (_) => _replyTo(message)),
                      _hoverIcon(
                        Icons.mood_rounded,
                        (anchor) => _openEmojiPicker(message, anchor),
                      ),
                    ]
                  // 상대 말풍선은 오른쪽에 붙는다 (전송 취소는 내 메시지 전용)
                  : [
                      _hoverIcon(
                        Icons.mood_rounded,
                        (anchor) => _openEmojiPicker(message, anchor),
                      ),
                      _hoverIcon(Icons.reply_rounded, (_) => _replyTo(message)),
                    ],
            ),
          ),
        );
      },
    );
  }

  /// 콜백에 아이콘의 화면 중심 좌표를 넘긴다 (이모지 캡슐 앵커용)
  Widget _hoverIcon(IconData icon, void Function(Offset anchor) onTap) {
    return Builder(
      builder: (context) => Pressable(
        onTap: () {
          final box = context.findRenderObject() as RenderBox;
          onTap(box.localToGlobal(box.size.center(Offset.zero)));
        },
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: AppColors.gray500),
        ),
      ),
    );
  }

  /// 상대가 치고 있으면 대화 맨 아래에 붙는 한 줄
  ///
  /// 목록이 아니라 대화 안에서도 보여야 답을 기다릴지 알 수 있다.
  /// 붙었다 사라지는 줄이라 고정 요소가 늘지 않는다.
  String? get _typingLabel {
    final who = _store.typingIn(_roomId);
    if (who.isEmpty) return null;
    final names = [
      for (final id in who) ?StaffDirectory.instance.byId(id)?.name,
    ];
    if (names.isEmpty) return '입력 중…';
    if (names.length == 1) return '${names.first}님이 입력 중…';
    return '${names.first}님 외 ${names.length - 1}명이 입력 중…';
  }

  /// 마지막 내 메시지 아래에 붙는 '읽음' — 목업의 그 자리 그대로다
  String? get _readLabel {
    final messages = _messages;
    if (messages.isEmpty) return null;
    final last = messages.last;
    if (!_isMine(last) || last.pending || last.readCount == 0) return null;
    return '읽음';
  }

  bool _sameMessageMinute(ChatMessage previous, ChatMessage message) {
    final previousTime = previous.createdAt;
    final messageTime = message.createdAt;
    return !previous.isSystem &&
        !message.isSystem &&
        previous.senderId == message.senderId &&
        previousTime.year == messageTime.year &&
        previousTime.month == messageTime.month &&
        previousTime.day == messageTime.day &&
        previousTime.hour == messageTime.hour &&
        previousTime.minute == messageTime.minute;
  }

  /// 하루가 바뀌는 자리에 날짜 구분선을 넣기 위해 본다
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _messageTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
  }

  /// 말풍선 한 줄 — 시스템 안내는 가운데 회색 글로 그린다
  Widget _messageRow(
    ChatMessage message,
    bool desktop,
    bool showSender,
    bool showTime,
  ) {
    if (message.isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final mine = _isMine(message);
    final sender = StaffDirectory.instance.byId(message.senderId);
    final name = sender?.name ?? '알 수 없음';

    return _RemovableMessage(
      key: ValueKey(message.id),
      removing: _removingIds.contains(message.id),
      mine: mine,
      child: MouseRegion(
        onEnter: (_) => _hovered.value = message.id,
        onExit: (_) {
          if (_hovered.value == message.id) _hovered.value = null;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mine
                ? _MyBubble(
                    text: message.body,
                    sender: name,
                    sentAt: message.createdAt,
                    timeLabel: _messageTime(message.createdAt),
                    showTime: showTime,
                    attachments: message.attachments,
                    replyTo: message.replyTo?.preview,
                    pending: message.pending,
                    onDoubleTap: () => _toggleHeart(message),
                    onLongPress: () => _openMessageMenu(message),
                    actions: desktop ? _hoverActions(message) : null,
                  )
                : _TheirBubble(
                    name: name,
                    sentAt: message.createdAt,
                    color: sender?.color ?? staffOf(name).color,
                    emoji: null,
                    text: message.body,
                    timeLabel: _messageTime(message.createdAt),
                    showProfile: showSender,
                    showTime: showTime,
                    attachments: message.attachments,
                    replyTo: message.replyTo?.preview,
                    onDoubleTap: () => _toggleHeart(message),
                    onLongPress: () => _openMessageMenu(message),
                    actions: desktop ? _hoverActions(message) : null,
                  ),
            // 리액션 알약은 **말풍선 아래 제 줄**에 선다.
            //
            // 예전에는 말풍선 모서리에 겹쳐 띄웠는데, 이모지 종류가 둘 이상
            // 붙으면 알약 줄이 짧은 말풍선보다 길어져서 **옆에 선 시각을 덮었다.**
            // 자리를 따로 주면 몇 종이 붙어도 겹칠 일이 없다.
            AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: message.reactions.isEmpty
                  ? SizedBox(width: double.infinity, height: 8)
                  : Padding(
                      // 상대 말풍선은 프로필 자리(48) 만큼 들어와서 선다
                      padding: EdgeInsets.fromLTRB(
                        mine ? 0 : 52,
                        4,
                        mine ? 4 : 0,
                        10,
                      ),
                      child: Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _ReactionPills(
                          reactions: message.reactions,
                          mine: mine,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PC에서만 말풍선 호버 액션 아이콘을 보여준다
    final desktop = isDesktop;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            // 바닥에 앉기 전에는 안 그린다 ([_placed]) — 자리를 잡는 한 프레임이
            // 눈에 띈다. `Opacity(0)` 은 **자리는 재고 그리지만 않는다**
            child: Opacity(
              opacity: _placed ? 1 : 0,
              child: ListView(
                controller: _scrollController,
                // 하단 여백은 입력바 높이(52+10)에 딱 맞게 — 고정 120이면
                // 홈 인디케이터가 없는 데스크톱에서 마지막 말풍선과 너무 벌어진다
                padding: EdgeInsets.fromLTRB(
                  20,
                  70,
                  20,
                  MediaQuery.paddingOf(context).bottom + 72,
                ),
                children: [
                  // 인스타 DM 처럼 **하루마다** 구분선을 넣는다. 예전에는 맨 위에
                  // '오늘' 이 한 줄 박혀 있어서, 어제 대화도 오늘 것처럼 보였다
                  for (var index = 0; index < _messages.length; index++) ...[
                    if (index == 0 ||
                        !_sameDay(
                          _messages[index - 1].createdAt,
                          _messages[index].createdAt,
                        ))
                      _DaySeparator(day: _messages[index].createdAt),
                    _messageRow(
                      _messages[index],
                      desktop,
                      index == 0 ||
                          !_sameMessageMinute(
                            _messages[index - 1],
                            _messages[index],
                          ),
                      index == _messages.length - 1 ||
                          !_sameMessageMinute(
                            _messages[index],
                            _messages[index + 1],
                          ),
                    ),
                  ],
                  if (_readLabel case final label?)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  if (_typingLabel case final label?)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 상단 고정 프로스트 — 대화가 헤더 뒤로 흐려진다
          TopFrost(collapse: TopFrost.always, color: AppColors.surface),
          // 상단 헤더: 뒤로가기 + 아바타 + 이름 (인스타 DM 스타일 좌측 정렬)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                children: [
                  // 사진 크게 보기가 떠 있는 동안은 터치를 안 받는다 —
                  // 뷰어의 닫기 `<` 와 자리가 겹쳐서 같이 눌린다
                  // (chat_photo_viewer.dart 의 photoViewerOpen 참고)
                  ValueListenableBuilder<bool>(
                    valueListenable: photoViewerOpen,
                    builder: (_, open, _) => GlassIconButton(
                      symbol: 'chevron.backward',
                      enabled: !open,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(width: 4),
                  // 이름 영역 탭 → 채팅방 상세로 이동
                  Expanded(
                    child: Pressable(
                      onTap: _openDetail,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _headColor.withValues(
                                alpha: _isGroup ? 0.12 : 1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _isGroup ? '💬' : _title.characters.first,
                              style: _isGroup
                                  ? TextStyle(fontSize: 15)
                                  : TextStyle(
                                      fontFamily: AppTextStyles.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.title3,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 15,
                            color: AppColors.gray400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 하단 고정 글래스 입력바 — 키보드와 함께 상승
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GlassInputBar(
                  onSend: _send,
                  focusNode: _inputFocus,
                  replyLabel: _replyTarget?.body,
                  onChanged: (_) => _onTyping(),
                  onAttach: _uploading ? null : _attach,
                  onCancelReply: () => setState(() => _replyTarget = null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
