import '../data/employee.dart';
import 'api_client.dart';

/// 로그인 응답 — 토큰 두 장과 내 정보
class LoginResult {
  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.employee,
  });

  final String accessToken;
  final String refreshToken;
  final Employee employee;
}

/// `/auth/*` 엔드포인트
class AuthApi {
  AuthApi._();

  static final _client = ApiClient.instance;

  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return LoginResult(
      accessToken: data!['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      employee: Employee.fromJson(
        (data['employee'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  /// 회원가입 — 유효한 초대키가 있어야 한다 (없으면 서버가 400)
  static Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String inviteKey,
  }) => _client.post(
    '/auth/signup',
    body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'inviteKey': inviteKey,
    },
  );

  static Future<Employee> me() async =>
      Employee.fromJson(await _client.get('/auth/me'));

  static Future<void> logout() => _client.post('/auth/logout');

  // --- 비밀번호 재설정 (비로그인) ---

  /// 1단계 — 인증번호 발송.
  /// 서버는 계정이 없어도 성공으로 답한다(사용자 열거 방지).
  static Future<void> requestPasswordReset({
    required bool byEmail,
    required String contact,
  }) => _client.post(
    '/auth/password-reset/request',
    body: {'method': byEmail ? 'EMAIL' : 'PHONE', 'contact': contact},
  );

  /// 2단계 — 인증번호 확인. 3단계에서 쓸 재설정 토큰을 돌려준다.
  static Future<String> verifyPasswordReset({
    required String contact,
    required String code,
  }) async {
    final data = await _client.post(
      '/auth/password-reset/verify',
      body: {'contact': contact, 'code': code},
    );
    return data!['resetToken'] as String;
  }

  /// 3단계 — 새 비밀번호 저장. 기존 세션은 서버에서 전부 무효화된다.
  static Future<void> confirmPasswordReset({
    required String resetToken,
    required String password,
  }) => _client.post(
    '/auth/password-reset/confirm',
    body: {'resetToken': resetToken, 'password': password},
  );
}
