part of 'contribution_section.dart';

// ---------------------------------------------------------------------------
// 내역
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  _HistoryCard({
    required this.items,
    required this.total,
    required this.onOpenAll,
    this.onRevert,
  });

  final List<_Contribution> items;
  final int total;
  final VoidCallback onOpenAll;

  /// 깎인 줄을 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final void Function(_Contribution item)? onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('기여 내역', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$total',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '이번 달 기여 기록이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _ContributionRow(
                item: items[i],
                onRevert: onRevert == null ? null : () => onRevert!(items[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 폰 목록 카드 — 다른 업무 목록과 같은 결로 기여 하나에 카드 하나
///
/// 데스크톱은 아직 [_ContributionRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _ContributionCard extends StatelessWidget {
  _ContributionCard({required this.item, this.onRevert});

  final _Contribution item;

  /// 깎인 점수를 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      // 부여 항목은 상대가 근거다 — 조사로 준 것·받은 것을 가른다
                      item.personLabel == null
                          ? _dayLabel(item.date)
                          : '${item.personLabel} · ${_dayLabel(item.date)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item.pointsLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.isPenalty && onRevert != null) ...[
                SizedBox(width: 2),
                _RevertButton(onTap: onRevert!),
              ],
            ],
          ),
          SizedBox(height: 14),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 한 줄 — 항목 아이콘, 내용, 준 사람, 점수
/// 깎인 줄 오른쪽 되돌리기 아이콘 — **대표에게만, 깎인 줄에만** (2026-08-28)
///
/// 줄 모양은 그대로 두고 아이콘만 뒤에 붙는다. 깎인 줄을 따로 생기게 만들면
/// 목록이 두 종류로 갈려서 훑기가 어려워진다.
class _RevertButton extends StatelessWidget {
  _RevertButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    padding: EdgeInsets.all(6),
    child: Icon(
      CupertinoIcons.arrow_counterclockwise,
      size: 15,
      color: AppColors.textTertiary,
    ),
  );
}

class _ContributionRow extends StatelessWidget {
  _ContributionRow({required this.item, this.onRevert});

  final _Contribution item;

  /// 깎인 점수를 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 15, color: item.color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  // 부여 항목은 상대가 근거다 — 조사로 준 것·받은 것을 가른다
                  item.personLabel == null
                      ? '${item.label} · ${_dayLabel(item.date)}'
                      : '${item.label} · ${item.personLabel} · '
                            '${_dayLabel(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            item.pointsLabel,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              // 깎인 줄은 빨강 — 카드(`_ContributionCard`)와 같은 규칙이다
              color: item.isPenalty ? AppColors.error : AppColors.primary,
            ),
          ),
          if (item.isPenalty && onRevert != null) ...[
            SizedBox(width: 2),
            _RevertButton(onTap: onRevert!),
          ],
        ],
      ),
    );
  }
}

/// 기여 내역 전체 화면 — 이번 달 내 기록
class _ContributionHistoryScreen extends StatefulWidget {
  _ContributionHistoryScreen({required this.items, this.onRevert});

  final List<_Contribution> items;

  /// 깎인 줄을 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final void Function(_Contribution item)? onRevert;

  @override
  State<_ContributionHistoryScreen> createState() =>
      _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState
    extends State<_ContributionHistoryScreen> {
  /// **넘겨받은 목록을 여기서 들고 있는다.** 되돌리면 이 화면에서도 줄이
  /// 바로 빠져야 하는데, 뒤에 있는 탭이 다시 받아 오는 것을 여기서는 못 본다
  /// (전체 화면으로 덮여 있어서 그 화면은 새로 안 그려진다).
  late List<_Contribution> _items = widget.items;

  void _revert(_Contribution item) {
    widget.onRevert?.call(item);
    setState(() {
      _items = [
        for (final row in _items)
          if (row.eventId == null || row.eventId != item.eventId) row,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = _items;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 68, 24, 32),
              children: [
                if (mine.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                    child: Text(
                      '이번 달 기여 기록이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider),
                    _ContributionRow(
                      item: mine[i],
                      onRevert: widget.onRevert == null
                          ? null
                          : () => _revert(mine[i]),
                    ),
                  ],
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 내역', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
