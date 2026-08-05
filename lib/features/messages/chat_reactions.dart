part of 'chat_screen.dart';

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
        boxShadow: AppShadows.float,
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
