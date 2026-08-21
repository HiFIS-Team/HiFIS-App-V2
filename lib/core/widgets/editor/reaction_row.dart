import 'package:flutter/material.dart';

import '../../api/notice/reaction_api.dart';
import '../../data/current_user.dart';
import '../../data/staff_directory.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../display/avatar.dart';
import '../input/pressable.dart';

/// 반응한 사람 시트 (공지·회의록 공용)
///
/// **알약 줄은 걷어냈다 (2026-08-19).** 반응이 하트 하나로 고정되면서 글
/// 오른쪽 세로 줄([PostActions])이 그 자리를 대신한다 — 여기 남은 것은
/// 「누가 눌렀나」 시트뿐이고, 그건 그대로 쓴다.

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
            // 이모지 칸 — 밑줄로 지금 보고 있는 것을 알린다.
            // **폭을 꽉 채워야 왼쪽부터 선다** — 안 그러면 스크롤뷰가 내용
            // 만큼만 넓어져서 Column 이 가운데로 밀어 놓는다 (실제로 그랬다)
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
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
