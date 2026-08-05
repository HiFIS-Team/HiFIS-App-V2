import '../client/api_client.dart';

export '../client/period.dart' show periodKey;

/// 동료 평가 항목 다섯 가지 — 서버 키와 화면 이름
enum PeerCategory {
  competency('competency', '업무 역량'),
  collaboration('collaboration', '협업 소통'),
  contribution('contribution', '성과 기여도'),
  attitude('attitude', '태도·규정 준수'),
  leadership('leadership', '리더십');

  const PeerCategory(this.wire, this.label);

  final String wire;
  final String label;

  static PeerCategory parse(String value) =>
      PeerCategory.values.firstWhere((c) => c.wire == value);
}

/// 항목마다 매기는 별 개수 — 서버가 1~5 만 받는다 (0은 422)
const peerStarCount = 5;

/// 별 하나가 몇 점인지
///
/// 서버 `_compute_total` 과 **반드시 같아야 한다** — 화면에 보이는 점수와
/// 실제로 쌓이는 점수가 갈리면 아무도 못 믿는다.
/// 자기 평가는 별당 1점(최대 25), 동료 평가는 별당 4점(최대 100).
int peerPointsPerStar({required bool isSelf}) => isSelf ? 1 : 4;

/// 제출한 동료 평가 한 건 (서버 `PeerReviewOut`)
///
/// **제출하면 고칠 수 없다.** 같은 사람·같은 달로 다시 내면 409 가 온다.
class PeerReview {
  PeerReview({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.isSelf,
    required this.period,
    required this.stars,
    required this.reasons,
    required this.total,
    required this.submittedAt,
  });

  factory PeerReview.fromJson(Map<String, dynamic> json) {
    final scores = (json['scores'] as Map).cast<String, dynamic>();
    final reasons = (json['reasons'] as Map? ?? const {})
        .cast<String, dynamic>();
    return PeerReview(
      id: json['id'] as String,
      reviewerId: json['reviewerId'] as String,
      revieweeId: json['revieweeId'] as String,
      isSelf: json['isSelf'] as bool? ?? false,
      period: json['period'] as String,
      stars: {
        for (final category in PeerCategory.values)
          category: scores[category.wire] as int? ?? 0,
      },
      reasons: {
        for (final category in PeerCategory.values)
          category: reasons[category.wire] as String? ?? '',
      },
      total: json['total'] as int,
      submittedAt: DateTime.parse(json['submittedAt'] as String).toLocal(),
    );
  }

  final String id;

  /// 평가를 쓴 사람
  final String reviewerId;

  /// 평가를 받은 사람
  final String revieweeId;

  final bool isSelf;

  /// `2026-07`
  final String period;

  /// 항목별 별 개수 (1~5)
  final Map<PeerCategory, int> stars;

  /// 항목별 사유 — 서버가 다섯 개 모두 요구한다
  final Map<PeerCategory, String> reasons;

  /// 서버가 계산한 점수 — 받은 사람에게 그대로 쌓인다
  final int total;

  final DateTime submittedAt;
}

/// `/peer-reviews` — 동료 평가
class PeerReviewApi {
  PeerReviewApi._();

  static final _client = ApiClient.instance;

  /// 평가 목록
  ///
  /// **직원·점장은 본인이 쓴 것만** 온다 — 누가 누구를 어떻게 평가했는지
  /// 서로 못 보게 막아 둔 것이다. 남이 쓴 평가는 면담 자료라
  /// **대표·관리자만** 전체를 받는다.
  static Future<List<PeerReview>> list({
    String? revieweeId,
    String? period,
  }) async {
    final rows = await _client.getList(
      '/peer-reviews',
      query: {'revieweeId': ?revieweeId, 'period': ?period},
    );
    return [
      for (final row in rows)
        PeerReview.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 평가 제출 — 다섯 항목의 별점과 사유가 모두 있어야 한다
  ///
  /// 이미 낸 사람·달이면 409 `ALREADY_SUBMITTED`.
  static Future<PeerReview> create({
    required String revieweeId,
    required String period,
    required Map<PeerCategory, int> stars,
    required Map<PeerCategory, String> reasons,
  }) async {
    final data = await _client.post(
      '/peer-reviews',
      body: {
        'revieweeId': revieweeId,
        'period': period,
        'scores': {
          for (final entry in stars.entries) entry.key.wire: entry.value,
        },
        'reasons': {
          for (final entry in reasons.entries) entry.key.wire: entry.value,
        },
      },
    );
    return PeerReview.fromJson(data!);
  }
}
