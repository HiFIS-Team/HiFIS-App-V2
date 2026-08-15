import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 리퀴드 글래스 **면** — 검색바·입력바·상단 블러가 깔고 앉는 판
///
/// 버튼·탭바·메뉴는 `cupertino_native` 가 진작 네이티브로 그리고 있었는데
/// **면만 Flutter 블러였다.** 재질이 달라서 나란히 두면 티가 났다.
///
/// | | 무엇이 그리나 |
/// |---|---|
/// | iOS 26+ | `UIGlassEffect` — **애플이 그린다** (스위프트 앱과 같은 것) |
/// | iOS 26 아래 | `UIBlurEffect(.systemThinMaterial)` — 예전 재질 |
/// | 그 외 (안드로이드·윈도우·**맥**) | [BackdropFilter] — 지금까지 쓰던 그대로 |
///
/// **맥은 아직 안 붙였다.** macOS 26 에 `NSGlassEffectView` 가 따로 있어서
/// 키 이름부터 다르다 (엔타이틀먼트 때 겪은 것과 같은 사정). iOS 가 도는 걸
/// 보고 붙인다.
///
/// ## 쓰는 법 — 면이지 그릇이 아니다
///
/// 이 위젯은 **자기 뒤를 비추는 배경판**이다. 안에 든 [child] 는 유리 **위**에
/// 그려진다. 유리가 비추는 것은 이 위젯 뒤에 있는 것이라, `Stack` 의 위
/// 레이어로 놓아야 아래 콘텐츠가 비친다.
///
/// ⚠️ **[GlassIconButton] 같은 네이티브 버튼과 같은 `Row` 에 두지 않는다.**
/// 눌러도 `onPressed` 까지 안 오는데 에러도 로그도 안 난다 (CLAUDE.md).
/// `Stack` 의 다른 자식으로 나눈다.
class GlassSurface extends StatelessWidget {
  GlassSurface({
    super.key,
    required this.child,
    this.radius = 0,
    this.tint,
    this.interactive = false,
    this.blurSigma = 28,
    this.fallbackColor,
    this.fallbackBorder,
  });

  final Widget child;

  /// 모서리 반경 — 네이티브는 유리 굴절이 이 모서리를 따라간다
  final double radius;

  /// 유리에 입힐 색 (null 이면 안 입힌다). iOS 26+ 에서만 먹는다
  final Color? tint;

  /// 누르면 유리가 눌리는 반응 — **누르는 면에만** 켠다 (검색바 ○, 상단 블러 ×)
  final bool interactive;

  /// 폴백에서 쓸 블러 세기
  final double blurSigma;

  /// 폴백에서 유리 대신 깔 반투명 색
  final Color? fallbackColor;

  /// 폴백에서 네이티브 글래스의 림처럼 보이게 두르는 헤어라인
  final BoxBorder? fallbackBorder;

  /// 네이티브 면을 쓸 수 있는가 — **지금은 iOS 만이다** (맥은 위 주석 참고)
  static bool get supported => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!supported) return _fallback();

    return Stack(
      children: [
        // 유리가 맨 아래 — 자기 **뒤**(이 Stack 밖)를 비춘다
        Positioned.fill(
          child: _NativeGlass(
            radius: radius,
            tint: tint,
            interactive: interactive,
          ),
        ),
        child,
      ],
    );
  }

  /// 애플이 아니거나 아직 안 붙인 플랫폼 — 지금까지 쓰던 Flutter 블러 그대로
  Widget _fallback() {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        // sigma 0 은 렌더링 오류가 나므로 최소값을 둔다
        filter: ImageFilter.blur(
          sigmaX: blurSigma + 0.01,
          sigmaY: blurSigma + 0.01,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: shape,
            border: fallbackBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 네이티브 뷰 한 장 — 값이 바뀌면 **다시 만들지 않고** 채널로 알린다
///
/// 새로 만들면 유리가 깜빡이고, 스크롤 한 프레임마다 값이 오는 자리(상단 블러)
/// 에서는 그게 곧 화면이 떠는 것으로 보인다.
class _NativeGlass extends StatefulWidget {
  _NativeGlass({
    required this.radius,
    required this.tint,
    required this.interactive,
  });

  final double radius;
  final Color? tint;
  final bool interactive;

  @override
  State<_NativeGlass> createState() => _NativeGlassState();
}

class _NativeGlassState extends State<_NativeGlass> {
  MethodChannel? _channel;

  Map<String, dynamic> get _params => {
    'radius': widget.radius,
    'tint': widget.tint?.toARGB32(),
    'interactive': widget.interactive,
  };

  @override
  void didUpdateWidget(_NativeGlass old) {
    super.didUpdateWidget(old);
    if (old.radius != widget.radius ||
        old.tint != widget.tint ||
        old.interactive != widget.interactive) {
      _channel?.invokeMethod('update', _params);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'com.hifis/glass_surface',
      creationParams: _params,
      creationParamsCodec: const StandardMessageCodec(),
      // 면은 배경이라 터치를 안 받는다 — 위에 얹힌 입력칸·버튼이 받아야 한다
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      onPlatformViewCreated: (id) =>
          _channel = MethodChannel('com.hifis/glass_surface_$id'),
    );
  }
}
