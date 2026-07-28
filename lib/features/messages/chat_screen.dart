import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';

/// 채팅방 화면 (인스타그램 DM 스타일 목업)
///
/// 메시지는 하드코딩된 샘플이며, 기능 개발 시 실제 채팅 데이터로 교체한다.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.name,
    required this.color,
    this.emoji,
  });

  final String name;
  final Color color;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 120),
              children: [
                const Center(child: Text('오늘', style: AppTextStyles.caption)),
                const SizedBox(height: 16),
                _TheirBubble(
                  name: name,
                  color: color,
                  emoji: emoji,
                  text: '은후님 혹시 내일 오전 근무 가능하실까요?',
                ),
                const SizedBox(height: 8),
                const _MyBubble(text: '네 가능합니다! 몇 시부터인가요?'),
                const SizedBox(height: 8),
                _TheirBubble(
                  name: name,
                  color: color,
                  emoji: emoji,
                  text: '9시부터 부탁드려요 🙏',
                ),
                const SizedBox(height: 8),
                const _MyBubble(text: '네 알겠습니다!'),
              ],
            ),
          ),
          // 상단 고정 프로스트 — 대화가 헤더 뒤로 흐려진다
          const TopFrost(collapse: 1, color: AppColors.surface),
          // 상단 헤더: 뒤로가기 + 아바타 + 이름 (인스타 DM 스타일 좌측 정렬)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                children: [
                  GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(
                              alpha: emoji != null ? 0.12 : 1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji ?? name.characters.first,
                            style: emoji != null
                                ? const TextStyle(fontSize: 15)
                                : const TextStyle(
                                    fontFamily: AppTextStyles.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(name, style: AppTextStyles.title3),
                        const SizedBox(width: 2),
                        const Icon(
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
          const Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _MessageInputBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyBubble extends StatelessWidget {
  const _MyBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
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
    );
  }
}

class _TheirBubble extends StatelessWidget {
  const _TheirBubble({
    required this.name,
    required this.color,
    required this.text,
    this.emoji,
  });

  final String name;
  final Color color;
  final String? emoji;
  final String text;

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
                ? const TextStyle(fontSize: 12)
                : const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
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
      ],
    );
  }
}

class _MessageInputBar extends StatefulWidget {
  const _MessageInputBar();

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
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
            padding: const EdgeInsets.only(left: 18, right: 8),
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
                const SizedBox(width: 8),
                // 입력 전에는 링크 아이콘, 입력 중에는 파란 전송(비행기) 버튼
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _hasText
                      ? GestureDetector(
                          key: const ValueKey('send'),
                          onTap: () => _controller.clear(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.paperplane_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('link'),
                          onTap: () {},
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: const Icon(
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
