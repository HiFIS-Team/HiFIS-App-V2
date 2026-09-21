import '../client/api_client.dart';

export '../client/period.dart' show periodKey;

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

  /// 한 건당 점수 — **자발적 목표만 고를 수 있다** (아래 [pickablePoints])
  ///
  /// 나머지는 고정이다. 매출 성과만 0인데, 매출액에서 계산되는 값이라
  /// 고정값이 없다.
  final int points;

  /// 사람이 직접 줄 수 있는 항목인가
  bool get grantable => this != ContribType.sales;

  /// 주는 사람이 점수를 고를 수 있는가 — **자발적 목표뿐이다**
  ///
  /// 큰 목표와 작은 목표가 같은 10점을 받아서 무게를 실을 자리가 없었다
  /// (2026-09-21 대표 요청). 아이디어는 낸 것 자체를 세는 값이고 근무 외
  /// 출근은 시간이 정하는 값이라 고를 것이 없다.
  bool get pickablePoints => this == ContribType.goal;

  /// 고를 수 있는 점수 폭 — 서버 `GOAL_POINTS_MIN`·`MAX` 와 **같아야 한다**
  ///
  /// 한쪽만 넓히면 앱에서 고른 값이 서버에서 422 로 되돌아온다.
  static const goalMin = 5;
  static const goalMax = 20;

  /// 고르개에 세울 값들 — 5부터 20까지 다섯씩
  ///
  /// 한 칸씩(5·6·7…) 열면 열여섯 칸이라 눌러 고르기가 어렵다. 다섯씩이면
  /// 네 칸이고, 10이 가운데라 여태 쓰던 값이 그대로 기본이 된다.
  static const goalSteps = [5, 10, 15, 20];

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
  /// [period] 는 `2026-07`. 안 주면 그 사람 것이 전부 온다.
  static Future<List<ContributionGrant>> list({
    String? employeeId,
    String? grantedById,
    String? period,
  }) async {
    final rows = await _client.getList(
      '/contributions',
      query: {
        'employeeId': ?employeeId,
        // 준 사람으로 거르기 — '내가 준 기여 내역'이 쓴다
        'grantedById': ?grantedById,
        'period': ?period,
      },
    );
    return [
      for (final row in rows)
        ContributionGrant.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 기여 점수 주기 — 대표·관리자·점장만 (직원은 403)
  ///
  /// 점수는 항목마다 정해져 있다. **자발적 목표만 [points] 로 고른다**
  /// (5~20, 2026-09-21). 다른 항목에 실어 보내면 400 `POINTS_FIXED` 다 —
  /// 조용히 버리면 20점을 줬다고 생각한 사람이 3점이 들어간 걸 모른다.
  ///
  /// 매출 성과를 넣으면 400 `SALES_AUTO`.
  static Future<ContributionGrant> create({
    required String employeeId,
    required ContribType type,
    required String reason,
    int? hours,
    int? points,
  }) async {
    final data = await _client.post(
      '/contributions',
      body: {
        'employeeId': employeeId,
        'type': type.wire,
        'reason': reason,
        'hours': ?hours,
        'points': ?points,
      },
    );
    return ContributionGrant.fromJson(data!);
  }
}
