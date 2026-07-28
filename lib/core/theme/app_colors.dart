import 'package:flutter/material.dart';

/// 앱 전역 컬러 토큰 (토스 스타일)
///
/// 무채색 베이스 + 포인트 컬러(블루) 1개 원칙.
/// 위젯에서 색상을 직접 선언하지 말고 반드시 이 토큰을 사용한다.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF3182F6);
  static const primaryLight = Color(0xFFE8F3FF);
  static const gradientStart = Color(0xFF4593FC);
  static const gradientEnd = Color(0xFF2A6FF2);

  // Grayscale
  static const gray900 = Color(0xFF191F28);
  static const gray700 = Color(0xFF333D4B);
  static const gray600 = Color(0xFF4E5968);
  static const gray500 = Color(0xFF6B7684);
  static const gray400 = Color(0xFF8B95A1);
  static const gray300 = Color(0xFFB0B8C1);
  static const gray200 = Color(0xFFD1D6DB);
  static const gray100 = Color(0xFFE5E8EB);
  static const gray50 = Color(0xFFF2F4F6);
  static const gray20 = Color(0xFFF9FAFB);

  // Semantic
  static const background = Color(0xFFF2F4F6);
  static const surface = Colors.white;
  static const textPrimary = gray900;
  static const textSecondary = gray600;
  static const textTertiary = gray400;
  static const divider = gray100;

  // Status
  static const success = Color(0xFF00C471);
  static const warning = Color(0xFFFF9F0A);
  static const error = Color(0xFFF04452);
}
