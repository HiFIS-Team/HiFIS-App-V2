import 'api_client.dart';

export 'period.dart' show periodKey;

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
class ScoreApi {
  ScoreApi._();

  static final _client = ApiClient.instance;

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
