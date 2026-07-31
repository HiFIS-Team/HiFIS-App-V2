part of 'ranking_screen.dart';

/// 랭킹 항목
///
/// 종합은 나머지 네 항목을 100점으로 환산해 평균 낸 값이라
/// 항상 맨 뒤에 둔다.
enum _Metric {
  revenue('매출', '매출'),
  kindness('친절 점수', '친절'),
  project('프로젝트 달성', '프로젝트'),
  care('환경정비', '환경정비'),
  overall('종합', '종합');

  const _Metric(this.label, this.short);

  final String label;

  /// 폰 탭처럼 칸이 좁을 때 쓰는 짧은 이름
  final String short;
}

/// 랭킹에 오르는 사람 한 명 (목업)
///
/// 이름과 아바타 색은 공용 명단([staffList])을 따르고,
/// 이번 달 실적만 여기에 담는다.
class _Ranker {
  const _Ranker({
    required this.name,
    required this.team,
    required this.branch,
    required this.revenue,
    required this.newSignups,
    required this.reSignups,
    required this.kindness,
    required this.reviews,
    required this.stars,
    required this.projectDone,
    required this.projectTotal,
    required this.care,
    required this.lastRank,
  });

  final String name;
  final String team;
  final String branch;

  /// 이번 달 매출 (원)
  final int revenue;
  final int newSignups;
  final int reSignups;

  /// 회원 리뷰로 환산한 친절 점수 (100점 만점)
  final int kindness;
  final int reviews;
  final double stars;

  /// 맡은 프로젝트 중 끝낸 개수
  final int projectDone;
  final int projectTotal;

  /// 이번 달 환경정비 수행 횟수
  final int care;

  /// 지난달 순위 — [_Metric] 순서대로 (0이면 지난달엔 순위가 없었다)
  final List<int> lastRank;

  Color get color => staffOf(name).color;

  bool get isMe => name == me;

  /// 프로젝트 달성률 (%)
  double get projectRate =>
      projectTotal == 0 ? 0 : projectDone * 100 / projectTotal;
}

/// 이번 달 실적 (목업) — 실제 연동 시 서버 집계로 교체한다
final _rankers = [
  _Ranker(
    name: me,
    team: '트레이너',
    branch: '강남점',
    revenue: 18400000,
    newSignups: 3,
    reSignups: 5,
    kindness: 96,
    reviews: 32,
    stars: 4.8,
    projectDone: 4,
    projectTotal: 5,
    care: 84,
    lastRank: [2, 1, 3, 2, 2],
  ),
  _Ranker(
    name: '박준현',
    team: '트레이너',
    branch: '강남점',
    revenue: 21200000,
    newSignups: 5,
    reSignups: 4,
    kindness: 90,
    reviews: 27,
    stars: 4.5,
    projectDone: 3,
    projectTotal: 4,
    care: 71,
    lastRank: [1, 3, 2, 3, 1],
  ),
  _Ranker(
    name: '유찬빈',
    team: '트레이너',
    branch: '강남점',
    revenue: 14900000,
    newSignups: 2,
    reSignups: 6,
    kindness: 88,
    reviews: 21,
    stars: 4.4,
    projectDone: 2,
    projectTotal: 4,
    care: 63,
    lastRank: [4, 4, 5, 4, 4],
  ),
  _Ranker(
    name: '전상현',
    team: 'FC',
    branch: '강남점',
    revenue: 16800000,
    newSignups: 7,
    reSignups: 2,
    kindness: 92,
    reviews: 24,
    stars: 4.6,
    projectDone: 3,
    projectTotal: 3,
    care: 58,
    lastRank: [3, 2, 1, 5, 3],
  ),
  _Ranker(
    name: '민중기',
    team: '대표',
    branch: '강남점',
    revenue: 9600000,
    newSignups: 1,
    reSignups: 3,
    kindness: 85,
    reviews: 12,
    stars: 4.2,
    projectDone: 6,
    projectTotal: 7,
    care: 92,
    lastRank: [6, 6, 4, 1, 5],
  ),
  _Ranker(
    name: '문명진',
    team: '마케팅',
    branch: '강남점',
    revenue: 7300000,
    newSignups: 0,
    reSignups: 0,
    kindness: 80,
    reviews: 6,
    stars: 4.0,
    projectDone: 5,
    projectTotal: 6,
    care: 47,
    lastRank: [7, 7, 6, 6, 7],
  ),
  _Ranker(
    name: '이준경',
    team: '개발',
    branch: '강남점',
    revenue: 0,
    newSignups: 0,
    reSignups: 0,
    kindness: 78,
    reviews: 4,
    stars: 3.9,
    projectDone: 8,
    projectTotal: 9,
    care: 39,
    lastRank: [8, 8, 7, 7, 6],
  ),
  _Ranker(
    name: '이지영',
    team: '트레이너',
    branch: '잠실점',
    revenue: 17600000,
    newSignups: 4,
    reSignups: 4,
    kindness: 93,
    reviews: 29,
    stars: 4.7,
    projectDone: 2,
    projectTotal: 3,
    care: 76,
    lastRank: [1, 1, 2, 1, 1],
  ),
  _Ranker(
    name: '김재훈',
    team: 'FC',
    branch: '잠실점',
    revenue: 12100000,
    newSignups: 6,
    reSignups: 1,
    kindness: 87,
    reviews: 18,
    stars: 4.3,
    projectDone: 1,
    projectTotal: 2,
    care: 54,
    lastRank: [2, 2, 1, 2, 2],
  ),
];

/// 지점 필터 — 맨 앞은 모든 지점을 함께 보는 '전체'
const _allBranches = '전체';
final _branches = [
  _allBranches,
  ...{for (final r in _rankers) r.branch},
];

/// 시상대 색 — 위(밝은 쪽), 아래(진한 쪽)
///
/// 회색 계열로 두면 3위 받침대가 화면 배경([AppColors.gray50] ==
/// [AppColors.background])과 같은 색이라 아예 안 보인다. 등수는 금·은·동이
/// 제일 빨리 읽히므로 여기서만 포인트 컬러 밖의 색을 쓴다.
(Color, Color) _medal(int rank) => switch (rank) {
  1 => (Color(0xFFFFC94B), Color(0xFFE59A12)),
  2 => (Color(0xFFC9D2DB), Color(0xFF97A3B0)),
  _ => (Color(0xFFDCA06C), Color(0xFFB1723E)),
};

/// 랭킹 한 줄 — 순위와 그 항목에서의 값·근거를 함께 담는다
class _Entry {
  _Entry({
    required this.rank,
    required this.ranker,
    required this.value,
    required this.note,
  });

  final int rank;
  final _Ranker ranker;

  /// 정렬 기준이 되는 값 (항목마다 단위가 다르다)
  final double value;

  /// 왜 이 값인지 (예: '신규 3 · 재등록 5')
  final String note;
}

/// 항목별 값 — 종합만 다른 사람 실적이 있어야 계산된다
double _valueOf(_Ranker r, _Metric metric, List<_Ranker> pool) =>
    switch (metric) {
      _Metric.revenue => r.revenue.toDouble(),
      _Metric.kindness => r.kindness.toDouble(),
      _Metric.project => r.projectRate,
      _Metric.care => r.care.toDouble(),
      _Metric.overall => _overall(r, pool),
    };

/// 종합 점수 — 항목마다 1등을 100점으로 두고 상대 위치를 평균 낸다.
///
/// 매출은 원, 환경정비는 횟수처럼 단위가 제각각이라 그냥 더할 수 없다.
/// 같은 지점 안에서 각자 1등 대비 몇 %인지로 바꾼 뒤 평균을 낸다.
double _overall(_Ranker r, List<_Ranker> pool) {
  const parts = [
    _Metric.revenue,
    _Metric.kindness,
    _Metric.project,
    _Metric.care,
  ];
  var sum = 0.0;
  for (final part in parts) {
    final top = pool
        .map((other) => _valueOf(other, part, pool))
        .fold(0.0, (a, b) => a > b ? a : b);
    if (top > 0) sum += _valueOf(r, part, pool) / top * 100;
  }
  return sum / parts.length;
}

/// 값 아래 붙는 근거 한 줄
String _noteOf(_Ranker r, _Metric metric) => switch (metric) {
  _Metric.revenue => '신규 ${r.newSignups} · 재등록 ${r.reSignups}',
  _Metric.kindness => '리뷰 ${r.reviews}건 · ★${r.stars}',
  _Metric.project => '${r.projectDone} / ${r.projectTotal}건',
  _Metric.care => '이번 달 ${r.care}회',
  _Metric.overall => '4개 항목 평균',
};

/// 순위표에 찍히는 값 — 항목마다 단위가 다르다
String _format(_Metric metric, double value) => switch (metric) {
  _Metric.revenue => '${_comma((value / 10000).round())}만원',
  _Metric.kindness => '${value.round()}점',
  _Metric.project => '${value.round()}%',
  _Metric.care => '${value.round()}회',
  _Metric.overall => '${value.round()}점',
};

/// 앞사람과의 차이를 "더 해야 하는 양"으로 바꾼다
///
/// 프로젝트 달성만 %를 그대로 보여주면 뭘 해야 할지 모르므로
/// 내가 맡은 건수 기준으로 몇 건을 더 끝내야 하는지로 환산한다.
String _gapLabel(_Metric metric, double gap, _Ranker r) => switch (metric) {
  _Metric.revenue => '${_comma((gap / 10000).ceil())}만원',
  _Metric.kindness => '${gap.ceil()}점',
  _Metric.project =>
    r.projectTotal == 0
        ? '${gap.ceil()}%'
        : '${(gap * r.projectTotal / 100).ceil()}건',
  _Metric.care => '${gap.ceil()}회',
  _Metric.overall => '${gap.ceil()}점',
};

/// 1234 → '1,234'
String _comma(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
