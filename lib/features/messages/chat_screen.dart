import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/client/api_client.dart' show fileUrl;
import '../../core/api/client/api_exception.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_input_bar.dart';
import '../../core/widgets/glass/top_frost.dart';
import '../../core/widgets/input/pressable.dart';
import 'chat_detail_screen.dart';
import 'chat_store.dart';

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

class _ChatScreenState extends State<ChatScreen> {
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

  /// 파일을 올리는 중 — 두 번 눌러 두 번 보내지 않게 잠근다
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _scrollController.addListener(_onScroll);
    _open();
  }

  /// 위로 끝까지 올리면 이전 대화를 더 받아온다
  ///
  /// **버튼을 두지 않는다** — 화면에 없던 요소를 새로 만들지 않고, 카톡·인스타처럼
  /// 위로 당기면 알아서 이어 붙는다.
  void _onScroll() {
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
    _scrollToBottom();
  }

  /// 새 메시지가 들어오면 아래에 붙어 있던 화면은 따라 내려간다
  void _onStore() {
    if (!mounted) return;
    final atBottom =
        !_scrollController.hasClients ||
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80;
    setState(() {});
    if (atBottom) _scrollToBottom();
    // 열어 둔 방에 새 글이 오면 바로 읽은 것으로 친다
    if (_room?.unreadCount case final unread? when unread > 0) {
      _store.markRead(_roomId);
    }
  }

  @override
  void dispose() {
    _hovered.dispose();
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
  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(allowMultiple: true);
    final files = [
      for (final f in picked?.files ?? const <PlatformFile>[])
        if (f.path case final path?) (path, f.name),
    ];
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      await _store.sendFiles(_roomId, files);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
        scale: 0.9,
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

  /// 말풍선 한 줄 — 시스템 안내는 가운데 회색 글로 그린다
  Widget _messageRow(ChatMessage message, bool desktop) {
    if (message.isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    final mine = _isMine(message);
    final sender = StaffDirectory.instance.byId(message.senderId);
    final name = sender?.name ?? '알 수 없음';
    final reaction = message.reactions.isEmpty
        ? null
        : message.reactions.first.emoji;

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
                    attachments: message.attachments,
                    replyTo: message.replyTo?.preview,
                    reaction: reaction,
                    pending: message.pending,
                    onDoubleTap: () => _toggleHeart(message),
                    onLongPress: () => _openMessageMenu(message),
                    actions: desktop ? _hoverActions(message) : null,
                  )
                : _TheirBubble(
                    name: name,
                    color: sender?.color ?? staffOf(name).color,
                    emoji: null,
                    text: message.body,
                    attachments: message.attachments,
                    replyTo: message.replyTo?.preview,
                    reaction: reaction,
                    onDoubleTap: () => _toggleHeart(message),
                    onLongPress: () => _openMessageMenu(message),
                    actions: desktop ? _hoverActions(message) : null,
                  ),
            // 리액션 알약이 말풍선 아래로 삐져나오는 만큼 간격을 더 준다
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: reaction != null ? 22 : 8,
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
                Center(child: Text('오늘', style: AppTextStyles.caption)),
                SizedBox(height: 16),
                for (final message in _messages) _messageRow(message, desktop),
                if (_readLabel case final label?)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text(
                        label,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
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
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
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
                  GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 4),
                  // 이름 영역 탭 → 채팅방 상세로 이동
                  Pressable(
                    onTap: _openDetail,
                    scale: 0.94,
                    pressedColor: AppColors.gray100,
                    borderRadius: BorderRadius.circular(24),
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
                        // **Flexible 로 감싸지 않는다** — 이 Row 는 폭이 무한대라
                        // flex 를 주면 레이아웃이 실패하고 화면 전체가 안 그려진다
                        // (실제 발생: 입력칸이 안 보이고 멈춘 것처럼 됐다)
                        Text(_title, style: AppTextStyles.title3),
                        SizedBox(width: 2),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          size: 15,
                          color: AppColors.gray400,
                        ),
                      ],
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

class _RemovableMessage extends StatelessWidget {
  _RemovableMessage({
    super.key,
    required this.removing,
    required this.mine,
    required this.child,
  });

  final bool removing;
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: removing ? 0.0 : 1.0),
      duration: Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      builder: (context, t, child) => ClipRect(
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            heightFactor: t,
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// 말풍선 안의 첨부 — 사진이면 미리보기, 아니면 파일 이름 한 줄
///
/// **말풍선 밖에 새로 그리는 것이 없다.** 본문 글자가 들어가던 자리에
/// 같은 폭으로 들어간다.
class _Attachments extends StatelessWidget {
  _Attachments({required this.urls, required this.mine});

  final List<String> urls;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final tint = mine ? Colors.white : AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final url in urls)
          Padding(
            padding: EdgeInsets.only(bottom: url == urls.last ? 0 : 6),
            child: isImageAttachment(url)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fileUrl(url),
                      width: 200,
                      fit: BoxFit.cover,
                      // 못 받아오면(서명 만료 등) 파일 줄로 떨어진다
                      errorBuilder: (_, _, _) => _file(url, tint),
                    ),
                  )
                : _file(url, tint),
          ),
      ],
    );
  }

  Widget _file(String url, Color tint) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(CupertinoIcons.doc, size: 15, color: tint),
      SizedBox(width: 6),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 200),
        child: Text(
          _nameOf(url),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(color: tint),
        ),
      ),
    ],
  );

  /// `/files/2026/08/abc.png?exp=..` 에서 보여줄 이름만 뽑는다
  static String _nameOf(String url) {
    final path = url.split('?').first;
    return path.substring(path.lastIndexOf('/') + 1);
  }
}

class _MyBubble extends StatelessWidget {
  _MyBubble({
    required this.text,
    this.attachments = const [],
    this.replyTo,
    this.reaction,
    this.pending = false,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String text;
  final List<String> attachments;
  final String? replyTo;
  final String? reaction;

  /// 아직 서버 응답을 못 받았다 — 살짝 흐리게 그려 보내는 중임을 알린다
  final bool pending;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// PC 호버 액션 아이콘 (말풍선 왼쪽에 붙는다)
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions != null) ...[actions!, SizedBox(width: 4)],
          Flexible(child: _bubble()),
        ],
      ),
    );
  }

  Widget _bubble() {
    return Opacity(
      // 보내는 중에는 살짝 흐리다 — 서버가 받으면 또렷해진다
      opacity: pending ? 0.55 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(maxWidth: 280),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTo != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        replyTo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: AppTextStyles.body2.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (reaction != null)
            Positioned(
              bottom: -14,
              right: 10,
              child: _ReactionPill(
                key: ValueKey(reaction!),
                emoji: reaction!,
                onTap: onLongPress,
              ),
            ),
        ],
      ),
    );
  }
}

class _TheirBubble extends StatelessWidget {
  _TheirBubble({
    required this.name,
    required this.color,
    required this.text,
    this.attachments = const [],
    this.emoji,
    this.replyTo,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String name;
  final Color color;
  final String? emoji;
  final String text;
  final List<String> attachments;
  final String? replyTo;
  final String? reaction;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// PC 호버 액션 아이콘 (말풍선 오른쪽에 붙는다)
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: emoji != null ? 0.12 : 1),
            shape: BoxShape.circle,
          ),
          child: Text(
            emoji ?? name.characters.first,
            style: emoji != null
                ? TextStyle(fontSize: 12)
                : TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onDoubleTap: onDoubleTap,
                onLongPress: onLongPress,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 260),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyTo != null)
                        Container(
                          margin: EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            replyTo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      if (attachments.isNotEmpty)
                        _Attachments(urls: attachments, mine: false),
                      if (text.isNotEmpty) ...[
                        if (attachments.isNotEmpty) SizedBox(height: 6),
                        Text(text, style: AppTextStyles.body2),
                      ],
                    ],
                  ),
                ),
              ),
              if (reaction != null)
                Positioned(
                  bottom: -14,
                  left: 10,
                  child: _ReactionPill(
                    key: ValueKey(reaction!),
                    emoji: reaction!,
                    onTap: onLongPress,
                  ),
                ),
            ],
          ),
        ),
        if (actions != null) ...[SizedBox(width: 4), actions!],
      ],
    );
  }
}

/// 말풍선 모서리에 겹쳐 붙는 리액션 알약. 탭하면 피커가 다시 열린다.
/// key가 이모지 값이라, 리액션이 새로 달리거나 바뀔 때마다 팝 애니메이션이 재생된다.
class _ReactionPill extends StatelessWidget {
  _ReactionPill({super.key, required this.emoji, this.onTap});

  final String emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 24,
          padding: EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.gray100),
            boxShadow: [
              BoxShadow(
                color: Color(0x14101828),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: _EmojiText(emoji, size: 13),
        ),
      ),
    );
  }
}

/// 이모지 피커 글래스 캡슐 — 탭하면 해당 이모지 문자열로 pop된다.
/// 가운데 메뉴(_MessageMenu)와 PC 호버 앵커 팝업 양쪽에서 쓴다.
class _EmojiCapsule extends StatelessWidget {
  _EmojiCapsule({this.selected});

  /// 이미 달려 있는 리액션 (선택 표시용)
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.gray100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final emoji in _reactionEmojis)
                GestureDetector(
                  onTap: () => Navigator.pop(context, emoji),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: emoji == selected
                          ? AppColors.gray100
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: _EmojiText(emoji, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 길게 누르면 뜨는 메시지 메뉴 — 위에는 이모지 피커, 아래에는 액션 목록.
/// 이모지 문자열 또는 [reply]/[unsend] 액션 값으로 pop된다.
class _MessageMenu extends StatelessWidget {
  _MessageMenu({this.selected, required this.mine});

  static const reply = 'menu:reply';
  static const unsend = 'menu:unsend';

  final String? selected;

  /// 내 메시지 여부. 전송 취소는 내 메시지에서만 보여준다.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이모지 피커 글래스 캡슐
            _EmojiCapsule(selected: selected),
            SizedBox(height: 12),
            // 액션 메뉴 카드
            _actionCard(context),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F101828),
            blurRadius: 32,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuRow(
            label: '답글 달기',
            icon: CupertinoIcons.arrowshape_turn_up_left,
            onTap: () => Navigator.pop(context, reply),
          ),
          if (mine) ...[
            Container(height: 1, color: AppColors.gray100),
            _MenuRow(
              label: '전송 취소',
              icon: CupertinoIcons.trash,
              color: AppColors.error,
              onTap: () => Navigator.pop(context, unsend),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  _MenuRow({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body2.copyWith(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(icon, size: 18, color: color ?? AppColors.gray600),
          ],
        ),
      ),
    );
  }
}
