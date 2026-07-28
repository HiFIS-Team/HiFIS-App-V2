import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 전역 테마 모드 컨트롤러
///
/// AppColors 팔레트를 교체한 뒤 위젯 트리 전체를 리빌드해서
/// 네비게이션/탭 상태를 유지한 채 테마를 적용한다.
abstract final class ThemeController {
  static ThemeMode mode = ThemeMode.light;

  static void set(BuildContext context, ThemeMode next) {
    mode = next;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    AppColors.setDark(
      next == ThemeMode.dark || (next == ThemeMode.system && platformDark),
    );
    _rebuildAll();
  }

  /// 모든 위젯이 AppColors getter를 다시 읽도록 트리 전체를 리빌드한다.
  static void _rebuildAll() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      visit(root);
    }
  }
}
