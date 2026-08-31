import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/auth/auth_api.dart';
import '../../core/api/chat/chat_socket.dart';
import '../../core/api/client/api_client.dart';
import '../../core/api/client/api_exception.dart';
import '../../core/api/client/token_store.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/header_action.dart';
import '../work/my_task/my_task_section.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff_directory.dart';
import '../../core/util/app_trail.dart';
import '../../core/util/capture_guard.dart';
import '../../core/util/push.dart';
import '../messages/chat_store.dart';
import '../../core/util/photo_cache.dart';
import '../project/project_screen.dart'
    show resetProjectCache, resetProjectDueModal;
import '../work/peer_review/peer_review_modal.dart' show resetPeerReviewModal;
import '../notice/notice_screen.dart' show resetNoticeCache;
import '../meeting/meeting_screen.dart' show resetMeetingCache;
import '../schedule/schedule_screen.dart' show resetScheduleScope;
import '../staff/staff_screen.dart' show resetStaffCache;
import '../approval/approval_screen.dart' show resetApprovalCache;

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
      // 권한을 알게 됐으니 캡처 방지를 그 사람 기준으로 맞춘다
      unawaited(CaptureGuard.apply());
      // 이 기기로 푸시를 받겠다고 서버에 알린다 — 켤 때마다 불러도 된다
      unawaited(PushGuard.register());
      await StaffDirectory.instance.load();
      // 사내톡은 화면을 열 때가 아니라 로그인해 있는 동안 늘 붙어 있다 —
      // 목록 화면에서 안 연 방의 새 메시지도 받아야 한다.
      // **기다리지 않는다** — WebSocket 연결은 서버가 안 받으면 OS 타임아웃까지
      // 수십 초를 끌 수 있어서, await 하면 그동안 앱이 로그인 화면에서 멈춘다.
      unawaited(ChatSocket.instance.connect());
      // 방 목록도 미리 받아 둔다 — 사내톡을 한 번도 안 열면 안 읽음 배지가
      // 안 뜬다 (헤더 메시지 버튼·우하단 필의 빨간 점이 이 값을 본다)
      unawaited(ChatStore.instance.loadRooms().catchError((_) {}));
      value = true;
    } catch (error) {
      // **토큰이 죽은 것과 서버에 못 닿은 것은 다르다.**
      // 예전엔 둘 다 토큰을 지웠다 — 지하 주차장에서 앱을 한 번 켜면 그것만으로
      // 로그아웃돼서, 와이파이가 잡힌 뒤 다시 비밀번호를 쳐야 했다.
      // 인증이 실제로 거절당했을 때만 지우고, 통신 실패면 토큰을 남긴 채
      // 이번 실행만 로그인 화면에서 시작한다(다음에 켜면 그대로 들어간다).
      if (_isAuthFailure(error)) await TokenStore.instance.clear();
    }
  }

  /// 서버가 "이 토큰 못 쓴다"고 답한 경우인가 (통신 실패와 구분)
  static bool _isAuthFailure(Object error) {
    final api = error is ApiException
        ? error
        : (error is DioException && error.error is ApiException)
        ? error.error as ApiException
        : null;
    if (api == null) return false;
    return api.status == 401 ||
        api.status == 403 ||
        api.code == 'TOKEN_REVOKED' ||
        api.code == 'INVALID_TOKEN';
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
    unawaited(CaptureGuard.apply());
    unawaited(PushGuard.register());
    await StaffDirectory.instance.load();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyAutoLogin, autoLogin);

    // 소켓은 기다리지 않는다 (restore 와 같은 이유) — 붙는 동안에도 메시지
    // 전송은 REST 로 나가므로 대화가 막히지 않는다
    unawaited(ChatSocket.instance.connect());
    unawaited(ChatStore.instance.loadRooms().catchError((_) {}));

    value = true;
  }

  /// 로그아웃 — 이메일은 남겨 두고 토큰만 지운다
  ///
  /// 서버에도 알려 이 계정의 기존 토큰을 전부 무효화한다. 서버가 응답하지
  /// 않아도 기기에서는 반드시 로그아웃되어야 하므로 실패는 무시한다.
  Future<void> signOut() async {
    // **토큰을 지우기 전에** 부른다 — 이 요청도 로그인 상태여야 나간다.
    // 안 지우면 이 기기로 앞사람 알림이 계속 간다.
    await PushGuard.unregister();
    // 쌓아 둔 앱 사용 기록도 여기서 올리고 비운다 — **같은 이유다.**
    // 아래에서 부르면 토큰이 이미 없어서 못 보내고 그대로 버려진다
    await AppTrail.reset();
    try {
      await AuthApi.logout();
    } catch (_) {
      // 네트워크가 없어도 로그아웃은 진행한다
    }
    await ChatSocket.instance.disconnect();
    await TokenStore.instance.clear();
    me = null;
    currentUser = null;
    // 로그아웃하면 다시 켠다 — 다음에 로그인하는 사람이 대표가 아닐 수 있다
    unawaited(CaptureGuard.apply());
    StaffDirectory.instance.clear();
    // 다음 사람에게 앞사람 대화가 보이면 안 된다
    ChatStore.instance.clear();
    // 받아 둔 사진 파일도 지운다 — 다음 사람에게 남의 사진이 남으면 안 된다
    PhotoCache.clear();
    // 다음 사람이 켜면 마감 모달을 다시 판단해야 한다
    resetProjectDueModal();
    resetPeerReviewModal();
    // 앞사람이 보던 지점이 다음 사람 화면에 걸려 있으면 안 된다
    resetBranchScope();
    resetHeaderAction();
    resetMyTaskCache();
    // 화면들이 들고 있는 목록도 비운다 — **다음 사람에게 앞사람 것이 보이면 안 된다.**
    // 탭을 다시 열 때 안 깜빡이려고 모듈 전역에 남겨 두는 것들이라
    // 여기서 안 비우면 로그아웃해도 살아남는다
    resetNoticeCache();
    resetProjectCache();
    resetMeetingCache();
    resetStaffCache();
    resetApprovalCache();
    // 일정은 갈래(공통·개인)와 보던 사람까지 되돌린다 — 안 그러면 다음 사람이
    // 앞사람의 개인 일정 칸에서 시작한다
    resetScheduleScope();
    value = false;
  }
}
