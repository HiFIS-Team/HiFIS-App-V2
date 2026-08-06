part of 'contribution_section.dart';

// ---------------------------------------------------------------------------
// 점수 요약
// ---------------------------------------------------------------------------

/// 이번 달 기여 점수 — 총점과 부여/자동 비중
///
/// 대표·관리자는 받는 쪽이 아니라 **주는 쪽**이라 같은 카드를 '내가 준 점수'로
/// 쓴다. 그때는 비중 막대를 안 그린다 — 준 것은 전부 사람이 준 것이라
/// '부여/자동' 이 늘 100 대 0 이 되어 아무 것도 안 알려 준다.
class _ScoreCard extends StatelessWidget {
  _ScoreCard({required this.items, this.given = false});

  final List<_Contribution> items;

  /// 내가 준 점수를 보는 중인가
  final bool given;

  @override
  Widget build(BuildContext context) {
    final total = _sum(items);
    // 사람이 준 점수와 기록에서 자동으로 들어온 점수를 가른다
    final granted = _sum(items.where((c) => !c.automatic).toList());
    final auto = total - granted;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  given
                      ? '${DateTime.now().month}월 내가 준 점수'
                      : '${DateTime.now().month}월 기여 점수',
                  style: AppTextStyles.label,
                ),
              ),
              Text(
                '$total',
                style: AppTextStyles.title1.copyWith(
                  fontSize: 28,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.body2.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          if (!given) ...[
            SizedBox(height: 14),
            // 받은 점수와 자동으로 쌓인 점수의 비중
            ProgressBar(ratio: total == 0 ? 0 : granted / total),
            SizedBox(height: 12),
            Row(
              children: [
                _legend(AppColors.primary, '부여받은 점수', granted),
                SizedBox(width: 16),
                _legend(AppColors.gray300, '자동 집계', auto),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, int points) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 6),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      SizedBox(width: 4),
      Text(
        '$points점',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 항목 네 칸 — 무엇으로 몇 점이 쌓였는지
class _KindGrid extends StatelessWidget {
  _KindGrid({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    // 데스크톱은 한 줄에 넷, 폰은 2×2
    final columns = isDesktop ? 4 : 2;
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in ContribType.values)
              SizedBox(
                width: width,
                child: _KindCard(
                  kind: kind,
                  items: items.where((c) => c.kind == kind).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KindCard extends StatelessWidget {
  _KindCard({required this.kind, required this.items});

  final ContribType kind;
  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final points = _sum(items);
    final empty = items.isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kind.icon, size: 15, color: kind.color),
              ),
              Spacer(),
              // 이 항목이 어떻게 들어오는지 — 부여인지 자동인지
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kind.grantedInApp ? '부여' : '자동',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            kind.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$points',
                style: AppTextStyles.title2.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textPrimary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.caption.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textSecondary,
                ),
              ),
              Spacer(),
              Text(
                empty ? '없음' : '${items.length}건',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 부여 권한이 있는 사람에게만 보이는 줄
class _GrantBanner extends StatelessWidget {
  _GrantBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.plus_circle_fill,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기여 점수 주기',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '창의적 아이디어 · 자발적 목표 업무를 직접 챙겨주세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
