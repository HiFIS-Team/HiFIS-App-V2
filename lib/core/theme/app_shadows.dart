import 'package:flutter/material.dart';

/// 카드용 그림자 토큰
///
/// 연회색 배경 위 흰 카드에만 사용한다. 진한 그림자 금지.
abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x0A101828),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];
}
