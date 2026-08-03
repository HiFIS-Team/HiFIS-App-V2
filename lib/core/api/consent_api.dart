import 'api_client.dart';

/// 직원 동의 한 건 (서버 `EmployeeConsentOut`)
class EmployeeConsent {
  EmployeeConsent({
    required this.id,
    required this.employeeId,
    required this.docType,
    required this.docVersion,
    required this.agreedAt,
  });

  factory EmployeeConsent.fromJson(Map<String, dynamic> json) =>
      EmployeeConsent(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        docType: json['docType'] as String,
        docVersion: json['docVersion'] as String,
        agreedAt: DateTime.parse(json['agreedAt'] as String).toLocal(),
      );

  final String id;
  final String employeeId;

  /// `TERMS` · `PRIVACY`
  final String docType;

  /// 동의한 **문서 버전**. 약관이 개정되면 재동의를 받아야 해서 필요하다
  final String docVersion;

  final DateTime agreedAt;
}

/// `/employees/me/consents` — 약관·개인정보처리방침 동의 이력
///
/// 동의는 **가입 폼이 아니라 별도 엔드포인트**로 남긴다. 가입 시점에는 아직
/// 토큰이 없어서, 가입 → 로그인 → 동의 순으로 부른다.
///
/// 법령상 입증 책임이 회사에 있어서, 동의를 받았다는 기록이 없으면 받은 게 아니다.
class ConsentApi {
  ConsentApi._();

  static final _client = ApiClient.instance;

  /// 동의 남기기
  static Future<void> agree({
    required String docType,
    required String docVersion,
  }) => _client.post(
    '/employees/me/consents',
    body: {'docType': docType, 'docVersion': docVersion},
  );

  /// 내 동의 이력 — 개정 뒤 재동의가 필요한지 볼 때 쓴다
  static Future<List<EmployeeConsent>> mine() async {
    final rows = await _client.getList('/employees/me/consents');
    return [
      for (final row in rows)
        EmployeeConsent.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
