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
}
