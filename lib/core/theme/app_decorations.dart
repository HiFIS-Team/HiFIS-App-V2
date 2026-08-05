import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';

/// 카드 공통 데코레이션
///
/// 흰 배경 + 헤어라인 테두리 + 은은한 그림자.
/// 모든 카드는 이걸 사용해 통일한다. 개별 스타일 선언 금지.
abstract final class AppDecorations {
  static BoxDecoration card({double radius = 24}) => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.gray100),
    boxShadow: AppShadows.card,
  );

  /// 입력칸 껍데기 — 회색 면에 모서리를 둥글린 것
  ///
  /// **화면마다 자기 입력칸 위젯을 들고 있다** (프로젝트·일정·결재·프로필·
  /// 회원 등록·새 메시지·로그인). 안에 넣는 `TextField` 설정이 자리마다
  /// 달라서 위젯 하나로 합치기는 어려운데, **껍데기 값이 갈리는 건 다른 문제**라
  /// 여기 한 곳에 둔다. 예전에는 모서리가 12·14·16 으로 섞여 있었다.
  static BoxDecoration field() => BoxDecoration(
    color: AppColors.gray50,
    borderRadius: BorderRadius.circular(12),
  );

  /// 입력칸 안쪽 여백 — 한 줄짜리 기준
  ///
  /// 여러 줄을 받는 칸은 위아래를 조금 더 준다 ([fieldPaddingMultiline]).
  static const fieldPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 13,
  );

  static const fieldPaddingMultiline = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );
}
