import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/util/sf_symbols.dart';
import 'package:hifis_app/core/widgets/glass/glass_surface.dart';

/// iOS 18~25 는 **안드로이드와 같은 화면**으로 간다 (2026-10-27 대표 요청)
///
/// 리퀴드 글래스가 없는 iOS 에서 네이티브 버튼·탭바가 예전 납작한 모양으로
/// 떴다. 판정은 네이티브(`com.hifis/os`)가 하고, 못 물어보면 예전처럼 애플
/// 화면에 둔다 — iOS 26 사용자가 잘못 안드로이드 화면을 보면 안 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hifis/os');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> detectWith(Object? answer) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'liquidGlass');
      if (answer is Exception) throw answer;
      return answer;
    });
    await detectLiquidGlass();
  }

  test('iOS 26 아래면 애플 화면을 안 쓴다 (유리 면도 안 쓴다)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await detectWith(false);
    expect(isApple, isFalse);
    expect(isApplePlatform, isTrue, reason: '글꼴·창 외관은 그대로 애플이다');
    expect(GlassSurface.supported, isFalse);
  });

  test('iOS 26 이상이면 애플 화면 그대로다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await detectWith(true);
    expect(isApple, isTrue);
    expect(GlassSurface.supported, isTrue);
  });

  test('못 물어보면 예전처럼 애플 화면이다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await detectWith(false); // 앞 상태를 일부러 false 로 둔다
    await detectWith(PlatformException(code: 'x'));
    // 실패하면 값을 안 건드린다 — 앞에서 false 였으면 false 다.
    // 실제 앱은 시작할 때 한 번만 부르므로 기본값(true)에서 시작한다
    expect(isApple, isFalse);
  });

  test('안드로이드는 묻지도 않는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var asked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked = true;
      return true;
    });
    await detectLiquidGlass();
    expect(asked, isFalse);
    expect(isApple, isFalse);
  });

  test('맥은 버전과 상관없이 애플 화면이다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await detectWith(true);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(isApple, isTrue);
  });
}
