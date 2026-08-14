import 'package:flutter/material.dart';

import '../../api/client/api_exception.dart';
import '../../api/notice/reaction_api.dart';
import '../../data/current_user.dart';
import '../../data/staff_directory.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../display/avatar.dart';
import '../feedback/app_toast.dart';
import '../input/pressable.dart';

/// 고를 수 있는 이모지 — 사내톡 말풍선 반응과 같은 목록
const reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

/// 본문 아래 이모지 반응 줄 (공지·회의록 공용)
///
/// 이미 달린 이모지가 알약으로 늘어서고, 맨 뒤 `+` 로 새 이모지를 고른다.
/// 내가 누른 알약은 파랗게 두어 다시 누르면 취소되는 걸 알린다.
///
/// **꾹 누르면 누가 눌렀는지 시트로 보여준다** (카톡과 같다).
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
    final live = [
      for (final reaction in widget.reactions)
        if (reaction.count > 0) reaction,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final reaction in live)
          _ReactionChip(
            emoji: reaction.emoji,
            count: reaction.count,
            mine: reaction.minePressed(myId),
            onTap: () => _toggle(reaction.emoji),
            // 꾹 누르면 누가 눌렀는지 — 누른 그 이모지 칸이 먼저 열린다
            onLongPress: () =>
                showReactionPeople(context, live, emoji: reaction.emoji),
          ),
        // 아직 아무도 안 눌렀으면 이 버튼만 남는다.
        // **테두리를 안 두른다** — 알약들 사이에서 덜 튀어야 한다
        Pressable(
          onTap: _pick,
          scale: 0.94,
          borderRadius: BorderRadius.circular(100),
          // `alignment` 를 주면 Container 가 부모가 주는 최대 폭까지 늘어나
          // 버튼 하나가 한 줄을 다 먹는다 (Wrap 을 쓴 뜻이 없어진다)
          child: Container(
            height: 28,
            padding: EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              Icons.add_reaction_outlined,
              size: 15,
              color: AppColors.gray400,
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
    required this.onLongPress,
  });

  final String emoji;
  final int count;

  /// 내가 누른 것 — 파란 테두리로 표시하고 다시 누르면 취소된다
  final bool mine;
  final VoidCallback onTap;

  /// 꾹 누르기 — 누가 눌렀는지 시트로 연다
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.94,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          // 내가 누른 것만 테두리로 알린다 (나머지는 바탕색만)
          border: mine ? Border.all(color: AppColors.primary) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 13, height: 1.2)),
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

// ── 누가 눌렀나 ──

/// 반응한 사람 시트 열기 — 알약을 꾹 눌렀을 때
///
/// 사내톡 말풍선도 같은 걸 쓸 수 있게 밖으로 열어 둔다.
void showReactionPeople(
  BuildContext context,
  List<ReactionAgg> reactions, {
  required String emoji,
}) {
  if (reactions.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ReactionPeopleSheet(reactions: reactions, first: emoji),
  );
}

/// 이모지별로 누른 사람 — 위 칸을 눌러 이모지를 옮긴다
class _ReactionPeopleSheet extends StatefulWidget {
  _ReactionPeopleSheet({required this.reactions, required this.first});

  final List<ReactionAgg> reactions;

  /// 처음 열릴 때 서 있을 이모지 (꾹 누른 그것)
  final String first;

  @override
  State<_ReactionPeopleSheet> createState() => _ReactionPeopleSheetState();
}

class _ReactionPeopleSheetState extends State<_ReactionPeopleSheet> {
  late String _emoji = widget.reactions.any((r) => r.emoji == widget.first)
      ? widget.first
      : widget.reactions.first.emoji;

  ReactionAgg get _current =>
      widget.reactions.firstWhere((r) => r.emoji == _emoji);

  @override
  Widget build(BuildContext context) {
    final ids = _current.employeeIds;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            SizedBox(height: 14),
            Text(
              '반응',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            // 이모지 칸 — 밑줄로 지금 보고 있는 것을 알린다
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final reaction in widget.reactions)
                    _EmojiTab(
                      emoji: reaction.emoji,
                      count: reaction.count,
                      selected: reaction.emoji == _emoji,
                      onTap: () => setState(() => _emoji = reaction.emoji),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.gray100),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  MediaQuery.paddingOf(context).bottom + 20,
                ),
                children: [
                  Text(
                    '${ids.length}명',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  for (final id in ids) _PersonRow(employeeId: id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시트 위 이모지 칸 하나
class _EmojiTab extends StatelessWidget {
  _EmojiTab({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.94,
    child: Container(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
      margin: EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected ? AppColors.textPrimary : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 18, height: 1.2)),
          SizedBox(width: 5),
          Text(
            '$count',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 누른 사람 한 줄 — 아바타 + 이름 (나는 `나` 배지가 붙는다)
class _PersonRow extends StatelessWidget {
  _PersonRow({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    // 명단을 아직 못 받았으면 이름을 못 붙인다 — 그때만 `알 수 없음`
    final name = StaffDirectory.instance.byId(employeeId)?.name ?? '알 수 없음';
    final mine = employeeId == currentUser?.id;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Avatar(name: name, size: 40),
          SizedBox(width: 12),
          if (mine) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '나',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
