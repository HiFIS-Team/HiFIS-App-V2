import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 앱 전역 테마 (토스 스타일)
///
/// 그림자 없는 플랫한 표면, 둥근 모서리, 리플 대신 은은한 하이라이트.
/// AppColors 팔레트(라이트/다크)를 읽어서 구성된다.
abstract final class AppTheme {
  static ThemeData get current => ThemeData(
    useMaterial3: true,
    brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
    fontFamily: AppTextStyles.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    splashFactory: NoSplash.splashFactory,
    // **눌림 표시를 안 준다** (2026-08-21 대표 결정 — [Pressable] 과 같은 이유).
    //
    // 잔물결은 예전부터 껐는데 회색 면은 남아 있었다. 그대로 두면
    // `InkWell`·`TextButton`·`IconButton` 을 쓰는 자리(사내톡 방 목록·날짜
    // 고르개 등)**만** 반응해서, 같은 목록인데 화면마다 다르게 느껴진다.
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.title3,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.gray100,
        disabledForegroundColor: AppColors.gray400,
        minimumSize: Size.fromHeight(56),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: AppTextStyles.label,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.textPrimary,
      unselectedItemColor: AppColors.gray300,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
