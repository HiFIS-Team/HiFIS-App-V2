import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/monitoring_api.dart';
import '../data/current_user.dart';
import '../data/employee.dart';
import '../data/staff.dart';
import 'platform.dart';

/// 화면 캡처 방지 — **MASTER 밑으로는 못 찍게 막는다**
///
/// 직원이 다른 센터로 옮겨 가면서 화면(디자인·기능)을 들고 나가는 것을 막으려는
/// 장치다. 대표는 예외라 아무 제약 없이 찍는다.
///
/// **플랫폼마다 되는 정도가 다르다.** 세 곳은 OS 가 실제로 막아 주는데
/// iOS 만 못 막는다 — 애플이 스크린샷을 차단하는 API 를 안 준다.
///
/// | | 스크린샷 | 녹화·미러링 |
/// |---|---|---|
/// | 안드로이드 | 막힘 (`FLAG_SECURE`) | 검은 화면 |
/// | macOS | 막힘 (`sharingType = .none`) | 막힘 |
/// | 윈도우 | 막힘 (`WDA_EXCLUDEFROMCAPTURE`) | 막힘 |
/// | **iOS** | **못 막음 — 찍힌 뒤 알기만 한다** | 도는 중인지는 안다 |
///
/// 그래서 iOS 는 **막는 대신 남긴다** — 찍을 때마다 서버에 알리고, 짧은 시간에
/// 여러 장 찍으면 이상 징후로 올라가 대표에게 푸시가 간다. 기록이 남는다는
/// 것을 아는 게 실질적인 억제다.
///
/// > 넷 다 **다른 폰으로 화면을 찍는 것은 못 막는다.** 문턱을 높이고 기록을
/// > 남기는 장치이지 새는 것을 봉하는 장치가 아니다.
class CaptureGuard {
  CaptureGuard._();

  static const _channel = MethodChannel('com.hifis/capture');

  /// 이 플랫폼이 **실제로** 막아 주는가 — iOS 는 false
  static bool blocks = false;

  /// 화면 녹화·미러링이 도는 중 (iOS 만 채운다)
  ///
  /// 켜지면 [HiFISApp] 이 프라이버시 커버로 덮는다 — 앱 전환 때 덮는 것과
  /// 같은 가림막이라 새로 그리는 것이 없다.
  static final recording = ValueNotifier<bool>(false);

  static bool _wired = false;

  /// 지금 켜져 있어야 하는가 — 로그인 전(=권한 모름)에도 켠다
  static bool get _wanted => myRole != Role.master;

  /// 로그인한 사람 기준으로 켜고 끈다.
  ///
  /// 로그인·세션 복원·로그아웃·권한 변경 때 부른다. 서버·네이티브 어느 쪽이
  /// 실패해도 앱은 그대로 돌아가야 하므로 예외를 삼킨다.
  static Future<void> apply() async {
    _wire();
    try {
      final blocked = await _channel.invokeMethod<bool>('setSecure', _wanted);
      blocks = blocked ?? false;
    } on MissingPluginException {
      // 아직 네이티브가 안 붙은 플랫폼 — 앱은 그대로 돌아간다
      blocks = false;
    } catch (error) {
      blocks = false;
      debugPrint('캡처 방지 설정 실패: $error');
    }
  }

  /// 네이티브 → Dart 로 오는 것 (iOS 전용). 한 번만 건다.
  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        // 스크린샷이 찍혔다 — 막지 못했으니 남기기라도 한다
        case 'onScreenshot':
          _report('screenshot');
        // 녹화·미러링이 시작·종료됐다
        case 'onCaptureChanged':
          final on = call.arguments as bool? ?? false;
          recording.value = on && _wanted;
          if (on) _report('recording');
      }
      return null;
    });
  }

  /// 서버에 알린다 — 활동 로그에 남고 반복되면 이상 징후가 된다
  ///
  /// **대표는 안 보낸다** (애초에 막지도 않는다). 로그인 전에도 안 보낸다 —
  /// 토큰이 없어 401 이 날 뿐이다.
  static void _report(String kind) {
    if (!_wanted || currentUser == null) return;
    // 기다리지 않는다 — 찍는 순간 화면이 멈추면 안 된다
    MonitoringApi.reportCapture(platform: platformName, kind: kind).catchError((
      error,
    ) {
      debugPrint('캡처 신고 실패: $error');
    });
  }
}
