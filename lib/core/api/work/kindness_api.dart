import '../client/api_client.dart';

/// 컴플레인 처리 단계 — 서버 `ComplaintStatus`
///
/// 설문의 '개선했으면 하는 부분' 이 곧 컴플레인이다. 칭찬만 있는 설문은
/// 이 값이 의미가 없어서 앱이 컴플레인으로 세지 않는다.
enum ComplaintStatus {
  pending('PENDING', '미처리'),
  working('WORKING', '해결중'),

  /// 완료 승인 대기 — MANAGER·MEMBER 가 완료를 눌렀고 대표가 아직 안 봤다
  ///
  /// 완료를 찍으면 찍은 사람에게 환경정비 `클레임해결` 점수가 붙어서
  /// 대표가 한 번 본다 (2026-08-31).
  doneRequested('DONE_REQUESTED', '완료 승인 대기'),
  done('DONE', '해결 완료');

  const ComplaintStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ComplaintStatus parse(String? value) =>
      ComplaintStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ComplaintStatus.pending,
      );
}

/// 회원이 남긴 친절도 설문 한 건 (서버 `KindnessSurveyOut`)
class KindnessSurvey {
  KindnessSurvey({
    required this.id,
    required this.motivation,
    required this.praisedEmployeeId,
    required this.praiseComment,
    required this.memberName,
    required this.memberPhone,
    required this.consent,
    required this.submittedAt,
    required this.improvementStatus,
    this.doneRequestedById,
    this.improvement,
    this.resolvedAt,
    this.resolvedById,
  });

  factory KindnessSurvey.fromJson(Map<String, dynamic> json) => KindnessSurvey(
    id: json['id'] as String,
    motivation: json['motivation'] as String? ?? '',
    praisedEmployeeId: json['praisedEmployeeId'] as String? ?? '',
    praiseComment: json['praiseComment'] as String? ?? '',
    improvement: json['improvement'] as String?,
    memberName: json['memberName'] as String? ?? '',
    memberPhone: json['memberPhone'] as String? ?? '',
    consent: json['consent'] as bool? ?? false,
    submittedAt: DateTime.parse(json['submittedAt'] as String).toLocal(),
    improvementStatus: ComplaintStatus.parse(
      json['improvementStatus'] as String?,
    ),
    doneRequestedById: json['doneRequestedById'] as String?,
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.parse(json['resolvedAt'] as String).toLocal(),
    resolvedById: json['resolvedById'] as String?,
  );

  final String id;

  /// 운동을 시작하게 된 계기
  final String motivation;

  /// 칭찬받은 직원
  final String praisedEmployeeId;
  final String praiseComment;

  /// 개선했으면 하는 부분 — 비어 있으면 컴플레인이 아니다
  final String? improvement;

  final String memberName;
  final String memberPhone;

  /// 개인정보 수집 및 이용 동의
  final bool consent;

  final DateTime submittedAt;

  final ComplaintStatus improvementStatus;

  /// 완료를 올린 사람 — 승인되면 이 사람에게 점수가 간다 (대기 중에만 채워진다)
  final String? doneRequestedById;
  final DateTime? resolvedAt;
  final String? resolvedById;

  /// 컴플레인으로 셀 건인가
  bool get isComplaint => (improvement ?? '').trim().isNotEmpty;
}

/// `/kindness-surveys` — 회원 친절도 설문
class KindnessApi {
  KindnessApi._();

  static final _client = ApiClient.instance;

  /// 들어온 설문 (최신순)
  ///
  /// [praisedEmployeeId] 를 주면 그 사람이 칭찬받은 것만. 안 주면 지점 전체
  /// (MASTER·ADMIN 은 전 지점).
  static Future<List<KindnessSurvey>> list({
    String? praisedEmployeeId,
    String? branchId,
  }) async {
    final rows = await _client.getList(
      '/kindness-surveys',
      query: {
        'praisedEmployeeId': ?praisedEmployeeId,
        // 안 주면 볼 수 있는 만큼 다 온다 — MEMBER·MANAGER 는 서버가 본인 지점으로 고정
        'branchId': ?branchId,
      },
    );
    return [
      for (final row in rows)
        KindnessSurvey.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 컴플레인 처리 단계 바꾸기
  ///
  /// 개선 의견이 없는 설문에 부르면 400 `NOT_A_COMPLAINT` 다.
  static Future<KindnessSurvey> setStatus(
    String id,
    ComplaintStatus status,
  ) async {
    final data = await _client.patch(
      '/kindness-surveys/$id/status',
      body: {'status': status.wire},
    );
    return KindnessSurvey.fromJson(data!);
  }

  /// 해결 완료 승인 — **MASTER 만.** 점수는 올린 사람에게 간다
  static Future<KindnessSurvey> approve(String id) async {
    final data = await _client.post('/kindness-surveys/$id/approve');
    return KindnessSurvey.fromJson(data!);
  }

  /// 해결 완료 반려 — **해결중으로 되돌린다** (미처리로 내리지 않는다)
  static Future<void> reject(String id, {String? reason}) =>
      _client.post('/kindness-surveys/$id/reject', query: {'reason': ?reason});

  /// 컴플레인 지우기 — **MASTER 만.** 개선 의견만 지우고 칭찬은 남긴다
  static Future<void> removeComplaint(String id) =>
      _client.delete('/kindness-surveys/$id/complaint');
}
