part of 'chat_screen.dart';

/// 말풍선 아래에 서는 리액션 알약 줄 — 이모지 종류마다 하나씩.
///
/// **누르면 내 공감이 붙었다 뗀다** (인스타 DM 과 같다, 2026-09-07 요청).
/// 예전에는 누르면 '누가 눌렀나' 시트만 열려서, 잘못 단 것을 빼려면 말풍선을
/// 길게 눌러 피커에서 같은 이모지를 다시 골라야 했다 — 뺄 길이 숨어 있었다.
/// 누가 눌렀는지는 **꾹 누르면** 나온다 (공지·회의록과 같은 시트다).
///
/// **[Row] 가 아니라 [Wrap] 이다.** PC 사내톡 도크는 폭이 380 뿐이라, 이모지가
/// 여러 종 붙으면 한 줄에 안 들어가 노란 빗금이 뜬다. 넘치면 아랫줄로 내린다.
class ChatReactionPills extends StatelessWidget {
  ChatReactionPills({
    super.key,
    required this.reactions,
    required this.mine,
    required this.onToggle,
    required this.onWho,
  });

  final List<ReactionAgg> reactions;

  /// 내 말풍선이면 오른쪽부터 채운다 (두 줄로 넘어갔을 때 갈린다)
  final bool mine;

  /// 알약을 눌렀다 — 그 이모지로 내 공감을 붙이거나 뗀다
  final ValueChanged<String> onToggle;

  /// 알약을 꾹 눌렀다 — 누가 눌렀는지 본다
  final ValueChanged<String> onWho;

  /// 세우는 차례 — **많이 눌린 것부터, 같으면 이모지 순**
  ///
  /// 서버가 주는 차례는 행이 쌓인 순서라 다시 받을 때마다 달라질 수 있다.
  /// 그대로 두면 새로고침마다 알약이 자리를 바꿔서 **눌러 둔 것을 다시 찾아야**
  /// 한다 (여러 사람이 여러 이모지를 단 말풍선에서 실제로 흔들렸다).
  List<ReactionAgg> get _ordered {
    final rows = [...reactions];
    rows.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.emoji.compareTo(b.emoji);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final myId = currentUser?.id;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: mine ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final reaction in _ordered)
          ChatReactionPill(
            key: ValueKey(reaction.emoji),
            emoji: reaction.emoji,
            count: reaction.count,
            pressed: reaction.minePressed(myId),
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(reaction.emoji);
            },
            onLongPress: () {
              HapticFeedback.selectionClick();
              onWho(reaction.emoji);
            },
          ),
      ],
    );
  }
}

/// 알약 하나 — 이모지와 누른 사람 수.
/// key가 이모지 값이라, 리액션이 새로 달리거나 바뀔 때마다 팝 애니메이션이 재생된다.
class ChatReactionPill extends StatelessWidget {
  ChatReactionPill({
    super.key,
    required this.emoji,
    required this.count,
    required this.pressed,
    required this.onTap,
    required this.onLongPress,
  });

  final String emoji;

  /// 누른 사람 수 — 1명이면 굳이 안 적는다 (알약이 길어지기만 한다)
  final int count;

  /// **내가 누른 것** — 파랗게 물들여 뺄 수 있다는 걸 알린다.
  /// 이 표시가 없으면 어느 것이 내 것인지 알 수 없어 지울 엄두를 못 낸다.
  final bool pressed;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onLongPress: onLongPress,
        child: Container(
          // 높이 26 · 이모지 12 — **글리프가 테두리에 닿지 않게** 잡은 값이다
          // (2026-09-07 대표 지적: "이모지를 감싸는 테두리가 안 맞는다").
          // 이모지는 글자와 달리 제 네모(em)보다 크게 그려지고, 그 정도가
          // 이모지마다 다르다 — ❤️ 는 작고 😂 는 꽉 찬다. 제일 큰 것에 맞춰
          // 위아래 5px 쯤 남긴다.
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: 9),
          // **[alignment] 를 주면 안 된다.** 값이 있으면 [Container] 가 부모가
          // 준 폭을 **꽉 채우고** 그 안에 아이를 놓는다 — 알약이 화면 폭만큼
          // 늘어나 이모지 하나가 가운데 떠 있었다 (2026-09-07 대표 지적).
          // 빼면 아이(가로 최소인 [Row]) 크기로 줄어든다. 세로 가운데 정렬은
          // 높이 24 안에서 [Row] 가 알아서 한다.
          decoration: BoxDecoration(
            color: pressed ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: pressed ? AppColors.primary : AppColors.gray100,
            ),
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
              // **이모지 자리를 고정한다.** 글리프 폭이 글꼴마다 달라서 안 잡으면
              // 알약 폭이 이모지마다 몇 px 씩 달라 줄이 들쭉날쭉해 보인다.
              // 뜻밖에 넓은 이모지(다른 클라이언트가 보낸 것)는 줄여서 담는다 —
              // 잘리면 반쪽짜리 그림이 남는다.
              SizedBox(
                width: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _EmojiText(emoji, size: 12),
                ),
              ),
              if (count > 1) ...[
                SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pressed
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
