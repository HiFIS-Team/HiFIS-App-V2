import '../client/api_client.dart';

export '../client/period.dart' show periodKey;

/// 등록 종류 — 서버 `RegistrationType`
enum RegistrationType {
  newMember('NEW', '신규'),
  renewal('RENEWAL', '재등록');

  const RegistrationType(this.wire, this.label);

  final String wire;
  final String label;

  static RegistrationType parse(String? value) =>
      RegistrationType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => RegistrationType.newMember,
      );
}

/// 등록권 상태 — 서버 `RegistrationStatus`
///
/// 회차를 다 쓰면 서버가 알아서 `EXPIRED` 로 바꾼다.
enum RegistrationStatus {
  active('ACTIVE'),
  expired('EXPIRED');

  const RegistrationStatus(this.wire);

  final String wire;

  static RegistrationStatus parse(String? value) =>
      RegistrationStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => RegistrationStatus.active,
      );
}

/// 회원이 어떻게 알고 왔나 — 서버 `VisitPath`
///
/// **뒤 셋만 담당 트레이너에게 5점이 붙는다.** 워크인·지인소개는 직원이
/// 끌어온 것이 아니라서 뺀다 (점수는 서버가 등록할 때 한 번 매긴다).
enum VisitPath {
  walkIn('WALK_IN', '워크인'),
  referral('REFERRAL', '지인소개'),
  blog('BLOG', '블로그'),
  instagram('INSTAGRAM', '인스타'),
  otToPt('OT_TO_PT', 'OT → PT');

  const VisitPath(this.wire, this.label);

  final String wire;
  final String label;

  /// 모르는 값·빈 값은 **null** — 이 칸이 생기기 전 회원이 그렇다.
  /// 아무 값으로나 떨어뜨리면 안 물어본 경로가 사실처럼 남는다.
  static VisitPath? parse(String? value) {
    if (value == null) return null;
    for (final path in VisitPath.values) {
      if (path.wire == value) return path;
    }
    return null;
  }
}

/// 센터 회원 (서버 `MemberOut`)
class Member {
  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.branchId,
    required this.ownerTrainerId,
    required this.registeredAt,
    this.referrerMemberId,
    this.visitPath,
    this.memo,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    branchId: json['branchId'] as String,
    ownerTrainerId: json['ownerTrainerId'] as String,
    registeredAt: DateTime.parse(json['registeredAt'] as String).toLocal(),
    referrerMemberId: json['referrerMemberId'] as String?,
    visitPath: VisitPath.parse(json['visitPath'] as String?),
    memo: json['memo'] as String?,
  );

  final String id;
  final String name;
  final String phone;
  final String branchId;

  /// 담당 트레이너 — 매출이 이 사람에게 붙는다
  final String ownerTrainerId;

  /// 소개한 회원 — 이름이 아니라 회원 id 다
  final String? referrerMemberId;

  /// 어떻게 알고 왔나 — **이 칸이 생기기 전에 등록된 회원은 null 이다**
  final VisitPath? visitPath;

  final DateTime registeredAt;
  final String? memo;
}

/// 등록권 한 건 (서버 `RegistrationOut`)
///
/// 회원이 결제한 수업 묶음이다. 재등록하면 새 등록권이 하나 더 생긴다.
class Registration {
  Registration({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.type,
    required this.totalSessions,
    required this.usedSessions,
    required this.pricePaid,
    required this.sessionUnitPrice,
    required this.status,
    required this.purchasedAt,
  });

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
    id: json['id'] as String,
    memberId: json['memberId'] as String,
    trainerId: json['trainerId'] as String,
    type: RegistrationType.parse(json['type'] as String?),
    totalSessions: json['totalSessions'] as int,
    usedSessions: json['usedSessions'] as int,
    pricePaid: json['pricePaid'] as int,
    sessionUnitPrice: json['sessionUnitPrice'] as int,
    status: RegistrationStatus.parse(json['status'] as String?),
    purchasedAt: DateTime.parse(json['purchasedAt'] as String).toLocal(),
  );

  final String id;
  final String memberId;
  final String trainerId;
  final RegistrationType type;

  /// 등록한 총 회차
  final int totalSessions;

  /// 싸인으로 소진된 회차
  final int usedSessions;

  /// 결제액
  final int pricePaid;

  /// 회당 단가 — 결제액 ÷ 회차
  final int sessionUnitPrice;

  final RegistrationStatus status;
  final DateTime purchasedAt;

  int get remaining => totalSessions - usedSessions;

  bool get exhausted => status == RegistrationStatus.expired || remaining <= 0;
}

/// 세션 싸인 한 건 (서버 `SessionSignOut`)
///
/// 기록 한 줄에 필요한 회원 이름·총 회차·등록 종류를 서버가 조인해 준다.
/// 지난 달 기록을 볼 때도 이것만으로 그릴 수 있다.
class SessionSign {
  SessionSign({
    required this.id,
    required this.registrationId,
    required this.memberId,
    required this.performedByTrainerId,
    required this.sessionNo,
    required this.signatureUrl,
    required this.signedAt,
    this.memberName,
    this.totalSessions,
    this.registrationType,
  });

  factory SessionSign.fromJson(Map<String, dynamic> json) => SessionSign(
    id: json['id'] as String,
    registrationId: json['registrationId'] as String,
    memberId: json['memberId'] as String,
    performedByTrainerId: json['performedByTrainerId'] as String,
    sessionNo: json['sessionNo'] as int,
    signatureUrl: json['signatureUrl'] as String,
    signedAt: DateTime.parse(json['signedAt'] as String).toLocal(),
    memberName: json['memberName'] as String?,
    totalSessions: json['totalSessions'] as int?,
    registrationType: json['registrationType'] == null
        ? null
        : RegistrationType.parse(json['registrationType'] as String),
  );

  final String id;
  final String registrationId;
  final String memberId;

  /// 수업을 한 트레이너
  final String performedByTrainerId;

  /// 몇 회차인지 (1부터)
  final int sessionNo;

  /// 서버가 조인해 준 표시용 값 — 예전 기록이면 비어 있을 수 있다
  final String? memberName;
  final int? totalSessions;
  final RegistrationType? registrationType;

  /// 서명 이미지 — `/files/...?exp=&sig=` 꼴의 상대 경로
  ///
  /// 서명(HMAC)이 곧 인증이라 헤더 없이 `<img>` 로 바로 뜬다.
  /// 대신 **7일이 지나면 403** 이라, 목록을 다시 받아 새 URL을 얻어야 한다.
  final String signatureUrl;

  final DateTime signedAt;

  /// 화면에 띄울 전체 주소
  String get signatureFullUrl => fileUrl(signatureUrl);
}

/// 싸인 저장 결과 — 갱신된 등록권이 같이 온다 (usedSessions 가 올라간 상태)
class SessionSignResult {
  SessionSignResult({required this.sign, required this.registration});

  factory SessionSignResult.fromJson(Map<String, dynamic> json) =>
      SessionSignResult(
        sign: SessionSign.fromJson(
          (json['sign'] as Map).cast<String, dynamic>(),
        ),
        registration: Registration.fromJson(
          (json['registration'] as Map).cast<String, dynamic>(),
        ),
      );

  final SessionSign sign;
  final Registration registration;
}

/// 회원 등록 결과 — 등록권을 같이 만들었으면 실려 온다
class MemberCreated {
  MemberCreated({required this.member, required this.registration});

  factory MemberCreated.fromJson(Map<String, dynamic> json) => MemberCreated(
    member: Member.fromJson(json),
    registration: json['registration'] == null
        ? null
        : Registration.fromJson(
            (json['registration'] as Map).cast<String, dynamic>(),
          ),
  );

  final Member member;
  final Registration? registration;
}

/// `/members` — 센터 회원
///
/// 목록은 지점 스코프다. 점장·직원은 본인 지점만, 대표·관리자는 전 지점.
class MemberApi {
  MemberApi._();

  static Future<List<Member>> list({
    String? branchId,
    String? ownerTrainerId,
    String? query,
  }) async {
    final rows = await ApiClient.instance.getList(
      '/members',
      query: {
        'branchId': ?branchId,
        'ownerTrainerId': ?ownerTrainerId,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return [
      for (final row in rows)
        Member.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 회원 등록 — [totalSessions] 를 주면 첫 등록권까지 **한 트랜잭션**으로 만든다
  ///
  /// 둘로 나눠 부르면 회원만 만들어지고 등록권에서 실패했을 때
  /// 등록권 없는 회원이 남는다. 실무에 그런 회원은 없다.
  static Future<MemberCreated> create({
    required String name,
    required String phone,
    required String branchId,
    required String ownerTrainerId,
    String? referrerMemberId,
    VisitPath? visitPath,
    String? memo,
    RegistrationType? type,
    int? totalSessions,
    int? pricePaid,
    int? sessionUnitPrice,
  }) async {
    final data = await ApiClient.instance.post(
      '/members',
      body: {
        'name': name,
        'phone': phone,
        'branchId': branchId,
        'ownerTrainerId': ownerTrainerId,
        'referrerMemberId': ?referrerMemberId,
        'visitPath': ?visitPath?.wire,
        'memo': ?memo,
        if (totalSessions != null)
          'registration': {
            'type': (type ?? RegistrationType.newMember).wire,
            'totalSessions': totalSessions,
            'pricePaid': pricePaid ?? 0,
            'sessionUnitPrice': sessionUnitPrice ?? 0,
          },
      },
    );
    return MemberCreated.fromJson(data!);
  }
}

/// `/registrations` — 등록권 (급여 인센티브 산출의 입력값)
class RegistrationApi {
  RegistrationApi._();

  static Future<List<Registration>> list({
    String? trainerId,
    RegistrationType? type,
    String? period,
  }) async {
    final rows = await ApiClient.instance.getList(
      '/registrations',
      query: {'trainerId': ?trainerId, 'type': ?type?.wire, 'period': ?period},
    );
    return [
      for (final row in rows)
        Registration.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 등록권 발급 — 직원은 본인 담당(`trainerId` = 본인)만 만들 수 있다
  static Future<Registration> create({
    required String memberId,
    required String trainerId,
    required RegistrationType type,
    required int totalSessions,
    required int pricePaid,
    required int sessionUnitPrice,
  }) async {
    final data = await ApiClient.instance.post(
      '/registrations',
      body: {
        'memberId': memberId,
        'trainerId': trainerId,
        'type': type.wire,
        'totalSessions': totalSessions,
        'pricePaid': pricePaid,
        'sessionUnitPrice': sessionUnitPrice,
      },
    );
    return Registration.fromJson(data!);
  }
}

/// `/session-signs` — 세션 싸인
class SessionSignApi {
  SessionSignApi._();

  static Future<List<SessionSign>> list({
    String? trainerId,
    String? memberId,
    String? period,
    String? branchId,
  }) async {
    final rows = await ApiClient.instance.getList(
      '/session-signs',
      query: {
        'trainerId': ?trainerId,
        'memberId': ?memberId,
        'period': ?period,
        // 안 주면 볼 수 있는 만큼 다 온다 — MEMBER·MANAGER 는 서버가 본인 지점으로 고정
        'branchId': ?branchId,
      },
    );
    return [
      for (final row in rows)
        SessionSign.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 싸인 저장 — 회차가 1 올라가고 수업왕 점수가 2점 쌓인다
  ///
  /// [signatureBase64] 는 PNG 를 base64 로 만든 것. 서버가 파일로 떨군다.
  /// [performedByTrainerId] 를 안 주면 요청한 사람이 수행자가 된다 (대타는 지정).
  static Future<SessionSignResult> create({
    required String registrationId,
    required String signatureBase64,
    String? performedByTrainerId,
  }) async {
    final data = await ApiClient.instance.post(
      '/session-signs',
      body: {
        'registrationId': registrationId,
        'signatureBase64': signatureBase64,
        'performedByTrainerId': ?performedByTrainerId,
      },
    );
    return SessionSignResult.fromJson(data!);
  }
}
