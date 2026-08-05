part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 순위표
// ---------------------------------------------------------------------------

/// 4위부터의 순위표 — 내 줄은 파란 면으로 눈에 띄게 둔다
class _RankList extends StatelessWidget {
  _RankList({
    required this.entries,
    required this.metric,
    required this.startsAt,
  });

  final List<_Entry> entries;
  final _Metric metric;

  /// 목록이 몇 위부터 시작하는지 (머리말에 쓴다)
  final int startsAt;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(12, isDesktop ? 16 : 6, 12, 6),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 폰은 시상대 바로 아래라 이어지는 흐름이 보여서 머리말을 뺀다
          if (isDesktop) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('$startsAt위부터', style: AppTextStyles.label),
            ),
            SizedBox(height: 6),
          ],
          for (var i = 0; i < entries.length; i++) ...[
            if (!isDesktop && i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Container(height: 1, color: AppColors.divider),
              ),
            _RankRow(entry: entries[i], metric: metric),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  _RankRow({required this.entry, required this.metric});

  final _Entry entry;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final mine = entry.ranker.isMe;

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.primary : AppColors.gray500,
              ),
            ),
          ),
          Avatar(name: entry.ranker.name, size: isDesktop ? 32 : 36),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.ranker.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 폰은 폭이 좁아 이름과 점수만 남긴다
                if (isDesktop) ...[
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.ranker.team,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _format(metric, entry.value),
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: mine ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isDesktop) ...[
                SizedBox(height: 1),
                Text(
                  entry.note,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Align(
              alignment: Alignment.centerRight,
              child: _DeltaBadge(entry: entry, metric: metric, compact: true),
            ),
          ),
        ],
      ),
    );
  }
}
