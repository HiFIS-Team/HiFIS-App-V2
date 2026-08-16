import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// 데스크톱(넓은 창 + 마우스) 레이아웃을 쓸 플랫폼인지.
///
/// macOS와 Windows 배포가 대상이다. 사이드바 셸, 호버 UI,
/// 프라이버시 커버 제외 등 데스크톱 분기는 전부 이 값으로 판단한다.
bool get isDesktop =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

/// 안드로이드인가 — **안드로이드다운 것을 켤 때만** 쓴다
///
/// `isApple` 의 반대가 아니다. `!isApple` 로 가르면 **윈도우까지 같이 바뀐다**
/// (윈도우는 `isDesktop` 이면서 `isApple` 이 아니다). 확인할 장비가 없는
/// 윈도우를 건드리지 않으려고 갈래를 따로 둔다.
///
/// 물결(리플)·화면 전환처럼 "안드로이드 관례라서 하는 것"에만 쓴다.
/// 애플이 아닌 곳의 **폴백**(글래스·SF 심볼)은 예전처럼 `isApple` 로 가른다 —
/// 그건 윈도우도 같이 타야 하는 갈래다.
bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

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
