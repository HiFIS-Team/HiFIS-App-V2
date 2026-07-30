import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 세션 (목업)
///
/// 서버가 붙기 전이라 자격 증명은 확인하지 않고, 로그인 여부·자동 로그인
/// 설정·마지막 이메일만 기기에 남긴다. 실제 연동 때는 [signIn]에서 받은
/// 토큰을 저장하고 [restore]에서 그 토큰이 살아 있는지 확인하면 된다.
///
/// 값(true/false)은 로그인 상태다. 최상위 게이트가 이 값을 듣고 있다가
/// 로그인 화면과 메인 화면을 바꿔 끼운다.
class AuthSession extends ValueNotifier<bool> {
  AuthSession._() : super(false);

  static final AuthSession instance = AuthSession._();

  static const _keySignedIn = 'auth.signed_in';
  static const _keyAutoLogin = 'auth.auto_login';
  static const _keyEmail = 'auth.email';

  /// 마지막으로 로그인한 이메일 — 다음 로그인 때 미리 채워 준다
  String? email;

  /// 자동 로그인 체크 상태
  bool autoLogin = true;

  /// 앱 시작 시 저장된 상태를 읽어 온다
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    autoLogin = prefs.getBool(_keyAutoLogin) ?? true;
    email = prefs.getString(_keyEmail);
    value = prefs.getBool(_keySignedIn) ?? false;
  }

  /// 로그인 — 자동 로그인을 껐으면 로그인 상태를 기기에 남기지 않는다
  /// (앱을 껐다 켜면 다시 로그인 화면부터)
  Future<void> signIn({required String email, required bool autoLogin}) async {
    this.email = email;
    this.autoLogin = autoLogin;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyAutoLogin, autoLogin);
    await prefs.setBool(_keySignedIn, autoLogin);

    value = true;
  }

  /// 로그아웃 — 이메일은 남겨 두고 로그인 상태만 지운다
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySignedIn, false);

    value = false;
  }
}
