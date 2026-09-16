import '../client/api_client.dart';

/// 연장 의향 — 서버 `RenewIntent`
enum RenewIntent {
  yes('YES', '연장할래요'),
  maybe('MAYBE', '고민 중이에요'),
  no('NO', '연장 안 해요');

  const RenewIntent(this.wire, this.label);

  final String wire;
  final String label;

  static RenewIntent? parse(String? value) {
    if (value == null) return null;
    for (final v in RenewIntent.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}

/// 회원이 고른 주제 하나 (서버 `PtTopicAnswer`)
///
/// **문구(`label`)를 서버가 붙여서 준다.** 앱이 주제표를 따로 들면
/// 대표가 문구를 고칠 때 스토어를 거쳐야 한다
/// (서버 `app/services/pt_topics.py`).
class PtTopicAnswer {
  const PtTopicAnswer({required this.topic, required this.label, this.note});

  factory PtTopicAnswer.fromJson(Map<String, dynamic> json) => PtTopicAnswer(
    topic: json['topic'] as String,
    label: json['label'] as String? ?? json['topic'] as String,
    note: json['note'] as String?,
  );

  /// 주제 코드 — 세는 자리에서 쓴다 (`DIET` · `POSTURE` …)
  final String topic;

  /// 화면에 뜨는 말 — 좋았던 점이면 칭찬형, 보완할 점이면 요청형이다
  final String label;

  /// 그 주제에 적은 상세 — **비어 있을 수 있다** (고르기만 해도 된다)
  final String? note;
}

/// PT 만족도 폼 한 건 (서버 `PtSurveyOut`)
///
/// 신규 등록권의 **7회차**에 열린다. 회원이 문자로 받은 주소에서 답한다.
class PtSurvey {
  PtSurvey({
    required this.id,
    required this.registrationId,
    required this.memberId,
    required this.trainerId,
    required this.sessionNo,
    required this.url,
    required this.createdAt,
    this.memberName,
    this.trainerName,
    this.pricePaid,
    this.branchName,
    this.sentAt,
    this.answeredAt,
    this.satisfaction,
    this.request,
    this.praise = const [],
    this.improve = const [],
    this.renew,
  });

  factory PtSurvey.fromJson(Map<String, dynamic> json) => PtSurvey(
    id: json['id'] as String,
    registrationId: json['registrationId'] as String,
    memberId: json['memberId'] as String,
    trainerId: json['trainerId'] as String,
    sessionNo: json['sessionNo'] as int,
    url: json['url'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    memberName: json['memberName'] as String?,
    trainerName: json['trainerName'] as String?,
    pricePaid: json['pricePaid'] as int?,
    branchName: json['branchName'] as String?,
    sentAt: _time(json['sentAt']),
    answeredAt: _time(json['answeredAt']),
    satisfaction: json['satisfaction'] as int?,
    request: json['request'] as String?,
    praise: _answers(json['praise']),
    improve: _answers(json['improve']),
    renew: RenewIntent.parse(json['renew'] as String?),
  );

  static List<PtTopicAnswer> _answers(Object? value) => [
    for (final row in (value as List? ?? const []))
      PtTopicAnswer.fromJson(row as Map<String, dynamic>),
  ];

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  final String id;
  final String registrationId;
  final String memberId;
  final String trainerId;

  /// 몇 회차에 열렸나 — 지금은 늘 7이지만 기준이 바뀌면 옛 줄이 뜻을 잃지 않는다
  final int sessionNo;

  /// 회원에게 손으로 넘겨줄 주소 — 문자 발송이 붙기 전까지 쓰는 길이다
  final String url;

  final DateTime createdAt;
  final String? memberName;
  final String? trainerName;

  /// 그 등록권의 결제액(원) — '연장할래요' 로 답한 건을 다음달 예상 매출로
  /// 합산할 때 쓴다
  final int? pricePaid;

  /// 회원 소속 지점 — 지점별 예상 매출을 가르는 자리
  final String? branchName;

  /// 문자를 실제로 보낸 시각 — 발신번호가 정해지기 전에는 비어 있다
  final DateTime? sentAt;

  /// 회원이 답한 시각 — 비어 있으면 아직 안 냈다
  final DateTime? answeredAt;

  /// 만족도 1~5
  final int? satisfaction;

  /// 앞으로 트레이너에게 바라는 점 — **2026-09-16 이전 설문의 서술형 답이다.**
  ///
  /// 그 뒤로는 객관식(`praise`·`improve`)으로 받는다. 옛 답이 22건 있어서
  /// 화면이 둘 다 그릴 줄 알아야 한다.
  final String? request;

  /// 좋았던 점 — 고른 주제들 (새 설문)
  final List<PtTopicAnswer> praise;

  /// 보완할 점 — 주제는 `praise` 와 같은 표에서 나오고 **문구만 요청형**이다
  final List<PtTopicAnswer> improve;

  final RenewIntent? renew;

  /// 적어 낸 글 전부 — 검색이 훑는 자리다 (주제 문구 + 상세)
  String get allText => [
    request ?? '',
    for (final a in [...praise, ...improve]) ...[a.label, a.note ?? ''],
  ].join(' ');

  bool get answered => answeredAt != null;

  /// 화면에 세울 이름 — **빈 글자도 '알 수 없음' 이다**
  ///
  /// 목록이 아바타에 첫 글자를 쓰는데(`name.characters.first`), 빈 글자가
  /// 오면 거기서 죽는다. null 만 막으면 빈 이름이 그대로 새어 나간다.
  String get displayMember => _orUnknown(memberName);
  String get displayTrainer => _orUnknown(trainerName);

  static String _orUnknown(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '알 수 없음' : trimmed;
  }
}

/// `/pt-surveys` — PT 만족도 폼 결과
///
/// **누가 무엇을 받나** (2026-09-09 대표 결정으로 바뀌었다)
///
/// | 누가 | 무엇을 |
/// |---|---|
/// | MASTER · ADMIN | 전부 |
/// | MANAGER · MEMBER | **본인이 수업한 것만** |
///
/// 예전에는 정반대였다 — 트레이너는 403 이었고 누구든 자기가 받은 평가는
/// 안 왔다. 회원에게 "트레이너에게는 전달되지 않아요" 라고 적어 두었기
/// 때문인데, **그 문구를 걷어내면서 같이 풀었다.**
class PtSurveyApi {
  PtSurveyApi._();

  /// 결과 목록 (최신순)
  ///
  /// [unanswered] 를 켜면 아직 안 낸 것만 — 누구에게 다시 물어야 하는지 보는 자리.
  static Future<List<PtSurvey>> list({
    String? trainerId,
    String? branchId,
    bool unanswered = false,
  }) async {
    final rows = await ApiClient.instance.getList(
      '/pt-surveys',
      query: {
        'trainerId': ?trainerId,
        // 안 주면 볼 수 있는 만큼 다 온다 — MANAGER 는 서버가 본인 지점으로 고정
        'branchId': ?branchId,
        if (unanswered) 'unanswered': 'true',
      },
    );
    return [
      for (final row in rows)
        PtSurvey.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
