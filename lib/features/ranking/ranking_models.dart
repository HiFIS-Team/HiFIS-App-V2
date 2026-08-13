part of 'ranking_screen.dart';

/// 랭킹 항목
///
/// 화면에 찍히는 단위가 항목마다 다르다 — 매출은 **금액**, 수업은 **개수**,
/// 친절·프로젝트·환경정비는 **점수 원장 합**이다.
///
/// 종합은 **그 달 쌓은 점수를 그대로 더한 값**이라 항상 맨 뒤에 둔다.
/// 매출만 단위가 달라서 서버가 점수로 바꿔(만원 단위 × 0.25) **말일에** 얹는다.
enum _Metric {
  revenue('매출', '매출', 'revenue'),
  kindness('친절 점수', '친절', 'kindness'),
  project('프로젝트 달성', '프로젝트', 'project'),
  care('환경정비', '환경정비', 'care'),
  lesson('수업 개수', '수업', 'lesson'),
  overall('종합', '종합', 'overall');

  const _Metric(this.label, this.short, this.wire);

  final String label;

  /// 서버 `ranking_board.METRICS` 의 이름 — 추월 기록을 항목별로 받을 때 쓴다
  final String wire;

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
    required this.blogScore,
    required this.instaScore,
    required this.otptScore,
    required this.overall,
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
    blogScore: row.blogScore,
    instaScore: row.instaScore,
    otptScore: row.otptScore,
    overall: row.overall,
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

  /// 방문 경로로 붙은 유입 점수 — 회원 등록 한 건에 5점씩
  ///
  /// 워크인·지인소개는 점수가 없어서 칸도 없다. 종합에는 쌓인 점수가 그대로
  /// 들어가고, 점수 내역에서는 셋을 갈라서 보여준다.
  final int blogScore;
  final int instaScore;
  final int otptScore;

  /// 종합 점수 — **서버가 더한 값을 그대로 쓴다**
  ///
  /// 그 달 쌓은 점수 합에 매출 점수(만원 단위 × 0.25)를 얹은 값이다.
  /// 매출 점수는 **말일부터** 붙으므로 월중에는 매출이 종합에 안 들어간다.
  final int overall;

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

/// '전 지점' — 셸 헤더 고르개가 안 걸렸을 때의 값 ([branchScopeName])
///
/// HQ 지점 이름과 **같은 글자**다. HQ 소속(MASTER·ADMIN)인 사람의 실적은
/// 어차피 랭킹에 안 오르므로 둘이 부딪칠 일이 없다.
const _allBranches = '전 지점';

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

/// 항목별 값 — 종합은 서버가 더해 준 값을 그대로 쓴다
double _valueOf(_Ranker r, _Metric metric, List<_Ranker> pool) =>
    switch (metric) {
      _Metric.revenue => r.revenue.toDouble(),
      _Metric.kindness => r.kindness.toDouble(),
      _Metric.project => r.projectScore.toDouble(),
      _Metric.care => r.careScore.toDouble(),
      _Metric.lesson => r.lessons.toDouble(),
      _Metric.overall => r.overall.toDouble(),
    };

/// 값 아래 붙는 근거 한 줄
String _noteOf(_Ranker r, _Metric metric) => switch (metric) {
  _Metric.revenue => '신규 ${r.newSignups} · 재등록 ${r.reSignups}',
  _Metric.kindness => '리뷰 ${r.reviews}건',
  _Metric.project => '${r.projectDone} / ${r.projectTotal}건',
  _Metric.care => '이번 달 ${r.care}회',
  _Metric.lesson => '${r.lessonScore}점',
  _Metric.overall => '쌓은 점수 합',
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
