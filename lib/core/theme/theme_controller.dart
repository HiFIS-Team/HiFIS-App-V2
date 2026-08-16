import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/sf_symbols.dart';
import 'app_colors.dart';

/// 앱 전역 테마 모드 컨트롤러
///
/// AppColors 팔레트를 교체한 뒤 위젯 트리 전체를 리빌드해서
/// 네비게이션/탭 상태를 유지한 채 테마를 적용한다.
abstract final class ThemeController {
  static ThemeMode mode = ThemeMode.light;

  static const _key = 'theme_mode';

  /// 저장해 둔 테마를 되살린다 — **`runApp` 전에** 부른다
  ///
  /// 뒤에 부르면 라이트로 한 번 그려졌다가 다크로 바뀌어 **깜빡인다.**
  /// 시스템 밝기는 아직 `MediaQuery` 가 없어서 [PlatformDispatcher] 로 읽는다.
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    mode = switch (prefs.getString(_key)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    final platformDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    AppColors.setDark(
      mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark),
    );
    syncNative();
  }

  static void set(BuildContext context, ThemeMode next) {
    mode = next;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    AppColors.setDark(
      next == ThemeMode.dark || (next == ThemeMode.system && platformDark),
    );
    syncNative();
    _rebuildAll();
    // 저장은 화면을 바꾼 뒤에 — 기다리면 고르는 손맛이 느려진다
    unawaited(_save(next));
  }

  static Future<void> _save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// 네이티브 창 외관을 앱 테마에 맞춘다
  ///
  /// **안 맞추면 다크 모드에서 유리가 밝게 뜬다.** 네이티브 뷰(우리 유리 ·
  /// `CNButton` · `CNTabBar` · 시스템 메뉴 · 키보드)는 앱 안 테마를 모르고
  /// **iOS 시스템 외관만** 보기 때문이다.
  ///
  /// 테마를 바꿀 때와 **앱이 뜰 때** 둘 다 불러야 한다 — 저장해 둔 테마로
  /// 복원되는 경로에서는 [set] 을 안 거친다.
  static const _channel = MethodChannel('com.hifis/theme');

  static void syncNative() {
    if (!isApple) return; // 안드로이드·윈도우는 해당 없다
    _channel.invokeMethod('setDark', AppColors.isDark).catchError((_) {
      // 채널이 없는 빌드(맥 등)에서는 조용히 넘어간다 — 색만 예전 그대로다
      return null;
    });
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
