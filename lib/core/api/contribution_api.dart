import 'api_client.dart';

/// 센터 기여 항목 — 서버 `ContribType`
///
/// 앞의 셋은 대표·관리자·점장이 보고 직접 준다.
/// 매출 성과는 급여 마감 때 서버가 계산해 넣으므로 줄 수 없다.
enum ContribType {
  idea('IDEA', '창의적 아이디어', 3),
  goal('GOAL', '자발적 목표 업무', 10),
  extraWork('EXTRA_WORK', '근무 외 출근', 10),
  sales('SALES', '매출 성과', 0);

  const ContribType(this.wire, this.label, this.points);

  final String wire;
  final String label;

  /// 한 건당 고정 점수 — 주는 사람이 고르지 않는다
  ///
  /// 매출 성과만 0이다. 매출액에서 계산되는 값이라 고정값이 없다.
  final int points;

  /// 사람이 직접 줄 수 있는 항목인가
  bool get grantable => this != ContribType.sales;

  static ContribType parse(String? value) => ContribType.values.firstWhere(
    (t) => t.wire == value,
    orElse: () => ContribType.idea,
  );
}

/// 부여된 기여 한 건 (서버 `ContributionGrantOut`)
///
/// 자동으로 쌓이는 근무 외 출근·매출 성과는 여기 안 나온다.
/// 그것들은 점수 원장(`/scores`)에만 있다.
class ContributionGrant {
  ContributionGrant({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.points,
    required this.reason,
    required this.grantedById,
    required this.createdAt,
    this.hours,
  });

  factory ContributionGrant.fromJson(Map<String, dynamic> json) =>
      ContributionGrant(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        type: ContribType.parse(json['type'] as String?),
        points: json['points'] as int,
        reason: json['reason'] as String,
        grantedById: json['grantedById'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        hours: json['hours'] as int?,
      );

  final String id;

  /// 점수를 받은 사람
  final String employeeId;

  final ContribType type;

  /// 근무 외 출근일 때만 채워진다 — 점수에는 영향이 없고 기록용이다
  final int? hours;

  final int points;

  /// 왜 줬는지 — 서버가 필수로 받는다
  final String reason;

  /// 준 사람
  final String grantedById;

  final DateTime createdAt;
}

/// `/contributions` — 센터 기여도 부여
class ContributionApi {
  ContributionApi._();

  static final _client = ApiClient.instance;

  /// 부여 내역 (최신순)
  ///
  /// 기간으로 거를 방법이 없어서 전부 온다 (backend-gap.md 34번).
  /// 이번 달 것만 쓰려면 앱이 걸러야 한다.
  static Future<List<ContributionGrant>> list({String? employeeId}) async {
    final rows = await _client.getList(
      '/contributions',
      query: {'employeeId': ?employeeId},
    );
    return [
      for (final row in rows)
        ContributionGrant.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 기여 점수 주기 — 대표·관리자·점장만 (직원은 403)
  ///
  /// 점수는 항목마다 정해져 있어 주는 쪽이 고르지 않는다.
  /// 매출 성과를 넣으면 400 `SALES_AUTO`.
  static Future<ContributionGrant> create({
    required String employeeId,
    required ContribType type,
    required String reason,
    int? hours,
  }) async {
    final data = await _client.post(
      '/contributions',
      body: {
        'employeeId': employeeId,
        'type': type.wire,
        'reason': reason,
        'hours': ?hours,
      },
    );
    return ContributionGrant.fromJson(data!);
  }
}
