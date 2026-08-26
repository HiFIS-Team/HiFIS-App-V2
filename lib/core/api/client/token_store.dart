import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// access·refresh 토큰 보관소
///
/// 자동 로그인을 껐으면 기기에 남기지 않고 메모리에만 둔다
/// (앱을 껐다 켜면 다시 로그인 화면부터).
///
/// **저장 위치는 OS 보안 저장소다** (iOS·macOS 키체인 / 안드로이드 Keystore 기반
/// EncryptedSharedPreferences / 윈도우 DPAPI). 예전엔 `SharedPreferences` 평문
/// 이었는데, 그건 안드로이드에서 앱 폴더의 XML 파일 하나이고 기기 백업에도
/// 그대로 실린다 — refresh 토큰은 14일짜리라 한 번 새면 그동안 계정이 열린다.
class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  static const _keyAccess = 'auth.access_token';
  static const _keyRefresh = 'auth.refresh_token';

  /// `first_unlock_this_device` — 잠금 해제 뒤부터 읽히고, **이 기기 밖으로는
  /// 안 나간다.** `_this_device` 를 빼면 아이클라우드 백업을 새 폰에 복원할 때
  /// 남의 세션 토큰이 같이 따라간다.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? accessToken;
  String? refreshToken;

  /// 기기에 남길지 여부 — 자동 로그인 설정을 따른다
  bool persist = true;

  Future<void> restore() async {
    accessToken = await _read(_keyAccess);
    refreshToken = await _read(_keyRefresh);
    if (accessToken == null && refreshToken == null) {
      await _migrateFromPrefs();
    }
  }

  Future<void> save({
    required String access,
    required String refresh,
    required bool persist,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    this.persist = persist;

    if (!persist) {
      await _delete(_keyAccess);
      await _delete(_keyRefresh);
      return;
    }
    await _write(_keyAccess, access);
    await _write(_keyRefresh, refresh);
  }

  /// 재발급받은 access 토큰만 갈아 끼운다
  Future<void> setAccessToken(String access) async {
    accessToken = access;
    if (!persist) return;
    await _write(_keyAccess, access);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await _delete(_keyAccess);
    await _delete(_keyRefresh);
  }

  /// 평문으로 저장돼 있던 예전 토큰을 보안 저장소로 옮긴다
  ///
  /// 이게 없으면 이미 쓰던 사람 전원이 업데이트 직후 로그아웃된다.
  /// 옮긴 뒤 평문은 지운다 — 남겨 두면 옮긴 의미가 없다.
  Future<void> _migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_keyAccess);
    final refresh = prefs.getString(_keyRefresh);
    if (access == null && refresh == null) return;
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);

    accessToken = access;
    refreshToken = refresh;
    if (access != null) await _write(_keyAccess, access);
    if (refresh != null) await _write(_keyRefresh, refresh);
  }

  /// 보안 저장소는 기기 상태에 따라 실패할 수 있다 — 그때는 로그인 화면으로
  /// 떨어지면 될 뿐, 앱이 켜지지도 않으면 안 된다
  static Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<void> _delete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }
}
