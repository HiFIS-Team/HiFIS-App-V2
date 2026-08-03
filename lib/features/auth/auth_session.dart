import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/chat_socket.dart';
import '../../core/api/token_store.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff_directory.dart';
import '../messages/chat_store.dart';

/// 로그인 세션
///
/// 값(true/false)은 로그인 상태다. 최상위 게이트가 이 값을 듣고 있다가
/// 로그인 화면과 메인 화면을 바꿔 끼운다.
///
/// 토큰 자체는 [TokenStore]가 들고 있고, 여기서는 "로그인했는가"와
/// "누가 로그인했는가"만 다룬다.
class AuthSession extends ValueNotifier<bool> {
  AuthSession._() : super(false);

  static final AuthSession instance = AuthSession._();

  static const _keyAutoLogin = 'auth.auto_login';
  static const _keyEmail = 'auth.email';

  /// 마지막으로 로그인한 이메일 — 다음 로그인 때 미리 채워 준다
  String? email;

  /// 자동 로그인 체크 상태
  bool autoLogin = true;

  /// 로그인한 직원 — 로그아웃 상태면 null
  Employee? me;

  /// 앱 시작 시 저장된 토큰으로 세션을 되살린다
  ///
  /// 토큰이 살아 있는지는 서버에 물어봐야 안다. 만료됐으면 클라이언트가
  /// refresh 로 한 번 되살려 보고, 그것도 안 되면 로그인 화면부터 시작한다.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    autoLogin = prefs.getBool(_keyAutoLogin) ?? true;
    email = prefs.getString(_keyEmail);

    // 토큰이 만료돼 되살리기까지 실패하면 로그인 화면으로 되돌린다
    ApiClient.instance.onSessionExpired = () {
      if (value) signOut();
    };

    await TokenStore.instance.restore();
    if (TokenStore.instance.accessToken == null) return;

    try {
      me = await AuthApi.me();
      currentUser = me;
      email = me!.email;
      await StaffDirectory.instance.load();
      // 사내톡은 화면을 열 때가 아니라 로그인해 있는 동안 늘 붙어 있다 —
      // 목록 화면에서 안 연 방의 새 메시지도 받아야 한다.
      // **기다리지 않는다** — WebSocket 연결은 서버가 안 받으면 OS 타임아웃까지
      // 수십 초를 끌 수 있어서, await 하면 그동안 앱이 로그인 화면에서 멈춘다.
      unawaited(ChatSocket.instance.connect());
      value = true;
    } catch (_) {
      // 서버가 꺼져 있거나 토큰이 죽었다 — 조용히 로그인 화면부터 시작한다
      await TokenStore.instance.clear();
    }
  }

  /// 로그인 — 실패하면 예외가 그대로 올라간다 (화면이 메시지를 보여준다)
  ///
  /// 자동 로그인을 껐으면 토큰을 기기에 남기지 않는다
  /// (앱을 껐다 켜면 다시 로그인 화면부터).
  Future<void> signIn({
    required String email,
    required String password,
    required bool autoLogin,
  }) async {
    final result = await AuthApi.login(email: email, password: password);

    await TokenStore.instance.save(
      access: result.accessToken,
      refresh: result.refreshToken,
      persist: autoLogin,
    );

    this.email = email;
    this.autoLogin = autoLogin;
    me = result.employee;
    currentUser = me;
    await StaffDirectory.instance.load();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyAutoLogin, autoLogin);

    // 소켓은 기다리지 않는다 (restore 와 같은 이유) — 붙는 동안에도 메시지
    // 전송은 REST 로 나가므로 대화가 막히지 않는다
    unawaited(ChatSocket.instance.connect());

    value = true;
  }

  /// 로그아웃 — 이메일은 남겨 두고 토큰만 지운다
  ///
  /// 서버에도 알려 이 계정의 기존 토큰을 전부 무효화한다. 서버가 응답하지
  /// 않아도 기기에서는 반드시 로그아웃되어야 하므로 실패는 무시한다.
  Future<void> signOut() async {
    try {
      await AuthApi.logout();
    } catch (_) {
      // 네트워크가 없어도 로그아웃은 진행한다
    }
    await ChatSocket.instance.disconnect();
    await TokenStore.instance.clear();
    me = null;
    currentUser = null;
    StaffDirectory.instance.clear();
    // 다음 사람에게 앞사람 대화가 보이면 안 된다
    ChatStore.instance.clear();
    value = false;
  }
}
