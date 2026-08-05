part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 내 순위
// ---------------------------------------------------------------------------

/// 맨 위 내 순위 카드 — 등수 · 지난달 대비 · 이번 달 값
class _MyRankCard extends StatelessWidget {
  _MyRankCard({
    required this.entry,
    required this.above,
    required this.below,
    required this.metric,
    required this.total,
  });

  final _Entry entry;

  /// 바로 위·아래 사람 (없으면 null)
  final _Entry? above;
  final _Entry? below;

  final _Metric metric;

  /// 이 지점에서 순위에 오른 사람 수 (상위 몇 %인지 계산에 쓴다)
  final int total;

  Widget get _chase =>
      _ChaseLine(entry: entry, above: above, below: below, metric: metric);

  /// 폰 — 아바타·상위 %를 왼쪽에, 등수를 오른쪽에 크게 놓고
  /// 그 아래 한 줄로 다음 순위까지 얼마 남았는지 붙인다
  Widget _phone(int percent) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // 내 순위만 브랜드 테두리로 목록과 구분한다
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: Avatar(name: entry.ranker.name, size: 46),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '내 순위',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                        SizedBox(width: 6),
                        _DeltaBadge(entry: entry, metric: metric),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('상위 $percent%', style: AppTextStyles.title2),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '위',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          SizedBox(height: 12),
          _chase,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (entry.rank * 100 / total).round();

    if (!isDesktop) return _phone(percent);

    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      // 옆 시상대에 높이를 맞추면 남는 자리가 생긴다. Spacer(flex)를 쓰면
      // IntrinsicHeight가 높이를 재는 동안 터지므로, 위·아래 두 덩어리로
      // 나누고 빈자리를 사이에 몰아준다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '내 ${metric.label}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 6),
                  _DeltaBadge(entry: entry, metric: metric),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '위',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '/ $total명',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 14),
              Container(height: 1, color: AppColors.divider),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _format(metric, entry.value),
                          style: AppTextStyles.title3,
                        ),
                        SizedBox(height: 2),
                        Text(entry.note, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '상위 $percent%',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _chase,
            ],
          ),
        ],
      ),
    );
  }
}

/// 다음 순위까지 얼마나 남았는지 — 카드 맨 아래 한 줄
///
/// 순위만 보여주면 뭘 해야 할지 모른다. 바로 위 사람과의 차이를
/// 그 항목의 단위(만원·회·건…)로 바꿔서 "얼마 더"를 알려 준다.
/// 이미 1위면 쫓아오는 사람과의 여유를 대신 보여준다.
class _ChaseLine extends StatelessWidget {
  _ChaseLine({
    required this.entry,
    required this.above,
    required this.below,
    required this.metric,
  });

  final _Entry entry;
  final _Entry? above;
  final _Entry? below;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final chasing = above != null;
    final target = above ?? below;

    // 혼자면 비교할 상대가 없다
    if (target == null) return SizedBox.shrink();

    final gap = chasing
        ? target.value - entry.value
        : entry.value - target.value;
    final color = chasing ? AppColors.primary : AppColors.success;

    final text = gap <= 0
        ? '${target.ranker.name}님과 동점이에요'
        : chasing
        ? '${target.rank}위 ${target.ranker.name}까지 '
              '${_gapLabel(metric, gap)} 남았어요'
        : '${target.rank}위와 ${_gapLabel(metric, gap)} 차이로 앞서요';

    final line = Row(
      children: [
        Icon(
          chasing
              ? CupertinoIcons.arrow_up_right
              : CupertinoIcons.checkmark_seal_fill,
          size: 13,
          color: color,
        ),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );

    // 폰은 이미 카드 안 구분선 아래라서 면을 한 겹 더 깔면 답답하다
    if (!isDesktop) return line;

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: line,
    );
  }
}

/// 지난달 대비 순위 변동 — 올라갔으면 초록 위 화살표
class _DeltaBadge extends StatelessWidget {
  _DeltaBadge({
    required this.entry,
    required this.metric,
    this.compact = false,
  });

  final _Entry entry;
  final _Metric metric;

  /// 순위표 줄에서 쓸 때는 배경 없이 화살표만
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final last = entry.ranker.lastRankOf(metric);

    // 지난달에 없던 사람은 비교할 게 없다
    if (last == 0) {
      return compact ? SizedBox.shrink() : _box('NEW', AppColors.primary, null);
    }

    final delta = last - entry.rank;
    if (delta == 0) {
      return compact
          ? Icon(Icons.remove_rounded, size: 12, color: AppColors.gray300)
          : _box('-', AppColors.gray400, null);
    }

    final up = delta > 0;
    final color = up ? AppColors.success : AppColors.error;
    final icon = up
        ? CupertinoIcons.arrow_up_right
        : CupertinoIcons.arrow_down_right;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 1),
          Text(
            '${delta.abs()}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
    }
    return _box('${delta.abs()}', color, icon);
  }

  Widget _box(String text, Color color, IconData? icon) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          SizedBox(width: 2),
        ],
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}
