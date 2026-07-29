import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';

/// 리액션으로 고를 수 있는 이모지 목록
const _reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

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

  final List<_ChatMessage> _messages = [
    _ChatMessage(text: '은후님 혹시 내일 오전 근무 가능하실까요?', mine: false),
    _ChatMessage(text: '네 가능합니다! 몇 시부터인가요?', mine: true),
    _ChatMessage(text: '9시부터 부탁드려요 🙏', mine: false, reaction: '❤️'),
    _ChatMessage(text: '네 알겠습니다!', mine: true, read: true),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final sent = _ChatMessage(text: text, mine: true);
    setState(() => _messages.add(sent));
    // 목업: 잠시 후 상대가 읽은 것으로 처리해 읽음 표시를 보여준다.
    // TODO: 실제 채팅 연동 시 읽음 이벤트로 교체
    Timer(Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => sent.read = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleHeart(_ChatMessage message) {
    setState(() => message.reaction = message.reaction == '❤️' ? null : '❤️');
  }

  Future<void> _pickReaction(_ChatMessage message) async {
    final emoji = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '리액션 선택',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _ReactionPicker(selected: message.reaction),
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
    if (emoji == null || !mounted) return;
    // 이미 달린 이모지를 다시 고르면 리액션을 제거한다
    setState(() => message.reaction = emoji == message.reaction ? null : emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(20, 70, 20, 120),
              children: [
                Center(child: Text('오늘', style: AppTextStyles.caption)),
                SizedBox(height: 16),
                for (final message in _messages) ...[
                  message.mine
                      ? _MyBubble(
                          text: message.text,
                          reaction: message.reaction,
                          onDoubleTap: () => _toggleHeart(message),
                          onLongPress: () => _pickReaction(message),
                        )
                      : _TheirBubble(
                          name: widget.name,
                          color: widget.color,
                          emoji: widget.emoji,
                          text: message.text,
                          reaction: message.reaction,
                          onDoubleTap: () => _toggleHeart(message),
                          onLongPress: () => _pickReaction(message),
                        ),
                  // 리액션 알약이 말풍선 아래로 삐져나오는 만큼 간격을 더 준다
                  SizedBox(height: message.reaction != null ? 22 : 8),
                ],
                if (_messages.last.mine && _messages.last.read)
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
          TopFrost(collapse: 1, color: AppColors.surface),
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
                  SizedBox(width: 12),
                  IgnorePointer(
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
                            widget.emoji ?? widget.name.characters.first,
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
                        Text(widget.name, style: AppTextStyles.title3),
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
                child: _MessageInputBar(onSend: _send),
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
  });

  final String text;
  final bool mine;

  /// 말풍선에 달린 리액션 이모지 (없으면 null)
  String? reaction;

  /// 상대가 읽었는지 여부 (내 메시지에만 의미 있음)
  bool read;
}

class _MyBubble extends StatelessWidget {
  _MyBubble({
    required this.text,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
  });

  final String text;
  final String? reaction;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
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
              child: Text(
                text,
                style: AppTextStyles.body2.copyWith(color: Colors.white),
              ),
            ),
          ),
          if (reaction != null)
            Positioned(
              bottom: -11,
              right: 10,
              child: _ReactionPill(emoji: reaction!, onTap: onLongPress),
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
    this.emoji,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
  });

  final String name;
  final Color color;
  final String? emoji;
  final String text;
  final String? reaction;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
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
                  child: Text(text, style: AppTextStyles.body2),
                ),
              ),
              if (reaction != null)
                Positioned(
                  bottom: -11,
                  left: 10,
                  child: _ReactionPill(emoji: reaction!, onTap: onLongPress),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 말풍선 모서리에 겹쳐 붙는 리액션 알약. 탭하면 피커가 다시 열린다.
class _ReactionPill extends StatelessWidget {
  _ReactionPill({required this.emoji, this.onTap});

  final String emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
        child: Text(emoji, style: TextStyle(fontSize: 13)),
      ),
    );
  }
}

/// 길게 누르면 뜨는 이모지 피커 — 화면 중앙 글래스 캡슐
class _ReactionPicker extends StatelessWidget {
  _ReactionPicker({this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.surface.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final emoji in _reactionEmojis)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, emoji),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emoji == selected
                              ? AppColors.gray100
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatefulWidget {
  _MessageInputBar({required this.onSend});

  final ValueChanged<String> onSend;

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
            height: 52,
            padding: EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
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
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
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
        ),
      ),
    );
  }
}
