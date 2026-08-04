import 'package:flutter/material.dart';

/// 앱 전역 컬러 토큰 (토스 스타일, 라이트/다크 팔레트)
///
/// 무채색 베이스 + 포인트 컬러(블루) 1개 원칙.
/// 위젯에서 색상을 직접 선언하지 말고 반드시 이 토큰을 사용한다.
/// 값이 getter인 이유: ThemeController가 팔레트를 교체하면 전체 리빌드와
/// 함께 색이 바뀐다. 그래서 이 토큰을 const 컨텍스트에 넣으면 안 된다.
abstract final class AppColors {
  static bool _dark = false;

  static bool get isDark => _dark;
  static void setDark(bool value) => _dark = value;

  // Brand (테마 공통)
  static const primary = Color(0xFF3182F6);
  static const gradientStart = Color(0xFF4593FC);
  static const gradientEnd = Color(0xFF2A6FF2);

  // Status (테마 공통)
  static const success = Color(0xFF00C471);
  static const warning = Color(0xFFFF9F0A);
  static const error = Color(0xFFF04452);

  // 근태 상태 (테마 공통)
  //
  // **무채색 + 포인트 1개 원칙의 예외다.** 대표 화면은 한 칸·한 카드 안에
  // 여러 상태가 같이 서서, 색이 그것들을 가르는 유일한 단서다.
  // 이 색들은 근태 화면 밖에서 쓰지 않는다.
  static const workIn = success; // 출근
  static const workOut = Color(0xFF495057); // 퇴근 — 끝난 상태라 진회색
  static const workOvertime = Color(0xFF7C3AED); // 야근
  static const workEarly = Color(0xFF00B8D9); // 조기퇴근
  static const workLate = warning; // 지각
  static const workLateEarly = Color(0xFFD9480F); // 지각 + 조기퇴근
  static const workNoCheckout = Color(0xFFD6336C); // 퇴근 누락
  static const workAbsent = error; // 결근
  static const workLeave = primary; // 월차
  static const workNone = Color(0xFFADB5BD); // 미출근 — 아직 아무 일도 없다

  static Color get primaryLight =>
      _dark ? const Color(0xFF16283F) : const Color(0xFFE8F3FF);

  // Grayscale — 다크에서는 명도가 반전된다
  static Color get gray900 =>
      _dark ? const Color(0xFFE7EBF0) : const Color(0xFF191F28);
  static Color get gray700 =>
      _dark ? const Color(0xFFC3CAD4) : const Color(0xFF333D4B);
  static Color get gray600 =>
      _dark ? const Color(0xFFA8B1BD) : const Color(0xFF4E5968);
  static Color get gray500 =>
      _dark ? const Color(0xFF8B95A1) : const Color(0xFF6B7684);
  static Color get gray400 =>
      _dark ? const Color(0xFF6B7684) : const Color(0xFF8B95A1);
  static Color get gray300 =>
      _dark ? const Color(0xFF4E5968) : const Color(0xFFB0B8C1);
  static Color get gray200 =>
      _dark ? const Color(0xFF3A4350) : const Color(0xFFD1D6DB);
  static Color get gray100 =>
      _dark ? const Color(0xFF2A3340) : const Color(0xFFE5E8EB);
  static Color get gray50 =>
      _dark ? const Color(0xFF232B36) : const Color(0xFFF2F4F6);
  static Color get gray20 =>
      _dark ? const Color(0xFF1D242E) : const Color(0xFFF9FAFB);

  // Semantic
  static Color get background =>
      _dark ? const Color(0xFF101419) : const Color(0xFFF2F4F6);
  static Color get surface => _dark ? const Color(0xFF1A212B) : Colors.white;

  /// 세그먼트 스위치의 회색 트랙
  ///
  /// 라이트에서 gray50은 화면 배경(background)과 같은 색이라 트랙이 안 보이고,
  /// 안 눌린 칸이 배경 위에 글자만 얹힌 것처럼 보인다. 한 단계 진한 면을 쓴다.
  /// 다크는 배경이 트랙보다 훨씬 어두워 gray50으로도 충분히 구분된다.
  static Color get track => _dark ? gray50 : gray100;
  static Color get textPrimary => gray900;
  static Color get textSecondary => gray600;
  static Color get textTertiary => gray400;
  static Color get divider => gray100;
}
