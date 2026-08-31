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
    // 프로젝트·결재함 목록바와 **같은 것**을 쓴다 (2026-08-21) — 예전에는
    // 셋이 같은 모양을 각자 그려서 고칠 때 한 곳씩 빠졌다
    return SegmentedTabs(
      labels: [for (final filter in _Filter.values) filter.label],
      selected: _Filter.values.indexOf(selected),
      onSelect: (i) => onSelect(_Filter.values[i]),
      height: 44,
      dense: true,
    );
  }
}

/// 폰 목록 카드 — 프로젝트 카드와 같은 결로 사람 하나에 카드 하나
///
/// 아바타·이름·상태 배지 / 직군 / 별점 요약. 아직 안 한 사람은 빈 별이라
/// **무엇이 남았는지가 한눈에 보인다.**
///
/// 데스크톱은 [_PersonTile] — 조직도 카드와 같은 틀이다.
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

  /// null 이면 **안 눌린다** — 평가 창이 닫혔고 아직 안 낸 사람이다.
  /// 공용 [PersonCard] 와 같은 규칙이라 손가락 커서도 안 뜬다.
  final VoidCallback? onTap;

  /// 준 별점의 평균 (5개 항목)
  double get _average {
    final stars = review!.stars.values;
    return stars.isEmpty ? 0 : stars.reduce((a, b) => a + b) / stars.length;
  }

  @override
  Widget build(BuildContext context) {
    final done = review != null;
    final color = done ? AppColors.success : AppColors.primary;

    final card = Container(
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
    );
    // 공용 [PersonCard] 와 같은 규칙 — onTap 이 null 이면 안 감싼다
    return onTap == null ? card : Pressable(onTap: onTap!, child: card);
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

/// 평가 대상 한 칸 (PC) — 조직도 카드와 같은 틀
///
/// **보여주는 값은 [_PersonRow] 와 같다** — 아바타(끝낸 사람은 흐리게) ·
/// 이름 · `나` 배지 · 직군/완료 문구 · 끝의 체크. 틀만 조직도 카드로 바꿨다.
class _PersonTile extends StatelessWidget {
  _PersonTile({
    required this.person,
    required this.isSelf,
    required this.onTap,
    this.done = false,
  });

  final Employee person;
  final bool isSelf;

  /// null 이면 **안 눌린다** — 평가 창이 닫혔고 아직 안 낸 사람이다.
  /// 공용 [PersonCard] 와 같은 규칙이라 손가락 커서도 안 뜬다.
  final VoidCallback? onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return PersonCard(
      name: person.name,
      color: person.color ?? avatarColorFor(person.name),
      avatarUrl: person.avatarUrl,
      dimmed: done,
      onTap: onTap,
      tag: isSelf ? _MeTag() : null,
      subtitle: done
          ? '평가 완료'
          : isSelf
          ? '본인 평가'
          : person.rank.label,
      subtitleColor: done
          ? AppColors.success
          : isSelf
          ? AppColors.primary
          : AppColors.textTertiary,
      subtitleWeight: done ? FontWeight.w600 : FontWeight.w400,
      trailing: Icon(
        done
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.chevron_right,
        size: 16,
        color: done ? AppColors.success : AppColors.gray300,
      ),
    );
  }
}

/// 이름 옆 `나` 배지 — 줄과 카드가 같이 쓴다
class _MeTag extends StatelessWidget {
  _MeTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
  );
}
