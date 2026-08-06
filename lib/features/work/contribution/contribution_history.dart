part of 'contribution_section.dart';

// ---------------------------------------------------------------------------
// 내역
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  _HistoryCard({
    required this.items,
    required this.total,
    required this.onOpenAll,
  });

  final List<_Contribution> items;
  final int total;
  final VoidCallback onOpenAll;

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
              _ContributionRow(item: items[i]),
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
  _ContributionCard({required this.item});

  final _Contribution item;

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
                  color: item.kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.kind.icon, size: 18, color: item.kind.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.kind.label,
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
                  color: item.kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '+${item.points}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: item.kind.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
class _ContributionRow extends StatelessWidget {
  _ContributionRow({required this.item});

  final _Contribution item;

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
              color: item.kind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.kind.icon, size: 15, color: item.kind.color),
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
                      ? '${item.kind.label} · ${_dayLabel(item.date)}'
                      : '${item.kind.label} · ${item.personLabel} · '
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
            '+${item.points}',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 내역 전체 화면 — 이번 달 내 기록
class _ContributionHistoryScreen extends StatelessWidget {
  _ContributionHistoryScreen({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final mine = items;

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
                    _ContributionRow(item: mine[i]),
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
