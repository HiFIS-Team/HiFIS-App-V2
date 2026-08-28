part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 시상대
// ---------------------------------------------------------------------------

/// TOP 3 시상대 — 가운데가 1위, 받침대 높이로 등수를 보여준다
///
/// **PC 전용이다** (2026-08-28). 폰에서는 시상대를 안 세우고 1위부터 같은
/// 줄에 세운다 — 왕관·받침대가 화면 위쪽을 통째로 먹는 데다 1~3위와 4위
/// 아래가 다른 물건으로 보여서 한 줄로 훑히지가 않았다. 금·은·동은
/// 순위표의 등수 숫자([_RankMark])가 이어받는다.
class _Podium extends StatelessWidget {
  _Podium({required this.top, required this.metric, this.onPick});

  final List<_Entry> top;
  final _Metric metric;

  /// 시상대를 누르면 점수 내역을 연다 — **종합 탭에서만 들어온다**
  ///
  /// 1~3위는 순위표(4위부터)에 없어서, 여기가 없으면 상위 세 명의 내역을
  /// 볼 길이 아예 없다.
  final void Function(_Ranker ranker)? onPick;

  /// 2위 · 1위 · 3위 순서로 세워야 1위가 가운데에 온다
  List<_Entry?> get _order => [
    top.length > 1 ? top[1] : null,
    top.isNotEmpty ? top[0] : null,
    top.length > 2 ? top[2] : null,
  ];

  @override
  Widget build(BuildContext context) {
    final steps = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in _order)
          Expanded(
            child: entry == null
                ? SizedBox()
                : onPick == null
                // 누를 수 없는 탭에서는 예전 그대로 — 누름 효과도 안 생긴다
                ? _Step(entry: entry, metric: metric)
                : Pressable(
                    onTap: () => onPick!(entry.ranker),
                    child: _Step(entry: entry, metric: metric),
                  ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${metric.label} TOP 3', style: AppTextStyles.label),
          SizedBox(height: 16),
          steps,
        ],
      ),
    );
  }
}

/// 시상대 한 칸 — 아바타 · 이름 · 값 · 등수 받침대
class _Step extends StatelessWidget {
  _Step({required this.entry, required this.metric});

  final _Entry entry;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    // 등수가 높을수록 받침대가 높다
    final height = switch (entry.rank) {
      1 => 74.0,
      2 => 56.0,
      _ => 44.0,
    };
    final (light, dark) = _medal(entry.rank);

    return Column(
      children: [
        // 1위만 메달 색 링을 두른다
        Container(
          padding: EdgeInsets.all(first ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: first ? Border.all(color: dark, width: 2.5) : null,
          ),
          child: Avatar(name: entry.ranker.name, size: first ? 52 : 42),
        ),
        SizedBox(height: 8),
        Text(
          entry.ranker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(
            fontWeight: first ? FontWeight.w700 : FontWeight.w600,
            fontSize: first ? 15 : 14,
          ),
        ),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _format(metric, entry.value),
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            // 금·은·동 — 셋 다 색이 있어야 3위도 배경에서 떨어져 보인다
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [light, dark],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: first ? 22 : 18,
              fontWeight: FontWeight.w800,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
