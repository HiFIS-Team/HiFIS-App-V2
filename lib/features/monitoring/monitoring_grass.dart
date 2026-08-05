part of 'monitoring_screen.dart';

// ---------------------------------------------------------------------------
// 잔디 — 최근 2주 × 24시간
// ---------------------------------------------------------------------------

/// 언제 붐볐는지를 한 판으로
///
/// GitHub 잔디는 가로가 '주'인데 여기는 **가로를 시간**으로 둔다.
/// 접속은 하루 안에서 시간대가 몰리는 값이라 그쪽이 훨씬 많이 보인다
/// (12주짜리로 그려 봤더니 기록이 며칠뿐이라 판이 거의 비어 있었다).
class _Grass extends StatelessWidget {
  _Grass({required this.grid});

  /// `[날짜][시간]` — 0번이 오늘
  final List<List<int>> grid;

  /// 제일 붐빈 칸 (농도의 기준)
  int get _top {
    var top = 0;
    for (final day in grid) {
      for (final count in day) {
        if (count > top) top = count;
      }
    }
    return top;
  }

  /// 건수를 네 단계 농도로 — 0은 빈 칸
  Color _shade(int count) {
    if (count == 0) return AppColors.gray50;
    final ratio = _top == 0 ? 0.0 : count / _top;
    final step = ratio > 0.66
        ? 1.0
        : ratio > 0.33
        ? 0.7
        : ratio > 0.12
        ? 0.45
        : 0.25;
    return AppColors.primary.withValues(alpha: step);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '최근 2주 접속',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ),
              SizedBox(width: 12),
              Spacer(),
              Text('적음', style: AppTextStyles.caption.copyWith(fontSize: 11)),
              SizedBox(width: 6),
              for (final step in const [0.0, 0.25, 0.45, 0.7, 1.0])
                Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: step == 0
                        ? AppColors.gray50
                        : AppColors.primary.withValues(alpha: step),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              SizedBox(width: 3),
              Text('많음', style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          SizedBox(height: 14),
          for (var d = 0; d < grid.length; d++) ...[
            if (d > 0) SizedBox(height: 3),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    _dayLabel(now, d),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: d == 0 ? FontWeight.w700 : FontWeight.w400,
                      color: d == 0
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1.5),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _shade(grid[d][h]),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 40),
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Center(
                    // 24칸에 숫자를 다 쓰면 뭉개진다 — 여섯 시간마다만
                    child: Text(
                      h % 6 == 0 ? '$h' : '',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 잔디 왼쪽 날짜 — 오늘은 '오늘', 나머지는 '8.2'
String _dayLabel(DateTime now, int daysAgo) {
  if (daysAgo == 0) return '오늘';
  final at = DateTime(now.year, now.month, now.day - daysAgo);
  return '${at.month}.${at.day}';
}
