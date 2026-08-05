import '../client/api_client.dart';

export '../client/period.dart' show periodKey;

/// 점수 원장 분류 — 서버 `ScoreCategory`
///
/// 랭킹·진급 합산이 전부 이 원장 하나에서 나온다. 각 업무 화면이 쌓아 올린
/// 점수가 여기 한 줄씩 모인다.
enum ScoreCategory {
  env('ENV', '환경정비'),
  peer('PEER', '동료 평가'),
  kindness('KINDNESS', '회원 친절도'),
  lesson('CLASS', '수업 개수'),
  contrib('CONTRIB', '센터 기여도'),
  project('PROJECT', '프로젝트 달성'),
  operator('OPERATOR', '운영자 부여');

  const ScoreCategory(this.wire, this.label);

  final String wire;
  final String label;

  static ScoreCategory parse(String? value) => ScoreCategory.values.firstWhere(
    (c) => c.wire == value,
    orElse: () => ScoreCategory.operator,
  );
}

/// 랭킹판 한 줄 (서버 `RankingBoardItem`)
///
/// **순위는 앱이 매긴다.** 서버는 사람마다 항목별 값만 주고, 지점 필터를
/// 바꿀 때마다 다시 요청하지 않아도 되게 앱이 그 안에서 세운다.
class RankingRow {
  RankingRow({
    required this.employeeId,
    required this.name,
    required this.branchId,
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

  factory RankingRow.fromJson(Map<String, dynamic> json) => RankingRow(
    employeeId: json['employeeId'] as String,
    name: json['name'] as String,
    branchId: json['branchId'] as String? ?? '',
    revenue: json['revenue'] as int? ?? 0,
    newSignups: json['newSignups'] as int? ?? 0,
    reSignups: json['reSignups'] as int? ?? 0,
    kindness: json['kindness'] as int? ?? 0,
    reviews: json['reviews'] as int? ?? 0,
    projectScore: json['projectScore'] as int? ?? 0,
    projectDone: json['projectDone'] as int? ?? 0,
    projectTotal: json['projectTotal'] as int? ?? 0,
    careScore: json['careScore'] as int? ?? 0,
    care: json['care'] as int? ?? 0,
    lessons: json['lessons'] as int? ?? 0,
    lessonScore: json['lessonScore'] as int? ?? 0,
    lastRank: [
      for (final r in (json['lastRank'] as List<dynamic>? ?? const []))
        r as int,
    ],
  );

  final String employeeId;
  final String name;
  final String branchId;

  /// 그 달 등록권 결제액 (원)
  final int revenue;
  final int newSignups;
  final int reSignups;

  /// 친절 점수(원장 합)와 받은 설문 수
  final int kindness;
  final int reviews;

  /// 프로젝트 점수(원장 합)와 그 달 기한인 프로젝트 중 담당분
  final int projectScore;
  final int projectDone;
  final int projectTotal;

  /// 환경정비 점수(원장 합)와 수행 횟수
  final int careScore;
  final int care;

  /// 그 달 수행한 세션 수와 그것으로 쌓인 점수
  final int lessons;
  final int lessonScore;

  /// 지난달 순위 — [매출, 친절, 프로젝트, 환경, 수업, 종합]. **0 이면 순위 없음**
  final List<int> lastRank;
}

/// 점수 원장 한 줄 (서버 `ScoreEventOut`)
class ScoreEvent {
  ScoreEvent({
    required this.id,
    required this.employeeId,
    required this.branchId,
    required this.category,
    required this.points,
    required this.period,
    required this.createdAt,
    this.reason,
    this.sourceRefId,
    this.createdById,
  });

  factory ScoreEvent.fromJson(Map<String, dynamic> json) => ScoreEvent(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    branchId: json['branchId'] as String,
    category: ScoreCategory.parse(json['category'] as String?),
    points: json['points'] as int,
    period: json['period'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    reason: json['reason'] as String?,
    sourceRefId: json['sourceRefId'] as String?,
    createdById: json['createdById'] as String?,
  );

  final String id;
  final String employeeId;
  final String branchId;
  final ScoreCategory category;

  /// 음수면 감점·취소다
  final int points;

  final String? reason;

  /// 이 점수를 만든 원본 — 부여 기록 id 이거나 `sales:2026-07` `offhours:...` 꼴
  final String? sourceRefId;

  /// `2026-07`
  final String period;

  /// 준 사람 — **시스템이 자동으로 쌓은 점수는 비어 있다**
  final String? createdById;

  final DateTime createdAt;

  /// 사람이 준 게 아니라 기록에서 자동으로 들어온 점수인가
  bool get automatic => createdById == null;
}

/// 분류별 점수 합계 (서버 `ScoreSummary`)
class ScoreSummary {
  ScoreSummary({
    required this.employeeId,
    required this.total,
    required this.byCategory,
    this.period,
  });

  factory ScoreSummary.fromJson(Map<String, dynamic> json) {
    final by = (json['byCategory'] as Map? ?? const {}).cast<String, dynamic>();
    return ScoreSummary(
      employeeId: json['employeeId'] as String,
      total: json['total'] as int,
      period: json['period'] as String?,
      byCategory: {
        for (final category in ScoreCategory.values)
          category: by[category.wire] as int? ?? 0,
      },
    );
  }

  final String employeeId;
  final String? period;
  final int total;
  final Map<ScoreCategory, int> byCategory;

  int operator [](ScoreCategory category) => byCategory[category] ?? 0;
}

/// `/scores` — 점수 원장
/// 랭킹판에서 자리가 바뀐 한 건 (서버 `RankOvertakeOut`)
///
/// [gap] 은 **항목마다 단위가 다르다** — 매출이면 원, 수업이면 개수,
/// 나머지는 점이다. 서버가 단위를 안 붙이는 건 화면이 이미 어느 탭인지
/// 알기 때문이다.
class RankOvertake {
  RankOvertake({
    required this.id,
    required this.metric,
    required this.moverName,
    required this.moverBranchId,
    required this.passedName,
    required this.gap,
    required this.rank,
    required this.createdAt,
  });

  factory RankOvertake.fromJson(Map<String, dynamic> json) => RankOvertake(
    id: json['id'] as String,
    metric: json['metric'] as String,
    moverName: json['moverName'] as String,
    moverBranchId: json['moverBranchId'] as String?,
    passedName: json['passedName'] as String,
    gap: (json['gap'] as num).toDouble(),
    rank: json['rank'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String metric;

  /// 앞지른 사람
  final String moverName;
  final String? moverBranchId;

  /// 밀려난 사람
  final String passedName;

  final double gap;

  /// 앞지른 사람의 새 등수
  final int rank;

  final DateTime createdAt;
}

class ScoreApi {
  ScoreApi._();

  static final _client = ApiClient.instance;

  /// 누가 누구를 앞질렀나 — **MASTER · ADMIN 만** (그 밖에는 403)
  ///
  /// 5분마다 도는 서버 잡이 채운다. 랭킹은 볼 때마다 다시 계산하는 값이라
  /// 서버가 찍어 두지 않으면 '언제 바뀌었나'를 알 수 없다.
  static Future<List<RankOvertake>> overtakes({
    String? metric,
    int limit = 20,
  }) async {
    final rows = await _client.getList(
      '/scores/overtakes',
      query: {'metric': ?metric, 'limit': '$limit'},
    );
    return [
      for (final row in rows)
        RankOvertake.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 랭킹판 — 사람마다 항목별 값과 지난달 순위
  ///
  /// [period] 를 비우면 이번 달. [branchId] 를 주면 그 지점만 센다
  /// (앱은 전사로 한 번 받아 화면에서 거른다 — 지점 탭을 옮길 때마다
  /// 다시 요청하지 않으려고).
  static Future<List<RankingRow>> board({
    String? period,
    String? branchId,
  }) async {
    final rows = await _client.getList(
      '/scores/ranking/board',
      query: {'period': ?period, 'branchId': ?branchId},
    );
    return [
      for (final row in rows)
        RankingRow.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 원장 조회 (최신순)
  static Future<List<ScoreEvent>> events({
    String? employeeId,
    ScoreCategory? category,
    String? period,
  }) async {
    final rows = await _client.getList(
      '/scores',
      query: {
        'employeeId': ?employeeId,
        'category': ?category?.wire,
        'period': ?period,
      },
    );
    return [
      for (final row in rows)
        ScoreEvent.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 분류별 합계 — 직원은 **본인 것만** 볼 수 있다 (남의 것은 403)
  static Future<ScoreSummary> summary({
    required String employeeId,
    String? period,
  }) async {
    final data = await _client.get(
      '/scores/summary',
      query: {'employeeId': employeeId, 'period': ?period},
    );
    return ScoreSummary.fromJson(data);
  }
}
