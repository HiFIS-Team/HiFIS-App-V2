import 'package:shared_preferences/shared_preferences.dart';

/// access·refresh 토큰 보관소
///
/// 자동 로그인을 껐으면 기기에 남기지 않고 메모리에만 둔다
/// (앱을 껐다 켜면 다시 로그인 화면부터).
class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  static const _keyAccess = 'auth.access_token';
  static const _keyRefresh = 'auth.refresh_token';

  String? accessToken;
  String? refreshToken;

  /// 기기에 남길지 여부 — 자동 로그인 설정을 따른다
  bool persist = true;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_keyAccess);
    refreshToken = prefs.getString(_keyRefresh);
  }

  Future<void> save({
    required String access,
    required String refresh,
    required bool persist,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    this.persist = persist;

    final prefs = await SharedPreferences.getInstance();
    if (!persist) {
      await prefs.remove(_keyAccess);
      await prefs.remove(_keyRefresh);
      return;
    }
    await prefs.setString(_keyAccess, access);
    await prefs.setString(_keyRefresh, refresh);
  }

  /// 재발급받은 access 토큰만 갈아 끼운다
  Future<void> setAccessToken(String access) async {
    accessToken = access;
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
  }
}
