import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// 데스크톱(넓은 창 + 마우스) 레이아웃을 쓸 플랫폼인지.
///
/// macOS와 Windows 배포가 대상이다. 사이드바 셸, 호버 UI,
/// 프라이버시 커버 제외 등 데스크톱 분기는 전부 이 값으로 판단한다.
bool get isDesktop =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

/// 어느 플랫폼에서 도는지 — 서버에 보낼 때 쓰는 짧은 이름
///
/// 화면 분기에는 쓰지 않는다. 분기는 [isDesktop] · `isApple` 을 쓴다.
String get platformName => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'ios',
  TargetPlatform.android => 'android',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.windows => 'windows',
  _ => 'unknown',
};
