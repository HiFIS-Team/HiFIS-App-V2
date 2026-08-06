part of 'peer_review_section.dart';

// ---------------------------------------------------------------------------
// 평가 작성 (직원·점장)
// ---------------------------------------------------------------------------

/// 이번 달 평가 진행 — 몇 명 중 몇 명을 마쳤는지
class _ReviewProgress extends StatelessWidget {
  _ReviewProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final left = total - done;
    final finished = left == 0;
    final color = finished ? AppColors.success : AppColors.primary;

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
                  '${DateTime.now().month}월 동료 평가',
                  style: AppTextStyles.label,
                ),
              ),
              Text('$done', style: AppTextStyles.title2.copyWith(color: color)),
              Text(
                ' / $total명',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: total == 0 ? 0 : done / total, color: color),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                finished
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.pencil_circle_fill,
                size: 14,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  finished ? '이번 달 평가를 모두 마쳤어요' : '$left명 남았어요',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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

/// 폰 목록 필터 — 프로젝트 목록의 단계 탭과 같은 모양
class _FilterTabs extends StatelessWidget {
  _FilterTabs({required this.selected, required this.onSelect});

  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          for (final filter in _Filter.values)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(filter),
                scale: 0.97,
                // 배경은 애니메이션 없이 즉시 바꾼다 (페이드가 있으면 두 칸이
                // 같이 눌린 것처럼 보인다)
                child: Container(
                  decoration: segmentFill(selected: filter == selected),
                  child: Center(
                    child: Text(
                      filter.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: filter == selected
                            ? AppColors.textPrimary
                            : AppColors.gray600,
                        fontWeight: filter == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 폰 목록 카드 — 프로젝트 카드와 같은 결로 사람 하나에 카드 하나
///
/// 아바타·이름·상태 배지 / 직급 / 별점 요약. 아직 안 한 사람은 빈 별이라
/// **무엇이 남았는지가 한눈에 보인다.**
///
/// 데스크톱은 아직 [_PersonRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _PersonCard extends StatelessWidget {
  _PersonCard({
    required this.person,
    required this.isSelf,
    required this.review,
    required this.onTap,
  });

  final Employee person;
  final bool isSelf;

  /// 이미 낸 평가 — 없으면 아직 안 한 사람이다
  final PeerReview? review;

  final VoidCallback onTap;

  /// 준 별점의 평균 (5개 항목)
  double get _average {
    final stars = review!.stars.values;
    return stars.isEmpty ? 0 : stars.reduce((a, b) => a + b) / stars.length;
  }

  @override
  Widget build(BuildContext context) {
    final done = review != null;
    final color = done ? AppColors.success : AppColors.primary;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: person.name, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body1.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            SizedBox(width: 6),
                            _Chip(text: '나', color: AppColors.primary),
                          ],
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        isSelf ? '본인 평가' : person.rank.label,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _StatusBadge(done: done),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                for (var i = 1; i <= peerStarCount; i++) ...[
                  if (i > 1) SizedBox(width: 3),
                  Icon(
                    done && i <= _average.round()
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    size: 15,
                    color: done ? color : AppColors.gray300,
                  ),
                ],
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done ? _average.toStringAsFixed(1) : '아직 평가하지 않았어요',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                      color: done ? color : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 오른쪽 위 상태 — 프로젝트 카드의 D-day 배지 자리
class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => _Chip(
    text: done ? '완료' : '평가하기',
    color: done ? AppColors.success : AppColors.primary,
    filled: false,
  );
}

/// 작은 알약 배지
class _Chip extends StatelessWidget {
  _Chip({required this.text, required this.color, this.filled = true});

  final String text;
  final Color color;

  /// true 면 색을 꽉 채우고 글자를 흰색으로 (이름 옆 '나' 배지)
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: filled ? 6 : 10, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: filled ? 10 : 12,
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 사람 한 줄 — 아바타·이름·소속과 끝의 이동 화살표
///
/// 이미 평가한 사람은 아바타가 한 톤 흐려지고 끝에 체크가 붙는다.
/// (눌러서 그때 쓴 내용을 다시 볼 수는 있다 — 고치지는 못한다)
class _PersonRow extends StatelessWidget {
  _PersonRow({
    required this.person,
    required this.isSelf,
    required this.onTap,
    this.done = false,
  });

  final Employee person;
  final bool isSelf;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = person.color ?? avatarColorFor(person.name);

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? color.withValues(alpha: 0.35) : color,
              shape: BoxShape.circle,
            ),
            child: Text(
              person.name.characters.first,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      person.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isSelf) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '나',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  done
                      ? '평가 완료'
                      : isSelf
                      ? '본인 평가'
                      : person.rank.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    color: done
                        ? AppColors.success
                        : isSelf
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.chevron_right,
            size: 16,
            color: done ? AppColors.success : AppColors.gray300,
          ),
        ],
      ),
    );
  }
}
