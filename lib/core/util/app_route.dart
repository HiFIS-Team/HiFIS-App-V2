import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import 'platform.dart';

/// 화면을 미는 방식 — 플랫폼마다 다르다
///
/// 앱이 애플 기준으로 자라서 `CupertinoPageRoute` 를 30곳에서 직접 불렀다.
/// 그러면 **안드로이드에서도 iOS 처럼 옆에서 밀려 들어온다.** 전환은 그
/// 플랫폼을 제일 먼저 알아채는 자리라 여기서 가른다.
///
/// | | 무엇이 뜨나 |
/// |---|---|
/// | 애플 · 윈도우 | [CupertinoPageRoute] — 지금까지와 **똑같다** |
/// | 안드로이드 | [MaterialPageRoute] — 아래 [PageTransitionsTheme] 를 탄다 |
///
/// 안드로이드에서 `MaterialPageRoute` 를 쓰면 Flutter 기본
/// [PageTransitionsTheme] 가 `PredictiveBackPageTransitionsBuilder` 를 골라 준다.
/// 그래서 **전환이 시스템 뒤로가기 제스처와 맞물린다** — 우리가 애니메이션을
/// 따로 만들 것이 없다.
///
/// 윈도우를 애플 쪽에 둔 이유는 [isAndroid] 주석에 있다 (확인할 장비가 없다).
Route<T> appRoute<T>(
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
  RouteSettings? settings,
}) {
  if (isAndroid) {
    return MaterialPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
      settings: settings,
    );
  }
  return CupertinoPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
    settings: settings,
  );
}

/// [appRoute] 로 화면을 민다 — `Navigator.push(context, appRoute(...))` 축약
Future<T?> pushScreen<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return Navigator.push<T>(
    context,
    appRoute<T>(builder, fullscreenDialog: fullscreenDialog),
  );
}
