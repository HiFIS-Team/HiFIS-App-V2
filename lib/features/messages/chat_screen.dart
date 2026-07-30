import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/top_frost.dart';
import 'chat_detail_screen.dart';

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

/// 채팅방 화면 (인스타그램 DM 스타일 목업)
///
/// 메시지는 하드코딩된 샘플이며, 기능 개발 시 실제 채팅 데이터로 교체한다.
/// 말풍선 더블탭 → ❤️ 토글, 길게 누르기 → 이모지 피커.
class ChatScreen extends StatefulWidget {
  ChatScreen({super.key, required this.name, required this.color, this.emoji});

  final String name;
  final Color color;
  final String? emoji;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  /// PC에서 커서가 올라가 있는 말풍선 (호버 액션 아이콘 표시용)
  _ChatMessage? _hovered;

  /// 채팅방 이름 (상세 화면에서 변경 가능)
  late String _title = widget.name;

  /// 답글 작성 대상 메시지 (없으면 일반 전송)
  _ChatMessage? _replyTarget;

  final List<_ChatMessage> _messages = [
    _ChatMessage(text: '은후님 혹시 내일 오전 근무 가능하실까요?', mine: false),
    _ChatMessage(text: '네 가능합니다! 몇 시부터인가요?', mine: true),
    _ChatMessage(text: '9시부터 부탁드려요 🙏', mine: false, reaction: '❤️'),
    _ChatMessage(text: '네 알겠습니다!', mine: true, read: true),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send(String text) {
    final sent = _ChatMessage(
      text: text,
      mine: true,
      replyTo: _replyTarget?.text,
    );
    setState(() {
      _messages.add(sent);
      _replyTarget = null;
    });
    // 목업: 잠시 후 상대가 읽은 것으로 처리해 읽음 표시를 보여준다.
    // TODO: 실제 채팅 연동 시 읽음 이벤트로 교체
    Timer(Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => sent.read = true);
      // 읽음 줄이 생기며 늘어난 높이만큼 더 내려서 입력바에 가려지지 않게 한다
      _scrollToBottom();
    });
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

  void _openDetail() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ChatDetailScreen(
          name: _title,
          color: widget.color,
          emoji: widget.emoji,
          onInvite: _onMembersInvited,
          onRename: (value) => setState(() => _title = value),
        ),
      ),
    );
  }

  /// 상세 화면에서 멤버 초대가 확정되면 회색 시스템 메시지를 남긴다
  void _onMembersInvited(List<String> names) {
    final label = names.length == 1
        ? '${names.first}님이 초대되었습니다'
        : '${names.first}님 외 ${names.length - 1}명이 초대되었습니다';
    setState(
      () => _messages.add(_ChatMessage(text: label, mine: false, system: true)),
    );
    _scrollToBottom();
  }

  void _toggleHeart(_ChatMessage message) {
    setState(() => message.reaction = message.reaction == '❤️' ? null : '❤️');
  }

  /// 말풍선 길게 누르기 메뉴: 위 이모지 피커 + 아래 답글/전송 취소
  Future<void> _openMessageMenu(_ChatMessage message) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '메시지 메뉴',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _MessageMenu(selected: message.reaction, mine: message.mine),
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
        // 이미 달린 이모지를 다시 고르면 리액션을 제거한다
        setState(
          () => message.reaction = result == message.reaction ? null : result,
        );
    }
  }

  void _replyTo(_ChatMessage message) {
    setState(() => _replyTarget = message);
    _inputFocus.requestFocus();
  }

  void _unsend(_ChatMessage message) {
    // 줄어드는 애니메이션이 끝난 뒤 실제로 제거한다
    setState(() => message.removing = true);
    Timer(Duration(milliseconds: 260), () {
      if (mounted) setState(() => _messages.remove(message));
    });
  }

  /// 호버 아이콘의 이모지 버튼 — 누른 아이콘 위에 이모지 캡슐만 띄운다
  /// (화면 가운데가 아니라 말풍선 곁에 뜨는 인스타그램 방식)
  Future<void> _openEmojiPicker(_ChatMessage message, Offset anchor) async {
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
                child: _EmojiCapsule(selected: message.reaction),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (result == null || !mounted) return;
    setState(
      () => message.reaction = result == message.reaction ? null : result,
    );
  }

  /// PC: 말풍선에 커서를 올리면 옆에 뜨는 작은 액션 아이콘들 (삭제·답글·이모지)
  Widget _hoverActions(_ChatMessage message) {
    final visible = _hovered == message;
    return AnimatedOpacity(
      duration: Duration(milliseconds: 120),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: message.mine
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
                for (final message in _messages)
                  if (message.system)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Text(message.text, style: AppTextStyles.caption),
                      ),
                    )
                  else
                    _RemovableMessage(
                      key: ObjectKey(message),
                      removing: message.removing,
                      mine: message.mine,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hovered = message),
                        onExit: (_) => setState(() {
                          if (_hovered == message) _hovered = null;
                        }),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            message.mine
                                ? _MyBubble(
                                    text: message.text,
                                    replyTo: message.replyTo,
                                    reaction: message.reaction,
                                    onDoubleTap: () => _toggleHeart(message),
                                    onLongPress: () =>
                                        _openMessageMenu(message),
                                    actions: desktop
                                        ? _hoverActions(message)
                                        : null,
                                  )
                                : _TheirBubble(
                                    name: _title,
                                    color: widget.color,
                                    emoji: widget.emoji,
                                    text: message.text,
                                    replyTo: message.replyTo,
                                    reaction: message.reaction,
                                    onDoubleTap: () => _toggleHeart(message),
                                    onLongPress: () =>
                                        _openMessageMenu(message),
                                    actions: desktop
                                        ? _hoverActions(message)
                                        : null,
                                  ),
                            // 리액션 알약이 말풍선 아래로 삐져나오는 만큼 간격을 더 준다
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              height: message.reaction != null ? 22 : 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                if (_messages.isNotEmpty &&
                    _messages.last.mine &&
                    _messages.last.read)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text(
                        '읽음',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
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
                            color: widget.color.withValues(
                              alpha: widget.emoji != null ? 0.12 : 1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            widget.emoji ?? _title.characters.first,
                            style: widget.emoji != null
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
                child: _MessageInputBar(
                  onSend: _send,
                  focusNode: _inputFocus,
                  replyLabel: _replyTarget?.text,
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

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.mine,
    this.reaction,
    this.read = false,
    this.replyTo,
    this.system = false,
  });

  final String text;
  final bool mine;

  /// 초대 안내처럼 가운데 회색으로 표시되는 시스템 메시지 여부
  final bool system;

  /// 답글 대상 메시지의 원문 (답글이 아니면 null)
  final String? replyTo;

  /// 말풍선에 달린 리액션 이모지 (없으면 null)
  String? reaction;

  /// 상대가 읽었는지 여부 (내 메시지에만 의미 있음)
  bool read;

  /// 전송 취소로 사라지는 중인지 여부 (애니메이션 후 리스트에서 제거)
  bool removing = false;
}

/// 전송 취소 시 말풍선이 줄어들고 흐려지며 사라지는 애니메이션 래퍼
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

class _MyBubble extends StatelessWidget {
  _MyBubble({
    required this.text,
    this.replyTo,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String text;
  final String? replyTo;
  final String? reaction;
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
    return Stack(
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
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}

class _TheirBubble extends StatelessWidget {
  _TheirBubble({
    required this.name,
    required this.color,
    required this.text,
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
                      Text(text, style: AppTextStyles.body2),
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

class _MessageInputBar extends StatefulWidget {
  _MessageInputBar({
    required this.onSend,
    this.focusNode,
    this.replyLabel,
    this.onCancelReply,
  });

  final ValueChanged<String> onSend;
  final FocusNode? focusNode;

  /// 답글 대상 원문. 있으면 입력바 위에 인용 줄이 표시된다.
  final String? replyLabel;
  final VoidCallback? onCancelReply;

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    // 엔터/전송 후 포커스가 풀리므로 다시 잡아 연속 입력이 되게 한다
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F101828),
            blurRadius: 32,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              // 네이티브 글래스의 림처럼 보이는 헤어라인 — 흰 배경에서도 구분되게
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 답글 인용 줄
                if (widget.replyLabel != null)
                  Padding(
                    padding: EdgeInsets.only(top: 12, right: 10),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.arrowshape_turn_up_left,
                          size: 14,
                          color: AppColors.gray500,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.replyLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onCancelReply,
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          style: AppTextStyles.body2,
                          cursorColor: AppColors.primary,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: '메시지 보내기',
                            hintStyle: AppTextStyles.body2.copyWith(
                              color: AppColors.gray400,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // 입력 전에는 링크 아이콘, 입력 중에는 파란 전송(비행기) 버튼
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: _hasText
                            ? GestureDetector(
                                key: ValueKey('send'),
                                onTap: _submit,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.paperplane_fill,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                key: ValueKey('link'),
                                onTap: () {},
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  color: Colors.transparent,
                                  child: Icon(
                                    CupertinoIcons.link,
                                    color: AppColors.gray600,
                                    size: 22,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
