import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../api/reaction_api.dart';
import '../data/current_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_toast.dart';
import 'pressable.dart';

/// 고를 수 있는 이모지 — 사내톡 말풍선 반응과 같은 목록
const reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

/// 본문 아래 이모지 반응 줄 (공지·회의록 공용)
///
/// 이미 달린 이모지가 알약으로 늘어서고, 맨 뒤 `+` 로 새 이모지를 고른다.
/// 내가 누른 알약은 파랗게 두어 다시 누르면 취소되는 걸 알린다.
///
/// 서버가 토글 뒤 **최신 집계 전체**를 주므로 화면 쪽 목록을 통째로 갈아끼운다.
/// 갈아끼우는 건 [onToggled] 로 넘겨서 화면이 자기 모델에 반영한다.
class ReactionRow extends StatefulWidget {
  ReactionRow({
    super.key,
    required this.target,
    required this.targetId,
    required this.reactions,
    required this.onToggled,
  });

  final ReactionTarget target;

  /// 서버 uuid — **null 이면 아직 안 올린 글**이라 눌러도 아무 일 없다
  final String? targetId;

  final List<ReactionAgg> reactions;

  /// 토글 뒤 새 집계
  final ValueChanged<List<ReactionAgg>> onToggled;

  @override
  State<ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<ReactionRow> {
  /// 응답을 기다리는 이모지 — 연타로 요청이 엇갈리는 걸 막는다
  final _pending = <String>{};

  Future<void> _toggle(String emoji) async {
    final id = widget.targetId;
    if (id == null || _pending.contains(emoji)) return;

    setState(() => _pending.add(emoji));
    try {
      final reactions = await ReactionApi.toggle(
        target: widget.target,
        targetId: id,
        emoji: emoji,
      );
      if (mounted) widget.onToggled(reactions);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _pending.remove(emoji));
  }

  Future<void> _pick() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPicker(),
    );
    if (emoji != null) await _toggle(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final myId = currentUser?.id;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final reaction in widget.reactions)
          if (reaction.count > 0)
            _ReactionChip(
              emoji: reaction.emoji,
              count: reaction.count,
              mine: reaction.minePressed(myId),
              onTap: () => _toggle(reaction.emoji),
            ),
        // 아직 아무도 안 눌렀으면 이 버튼만 남는다
        Pressable(
          onTap: _pick,
          scale: 0.94,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Icon(
              Icons.add_reaction_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 이모지 하나 + 누른 사람 수
class _ReactionChip extends StatelessWidget {
  _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final int count;

  /// 내가 누른 것 — 파란 테두리로 표시하고 다시 누르면 취소된다
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: mine ? AppColors.primary : AppColors.gray100,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 14, height: 1.2)),
            SizedBox(width: 5),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이모지 고르기 — 아래에서 올라오는 작은 시트
class _EmojiPicker extends StatelessWidget {
  _EmojiPicker();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final emoji in reactionEmojis)
              Pressable(
                onTap: () => Navigator.pop(context, emoji),
                scale: 0.85,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: 26, height: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
