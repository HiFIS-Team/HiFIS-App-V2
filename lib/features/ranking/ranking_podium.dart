part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 시상대
// ---------------------------------------------------------------------------

/// TOP 3 시상대 — 가운데가 1위, 받침대 높이로 등수를 보여준다
class _Podium extends StatelessWidget {
  _Podium({required this.top, required this.metric, this.big = false});

  final List<_Entry> top;
  final _Metric metric;

  /// 폰은 이 화면의 주인공이라 카드 없이 크게 세운다
  final bool big;

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
                : _Step(entry: entry, metric: metric, big: big),
          ),
      ],
    );

    // 폰은 배경 위에 그대로 세운다 — 카드 테두리를 두르면 시상대가 작아 보인다
    if (big) return steps;

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

/// 시상대 한 칸 — 왕관 · 아바타 · 이름 · 값 · 등수 받침대
class _Step extends StatelessWidget {
  _Step({required this.entry, required this.metric, this.big = false});

  final _Entry entry;
  final _Metric metric;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    // 등수가 높을수록 받침대가 높다
    final height = switch ((entry.rank, big)) {
      (1, true) => 104.0,
      (2, true) => 78.0,
      (_, true) => 64.0,
      (1, _) => 74.0,
      (2, _) => 56.0,
      _ => 44.0,
    };
    final avatar = big ? (first ? 72.0 : 56.0) : (first ? 52.0 : 42.0);
    final (light, dark) = _medal(entry.rank);

    return Column(
      children: [
        // 1위 머리 위 왕관 — 자리를 늘 잡아둬서 세 칸의 아래가 어긋나지 않는다
        if (big)
          SizedBox(
            height: 24,
            child: first
                ? Text('👑', style: TextStyle(fontSize: 20, height: 1.1))
                : null,
          ),
        // 1위만 메달 색 링을 두른다
        Container(
          padding: EdgeInsets.all(first ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: first ? Border.all(color: dark, width: 2.5) : null,
          ),
          child: Avatar(name: entry.ranker.name, size: avatar),
        ),
        SizedBox(height: big ? 10 : 8),
        Text(
          entry.ranker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(
            fontWeight: first ? FontWeight.w700 : FontWeight.w600,
            fontSize: big ? (first ? 16 : 15) : (first ? 15 : 14),
          ),
        ),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _format(metric, entry.value),
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(
              fontSize: big ? 13 : 12,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
        ),
        SizedBox(height: big ? 12 : 10),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: big ? 3 : 4),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: big ? 14 : 10),
          decoration: BoxDecoration(
            // 금·은·동 — 셋 다 색이 있어야 3위도 배경에서 떨어져 보인다
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [light, dark],
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(big ? 16 : 12),
            ),
          ),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: big ? (first ? 34 : 28) : (first ? 22 : 18),
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
