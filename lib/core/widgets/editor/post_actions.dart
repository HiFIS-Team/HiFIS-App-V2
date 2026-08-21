import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/client/api_exception.dart';
import '../../api/notice/comment_api.dart';
import '../../api/notice/reaction_api.dart';
import '../../data/current_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../feedback/app_toast.dart';
import '../glass/glass_surface.dart';
import '../input/pressable.dart';
import 'post_comment_sheet.dart';
import 'reaction_row.dart';

// 쓰는 쪽이 대상과 집계 타입을 같이 받도록 함께 내보낸다
export '../../api/notice/reaction_api.dart' show ReactionAgg, ReactionTarget;

/// 하트로 고정된 반응 이모지 (2026-08-19 대표 결정)
///
/// 예전에는 여섯 개 중에 골랐는데(`reactionEmojis`), 인스타처럼 **하트 하나**로
/// 좁혔다. 서버는 그대로 이모지 문자열을 받으므로 이 값만 보낸다.
///
/// 이미 달려 있는 다른 이모지(👍 등)는 DB 에 남아 있지만 화면에는 안 나온다.
const heartEmoji = '❤️';

/// 글 아래 떠 있는 하트·댓글 바 (공지·회의록·프로젝트 공용)
///
/// ```
///        ╭──────────────────────╮
///        │   ♡ 12      💬 3     │   ← 리퀴드 글래스
///        ╰──────────────────────╯
/// ```
///
/// - 하트를 **한 번 누르면** 빨갛게 채워지고, **꾹 누르면** 누가 눌렀는지 뜬다
/// - 말풍선을 누르면 댓글이 아래에서 올라온다
///
/// ## 오른쪽 세로 줄이었다가 아래 가로 바가 됐다 (2026-08-19)
///
/// 처음에는 인스타처럼 **글 오른쪽에 세로로** 띄웠다. 인스타는 꽉 찬 영상
/// 위라 아이콘만 얹어도 되는데, 우리는 **흰 카드 위**라 카드 글자와 겹쳐
/// 얹힌 것처럼 보였다 (`활동 4` 옆에 하트가 물렸다). 캡슐을 둘러 봐도
/// 여전히 붕 떠 보여서, 앱이 원래 쓰던 자리인 **화면 아래 글래스 바**로 옮겼다.
///
/// 검색바·입력바와 **같은 재질**이다 ([GlassSurface]) — 애플에서는 애플이
/// 직접 그리고, 나머지는 블러로 떨어진다.
///
/// ⚠️ 안에 [GlassIconButton] 같은 **네이티브 버튼을 두지 않는다** — 유리 면과
/// 같은 `Row` 에 두면 탭이 `onPressed` 까지 안 온다 (CLAUDE.md).
/// 여기 든 것은 전부 [Pressable] + [Icon] 이다.
class PostActions extends StatefulWidget {
  PostActions({
    super.key,
    required this.target,
    required this.targetId,
    required this.reactions,
    required this.onToggled,
    required this.commentCount,
    required this.onCommentCount,
  });

  /// 반응 대상 — 댓글 대상은 여기서 끌어낸다 (둘이 같은 글이다)
  final ReactionTarget target;

  /// 서버 uuid — **null 이면 아직 안 올린 글**이라 아무것도 안 그린다
  final String? targetId;

  final List<ReactionAgg> reactions;

  /// 토글 뒤 새 집계
  final ValueChanged<List<ReactionAgg>> onToggled;

  final int commentCount;

  /// 댓글이 늘거나 줄었을 때 — 화면이 자기 모델에 반영한다
  final ValueChanged<int> onCommentCount;

  /// 바 높이
  static const height = 52.0;

  /// **본문이 비워 줘야 하는 아래 여백** — 목록 padding 에 더한다.
  /// 바에 가려 마지막 줄이 안 보이면 안 된다
  static const inset = height + 24;

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  /// 응답을 기다리는 중 — 연타로 요청이 엇갈리는 걸 막는다
  bool _pending = false;

  ReactionAgg? get _heart {
    for (final reaction in widget.reactions) {
      if (reaction.emoji == heartEmoji) return reaction;
    }
    return null;
  }

  bool get _mine => _heart?.minePressed(currentUser?.id) ?? false;

  Future<void> _toggle() async {
    final id = widget.targetId;
    if (id == null || _pending) return;

    setState(() => _pending = true);
    HapticFeedback.selectionClick();
    try {
      final reactions = await ReactionApi.toggle(
        target: widget.target,
        targetId: id,
        emoji: heartEmoji,
      );
      if (mounted) widget.onToggled(reactions);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _pending = false);
  }

  /// 꾹 누르기 — 누가 눌렀는지. 아무도 안 눌렀으면 열 것이 없다
  void _who() {
    final heart = _heart;
    if (heart == null || heart.count == 0) return;
    HapticFeedback.mediumImpact();
    showReactionPeople(context, [heart], emoji: heartEmoji);
  }

  Future<void> _comments() async {
    final id = widget.targetId;
    if (id == null) return;
    await showPostComments(
      context,
      target: switch (widget.target) {
        ReactionTarget.notice => CommentTarget.notice,
        ReactionTarget.project => CommentTarget.project,
        // 사내톡 말풍선은 여기 안 온다 (반응만 있고 댓글이 없다)
        _ => CommentTarget.meeting,
      },
      targetId: id,
      onCount: (count) {
        if (mounted) widget.onCommentCount(count);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targetId == null) return SizedBox.shrink();
    final hearts = _heart?.count ?? 0;

    return GlassSurface(
      radius: 26,
      // 누르는 면이라 유리가 눌리는 반응을 켠다 (검색바와 같다)
      interactive: true,
      // 애플이 아닌 곳에서 검색바가 쓰던 값 그대로
      fallbackColor: AppColors.surface.withValues(alpha: 0.72),
      fallbackBorder: Border.all(color: AppColors.gray100),
      child: SizedBox(
        height: PostActions.height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: _mine
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              // 내가 누른 하트만 빨갛다 — 개수는 그대로 회색이라 숫자가 안 튄다
              color: _mine ? AppColors.error : AppColors.textSecondary,
              count: hearts,
              onTap: _toggle,
              onLongPress: _who,
            ),
            _ActionButton(
              icon: Icons.mode_comment_outlined,
              color: AppColors.textSecondary,
              count: widget.commentCount,
              onTap: _comments,
            ),
          ],
        ),
      ),
    );
  }
}

/// 아이콘 하나 + 옆 숫자 — 0 이면 숫자를 안 그린다
class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          // 아직 아무도 안 눌렀으면 `0` 대신 비워 둔다 — 바가 덜 어수선하다
          if (count > 0) ...[
            SizedBox(width: 6),
            Text(
              '$count',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
