part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 순위표
// ---------------------------------------------------------------------------

/// 순위표 — 내 줄은 파란 면으로 눈에 띄게 둔다
///
/// **폰은 1위부터, PC 는 4위부터다** (2026-08-28). PC 는 위 셋이 시상대에
/// 서 있어서 여기서 빠지고, 폰은 시상대가 없어서 전원이 여기 선다.
class _RankList extends StatelessWidget {
  _RankList({
    required this.entries,
    required this.metric,
    required this.startsAt,
    this.onPick,
    this.picked,
  });

  final List<_Entry> entries;
  final _Metric metric;

  /// 목록이 몇 위부터 시작하는지 (머리말에 쓴다)
  final int startsAt;

  /// 줄을 누르면 점수 내역을 연다 — **종합 탭에서만 들어온다**
  final void Function(_Ranker ranker)? onPick;

  /// 지금 내역이 열려 있는 사람 (그 줄을 눌린 상태로 둔다)
  final String? picked;

  /// 색 면이 깔리는 줄인가 — 내 줄이거나 지금 내역을 연 줄
  bool _filled(_Entry entry) => entry.ranker.isMe || picked == entry.ranker.id;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return SizedBox.shrink();

    return Container(
      // **좌우 여백을 카드가 아니라 줄이 갖는다.** 카드가 갖고 있으면 색 면이
      // 깔린 줄 둘레에 흰 띠가 남아서 잘못 칠한 것처럼 보였다 (2026-08-28 지적).
      // 줄이 끝에서 끝까지 차고, 모서리는 카드가 깎아 준다.
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 0),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 폰은 1위부터라 `1위부터` 라고 적을 것이 없다 — 머리말을 뺀다
          if (isDesktop) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text('$startsAt위부터', style: AppTextStyles.label),
            ),
            SizedBox(height: 6),
          ],
          for (var i = 0; i < entries.length; i++) ...[
            // 색 면이 깔린 줄 **위아래로는 선을 안 긋는다** — 면과 면 사이
            // 띄운 자리에 선이 떠 있으면 잘못 그은 것처럼 보인다
            if (!isDesktop &&
                i > 0 &&
                !_filled(entries[i]) &&
                !_filled(entries[i - 1]))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Container(height: 1, color: AppColors.divider),
              ),
            _RankRow(
              entry: entries[i],
              metric: metric,
              onPick: onPick,
              picked: picked == entries[i].ranker.id,
            ),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  _RankRow({
    required this.entry,
    required this.metric,
    this.onPick,
    this.picked = false,
  });

  final _Entry entry;
  final _Metric metric;

  /// 있으면 줄이 눌린다 (종합 탭)
  final void Function(_Ranker ranker)? onPick;

  /// 지금 이 사람의 점수 내역이 열려 있는가
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final mine = entry.ranker.isMe;
    final row = _row(mine);
    // 누를 수 없는 탭에서는 예전 그대로 — 누름 효과도 안 생긴다
    if (onPick == null) return row;
    return Pressable(onTap: () => onPick!(entry.ranker), child: row);
  }

  Widget _row(bool mine) {
    return Container(
      height: 56,
      // **모서리도 여백도 없다.** 색 면이 카드 안쪽 끝까지 차야 둘레에 흰 띠가
      // 안 남는다 — 모서리는 카드(`clipBehavior`)가 깎아 준다.
      padding: EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        // 내역을 연 줄은 회색 면으로 어디를 눌렀는지 남긴다
        // (내 줄의 파란 면이 우선이다 — 내 자리를 잃으면 안 된다)
        color: mine
            ? AppColors.primaryLight
            : picked
            ? AppColors.gray50
            : Colors.transparent,
      ),
      child: Row(
        children: [
          _RankMark(rank: entry.rank, mine: mine),
          SizedBox(width: 4),
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

/// 등수 표시 — **1~3위만 메달이다**
///
/// 폰에서 시상대를 걷어내면서(2026-08-28) 금·은·동이 갈 자리가 여기밖에
/// 없다. 줄 모양은 4위 아래와 **똑같이** 두고 숫자만 다르게 한다 — 위 셋을
/// 다른 물건으로 만들면 목록이 한 줄로 안 훑힌다.
///
/// **4위 아래도 같은 22 칸을 쓴다.** 예전에는 글자를 그대로 뒀는데, 메달은
/// 칸 가운데에 숫자가 있고 글자는 왼쪽에서 시작해서 **1~3위와 4위 아래가
/// 서로 어긋나 보였다** (2026-08-28 지적).
class _RankMark extends StatelessWidget {
  _RankMark({required this.rank, required this.mine});

  final int rank;

  /// 내 줄인가 — 4위 아래는 파란 글자로 자기 자리를 알아본다
  final bool mine;

  /// 메달 지름 — **숫자만 있는 줄도 같은 칸**이라 자리가 안 어긋난다
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      // 예전에는 글자를 그대로 뒀는데, 메달은 22 칸 **가운데**에 숫자가 있고
      // 이쪽은 글자가 **왼쪽에서** 시작해서 4위 아래가 왼쪽으로 밀려 보였다
      return SizedBox(
        width: _size,
        child: Center(
          child: Text(
            '$rank',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: mine ? AppColors.primary : AppColors.gray500,
            ),
          ),
        ),
      );
    }

    final (light, dark) = _medal(rank);
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ),
        // 메달만 그림자를 진다 — 흰 면 위에서 동그라미가 떠 보인다
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
