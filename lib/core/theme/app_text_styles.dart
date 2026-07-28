import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 전역 타이포그래피 토큰 (Pretendard)
///
/// 제목은 굵게, 보조 정보는 회색으로 위계를 만든다.
/// 색상 변경이 필요하면 `copyWith(color: ...)`로 파생해서 사용한다.
abstract final class AppTextStyles {
  static const String fontFamily = 'Pretendard';

  /// 화면 최상단 인사말, 온보딩 헤드라인
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// 화면 타이틀
  static const title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// 섹션 타이틀
  static const title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// 카드 타이틀, 앱바 타이틀
  static const title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// 본문 강조
  static const body1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// 본문 기본
  static const body2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// 버튼, 입력 라벨
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// 날짜, 시간, 보조 설명
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textTertiary,
  );
}
