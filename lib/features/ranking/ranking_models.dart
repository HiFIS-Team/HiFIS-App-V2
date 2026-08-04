part of 'ranking_screen.dart';

/// 랭킹 항목
///
/// 화면에 찍히는 단위가 항목마다 다르다 — 매출은 **금액**, 수업은 **개수**,
/// 친절·프로젝트·환경정비는 **점수 원장 합**이다. 종합은 나머지 다섯을
/// 100점으로 환산해 평균 낸 값이라 항상 맨 뒤에 둔다.
enum _Metric {
  revenue('매출', '매출'),
  kindness('친절 점수', '친절'),
  project('프로젝트 달성', '프로젝트'),
  care('환경정비', '환경정비'),
  lesson('수업 개수', '수업'),
  overall('종합', '종합');

  const _Metric(this.label, this.short);

  final String label;

  /// 폰 탭처럼 칸이 좁을 때 쓰는 짧은 이름
  final String short;
}

/// 랭킹에 오르는 사람 한 명
///
/// 서버 `RankingBoardItem` 을 화면 말로 옮긴 것이다. 이름·아바타 색은
/// 공용 명단([staffList])을 따르고, 이번 달 실적만 여기에 담는다.
class _Ranker {
  const _Ranker({
    required this.id,
    required this.name,
    required this.team,
    required this.branch,
    required this.revenue,
    required this.newSignups,
    required this.reSignups,
    required this.kindness,
    required this.reviews,
    required this.projectScore,
    required this.projectDone,
    required this.projectTotal,
    required this.careScore,
    required this.care,
    required this.lessons,
    required this.lessonScore,
    required this.lastRank,
  });

  factory _Ranker.fromRow(RankingRow row) => _Ranker(
    id: row.employeeId,
    name: row.name,
    team: StaffDirectory.instance.byId(row.employeeId)?.rank.label ?? '',
    branch: StaffDirectory.instance.branchName(row.branchId),
    revenue: row.revenue,
    newSignups: row.newSignups,
    reSignups: row.reSignups,
    kindness: row.kindness,
    reviews: row.reviews,
    projectScore: row.projectScore,
    projectDone: row.projectDone,
    projectTotal: row.projectTotal,
    careScore: row.careScore,
    care: row.care,
    lessons: row.lessons,
    lessonScore: row.lessonScore,
    lastRank: row.lastRank,
  );

  final String id;
  final String name;

  /// 직급 — 이름 아래 붙는다
  final String team;

  /// 소속 지점 이름 (지점 필터가 이 값을 쓴다)
  final String branch;

  /// 이번 달 매출 (원)
  final int revenue;
  final int newSignups;
  final int reSignups;

  /// 회원 리뷰로 환산한 친절 점수 (100점 만점)
  final int kindness;
  final int reviews;

  /// 프로젝트 달성 점수와, 맡은 프로젝트 중 끝낸 개수
  final int projectScore;
  final int projectDone;
  final int projectTotal;

  /// 환경정비 점수와 이번 달 수행 횟수
  final int careScore;
  final int care;

  /// 이번 달 수행한 수업(세션) 개수와 그것으로 쌓인 점수
  final int lessons;
  final int lessonScore;

  /// 지난달 순위 — [_Metric] 순서대로 (0이면 지난달엔 순위가 없었다)
  final List<int> lastRank;

  Color get color =>
      StaffDirectory.instance.byId(id)?.color ?? staffOf(name).color;

  bool get isMe => id == currentUser?.id;

  /// 지난달 그 항목 순위 — 항목이 늘어난 뒤의 옛 응답이면 0(순위 없음)
  int lastRankOf(_Metric metric) =>
      metric.index < lastRank.length ? lastRank[metric.index] : 0;
}

/// 이번 달 실적 — `GET /scores/ranking/board` 로 채운다
final _rankers = <_Ranker>[];

/// 랭킹판 받아오기 — 전사로 한 번 받고 지점 필터는 화면에서 건다
Future<void> _loadRanking() async {
  final rows = await ScoreApi.board();
  _rankers
    ..clear()
    ..addAll([for (final row in rows) _Ranker.fromRow(row)]);
}

/// 지점 필터 — 맨 앞은 모든 지점을 함께 보는 '전체'
const _allBranches = '전체';
List<String> get _branches => [
  _allBranches,
  ...{
    for (final r in _rankers)
      if (r.branch.isNotEmpty) r.branch,
  },
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
      _Metric.project => r.projectScore.toDouble(),
      _Metric.care => r.careScore.toDouble(),
      _Metric.lesson => r.lessons.toDouble(),
      _Metric.overall => _overall(r, pool),
    };

/// 종합 점수 — 항목마다 1등을 100점으로 두고 상대 위치를 평균 낸다.
///
/// 매출은 원, 수업은 개수처럼 단위가 제각각이라 그냥 더할 수 없다.
/// 같은 지점 안에서 각자 1등 대비 몇 %인지로 바꾼 뒤 평균을 낸다.
double _overall(_Ranker r, List<_Ranker> pool) {
  const parts = [
    _Metric.revenue,
    _Metric.kindness,
    _Metric.project,
    _Metric.care,
    _Metric.lesson,
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
  _Metric.kindness => '리뷰 ${r.reviews}건',
  _Metric.project => '${r.projectDone} / ${r.projectTotal}건',
  _Metric.care => '이번 달 ${r.care}회',
  _Metric.lesson => '${r.lessonScore}점',
  _Metric.overall => '5개 항목 평균',
};

/// 순위표에 찍히는 값 — 항목마다 단위가 다르다
String _format(_Metric metric, double value) => switch (metric) {
  _Metric.revenue => '${_comma((value / 10000).round())}만원',
  _Metric.kindness => '${value.round()}점',
  _Metric.project => '${value.round()}점',
  _Metric.care => '${value.round()}점',
  _Metric.lesson => '${value.round()}회',
  _Metric.overall => '${value.round()}점',
};

/// 앞사람과의 차이를 "더 해야 하는 양"으로 바꾼다
String _gapLabel(_Metric metric, double gap) => switch (metric) {
  _Metric.revenue => '${_comma((gap / 10000).ceil())}만원',
  _Metric.lesson => '${gap.ceil()}회',
  _ => '${gap.ceil()}점',
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
