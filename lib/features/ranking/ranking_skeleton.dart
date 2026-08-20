part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 뼈대
// ---------------------------------------------------------------------------

/// 판을 받아오는 동안 자리를 잡아 두는 뼈대 — 시상대 · 내 순위 · 순위표
///
/// 짜임을 [_RankingScreenState._body] 와 맞춘다. 안 맞추면 다 받았을 때
/// 줄이 밀려서 그 자체가 깜빡임이 된다.
///
/// **목록바와 달 이동 줄은 여기에 없다** — 받아올 것이 없는 자리라 그대로 둔다.
class _RankingSkeleton extends StatelessWidget {
  _RankingSkeleton();

  /// 시상대 한 칸 — 아바타 · 이름 · 값 · 받침대
  ///
  /// 크기는 [_Step] 에서 그대로 가져왔다 (폰은 크게, PC 는 카드 안이라 작게).
  Widget _step({
    required double avatar,
    required double pedestal,
    required bool big,
  }) => Column(
    children: [
      // 1위 왕관 자리 — 진짜 시상대도 늘 비워 둬서 세 칸 아래가 안 어긋난다
      if (big) SizedBox(height: 24),
      SkeletonCircle(size: avatar),
      SizedBox(height: big ? 10 : 8),
      Skeleton(width: big ? 50 : 44, height: 13),
      SizedBox(height: 6),
      Skeleton(width: big ? 38 : 34, height: 11),
      SizedBox(height: big ? 12 : 10),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: big ? 3 : 4),
        child: SizedBox(
          width: double.infinity,
          child: Skeleton(height: pedestal, radius: big ? 16 : 12),
        ),
      ),
    ],
  );

  /// 2위 · 1위 · 3위 순서 — 1위가 가운데다
  Widget _podium(bool big) {
    final steps = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _step(
            avatar: big ? 56 : 42,
            pedestal: big ? 78 : 56,
            big: big,
          ),
        ),
        Expanded(
          child: _step(
            avatar: big ? 72 : 52,
            pedestal: big ? 104 : 74,
            big: big,
          ),
        ),
        Expanded(
          child: _step(
            avatar: big ? 56 : 42,
            pedestal: big ? 64 : 44,
            big: big,
          ),
        ),
      ],
    );

    // 폰은 카드 없이 배경 위에 그대로 세운다 ([_Podium] 과 같다)
    if (big) return steps;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 104, height: 13),
          SizedBox(height: 16),
          steps,
        ],
      ),
    );
  }

  /// 내 순위 카드 — 아바타 · 상위 % · 등수, 그 아래 따라잡기 한 줄
  ///
  /// 진짜 카드는 브랜드 테두리를 두르는데 뼈대에서는 회색으로 둔다 —
  /// 아직 내 등수가 아니라 자리만 잡아 둔 것이라 색까지 미리 칠하면 튄다.
  Widget _myRank() => Container(
    padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gray100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SkeletonCircle(size: 52),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 72, height: 11),
                  SizedBox(height: 8),
                  Skeleton(width: 96, height: 20, radius: 8),
                ],
              ),
            ),
            SizedBox(width: 10),
            Skeleton(width: 54, height: 30, radius: 8),
          ],
        ),
        SizedBox(height: 14),
        Skeleton(height: 12),
      ],
    ),
  );

  /// 4위부터의 순위표 — 줄 높이 56 은 [_RankRow] 와 같은 값이다
  Widget _list() => Container(
    padding: EdgeInsets.fromLTRB(12, isDesktop ? 16 : 6, 12, 6),
    decoration: AppDecorations.card(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Skeleton(width: 62, height: 13),
          ),
          SizedBox(height: 6),
        ],
        for (var i = 0; i < 6; i++)
          SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  SizedBox(width: 26, child: Skeleton(width: 12, height: 13)),
                  SkeletonCircle(size: isDesktop ? 32 : 36),
                  SizedBox(width: 12),
                  // 줄마다 이름 길이를 달리해서 진짜 목록처럼 보이게 한다
                  Expanded(
                    child: Skeleton(width: 88.0 + (i % 3) * 22, height: 12),
                  ),
                  SizedBox(width: 10),
                  Skeleton(width: 46, height: 13),
                  SizedBox(width: 8),
                  SizedBox(width: 26, child: Skeleton(width: 22, height: 11)),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PC 는 폭이 남아 내 순위와 시상대를 나란히, 폰은 시상대를 크게
        if (isDesktop)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _myRank()),
                SizedBox(width: 16),
                Expanded(flex: 2, child: _podium(false)),
              ],
            ),
          )
        else ...[
          _podium(true),
          SizedBox(height: 16),
          _myRank(),
        ],
        SizedBox(height: isDesktop ? 16 : 12),
        _list(),
      ],
    ),
  );
}
