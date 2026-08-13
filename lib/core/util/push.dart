import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/home/notification_api.dart';
import '../data/current_user.dart';

/// 푸시 알림 — 앱이 꺼져 있어도 폰에 뜨는 그것
///
/// 앱 안 알림함(`/notifications`)과 **다른 길이다.** 저쪽은 앱을 열어야 보이고
/// 이건 잠금화면에 뜬다. 서버는 알림을 만들 때 둘 다 태운다.
///
/// **애플·안드로이드 셋 다 된다.** 윈도우는 없다.
///
/// 보내는 길은 플랫폼마다 다른데(애플은 APNs 직접, 안드로이드는 FCM) **앱은
/// 그 차이를 모른다** — 네이티브 쪽이 같은 채널 규약을 쓰고, 어느 길로 보낼지는
/// 서버가 기기 토큰에 붙은 `platform` 을 보고 정한다.
///
/// 도는 순서
///
/// ```
/// 로그인  →  register()  →  (네이티브) 권한 묻고 토큰 받기
///                        →  onToken  →  POST /push/devices
/// 알림 누름  →  (네이티브) onTap  →  그 화면으로 이동
/// 로그아웃  →  unregister()  →  DELETE /push/devices/{token}
/// ```
class PushGuard {
  PushGuard._();

  static const _channel = MethodChannel('com.hifis/push');

  /// 애플에게 받은 기기 토큰 — 로그아웃할 때 지우려고 들고 있는다
  static String? _token;

  static bool _wired = false;

  /// 알림을 눌렀을 때 갈 곳 (`/projects/{id}` 처럼 서버가 준 앱 안 주소)
  ///
  /// [PushGuard] 가 화면을 모르므로 값만 걸어 두고, 화면 쪽이 듣고 옮긴다.
  /// 앱이 꺼져 있을 때 눌린 것도 여기로 온다 — 네이티브가 담아 뒀다가
  /// [register] 가 준비를 알리는 순간 흘려보낸다.
  static final tappedLink = ValueNotifier<String?>(null);

  /// 로그인한 뒤 부른다 — 권한을 묻고 이 기기를 서버에 등록한다
  ///
  /// **두 번째부터는 조용하다.** 한 번 답한 뒤에는 시스템 창이 다시 안 뜨고
  /// 그때의 답이 그대로 돌아온다. 그래서 켤 때마다 불러도 된다.
  ///
  /// 어디서 실패해도 앱은 그대로 돌아간다 — 푸시가 안 올 뿐이고 앱 안
  /// 알림함은 살아 있다.
  static Future<void> register() async {
    _wire();
    try {
      await _channel.invokeMethod<void>('ready');
      await _channel.invokeMethod<bool>('register');
    } on MissingPluginException {
      // 네이티브가 없는 플랫폼 — 윈도우가 여기로 떨어진다 (푸시가 안 올 뿐이다)
    } catch (error) {
      debugPrint('푸시 등록 요청 실패: $error');
    }
  }

  /// 로그아웃할 때 부른다 — 이 기기로 앞사람 알림이 계속 가면 안 된다
  ///
  /// **토큰을 기억해 둔 채로 지운다.** 다음 사람이 로그인하면 [register] 가
  /// 다시 등록하고, 서버가 그때 주인을 바꾼다.
  static Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await NotificationApi.unregisterDevice(token);
    } catch (error) {
      debugPrint('푸시 해제 실패: $error');
    }
  }

  /// 네이티브 → Dart. 한 번만 건다.
  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          final args = (call.arguments as Map).cast<String, dynamic>();
          await _send(args);
        case 'onTap':
          final link = call.arguments as String?;
          if (link != null && link.isNotEmpty) tappedLink.value = link;
      }
      return null;
    });
  }

  /// 받은 토큰을 서버에 올린다 — 로그인 전이면 아무것도 안 한다
  static Future<void> _send(Map<String, dynamic> args) async {
    final token = args['token'] as String?;
    if (token == null || token.isEmpty) return;
    _token = token;
    // 로그인 전에 토큰이 먼저 올 수 있다 (권한을 이미 준 상태로 앱을 켠 경우).
    // 그때 보내면 401 이라, 들고만 있다가 로그인하면 register() 가 다시 부른다.
    if (currentUser == null) return;
    try {
      await NotificationApi.registerDevice(
        token: token,
        platform: args['platform'] as String? ?? 'IOS',
        sandbox: args['sandbox'] as bool? ?? false,
      );
    } catch (error) {
      debugPrint('기기 토큰 등록 실패: $error');
    }
  }
}
