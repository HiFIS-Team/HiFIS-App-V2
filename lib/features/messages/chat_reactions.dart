part of 'chat_screen.dart';

/// 말풍선 아래에 서는 리액션 알약 줄 — 이모지 종류마다 하나씩.
///
/// 탭하면 **누가 눌렀는지** 시트가 열린다. 공지·회의록·프로젝트가 쓰던
/// [showReactionPeople] 을 그대로 부르므로 모양도 같다.
///
/// **[Row] 가 아니라 [Wrap] 이다.** PC 사내톡 도크는 폭이 380 뿐이라, 이모지가
/// 여러 종 붙으면 한 줄에 안 들어가 노란 빗금이 뜬다. 넘치면 아랫줄로 내린다.
class _ReactionPills extends StatelessWidget {
  _ReactionPills({required this.reactions, required this.mine});

  final List<ReactionAgg> reactions;

  /// 내 말풍선이면 오른쪽부터 채운다 (두 줄로 넘어갔을 때 갈린다)
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: mine ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final reaction in reactions)
          _ReactionPill(
            key: ValueKey(reaction.emoji),
            emoji: reaction.emoji,
            count: reaction.count,
            onTap: () {
              HapticFeedback.selectionClick();
              showReactionPeople(context, reactions, emoji: reaction.emoji);
            },
          ),
      ],
    );
  }
}

/// 알약 하나 — 이모지와 누른 사람 수.
/// key가 이모지 값이라, 리액션이 새로 달리거나 바뀔 때마다 팝 애니메이션이 재생된다.
class _ReactionPill extends StatelessWidget {
  _ReactionPill({
    super.key,
    required this.emoji,
    required this.count,
    required this.onTap,
  });

  final String emoji;

  /// 누른 사람 수 — 1명이면 굳이 안 적는다 (알약이 길어지기만 한다)
  final int count;

  final VoidCallback onTap;

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
      // [Pressable] 이라야 PC 에서 손가락 커서가 뜬다 — 눌러서 볼 것이 있는 자리다
      child: Pressable(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmojiText(emoji, size: 13),
              if (count > 1) ...[
                SizedBox(width: 5),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
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
    return GlassSurface(
      radius: 32,
      // 이모지를 누르는 면이라 유리 눌림 반응을 켠다
      interactive: true,
      // 애플이 아닌 곳에서 쓰던 값 그대로 — 화면이 안 바뀐다
      fallbackColor: AppColors.surface.withValues(alpha: 0.8),
      fallbackBorder: Border.all(color: AppColors.gray100),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
