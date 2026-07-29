import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// 데스크톱(넓은 창 + 마우스) 레이아웃을 쓸 플랫폼인지.
///
/// macOS와 Windows 배포가 대상이다. 사이드바 셸, 호버 UI,
/// 프라이버시 커버 제외 등 데스크톱 분기는 전부 이 값으로 판단한다.
bool get isDesktop =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;
