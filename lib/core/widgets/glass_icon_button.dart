import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 리퀴드 글래스 원형 아이콘 버튼 (헤더 아이콘, 뒤로가기 등 공통)
///
/// symbol은 SF Symbol 이름을 사용한다. (예: 'bell', 'chevron.backward')
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.symbol,
    this.onPressed,
    this.showBadge = false,
  });

  final String symbol;
  final VoidCallback? onPressed;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CNButton.icon(
          icon: CNSymbol(symbol, size: 17, color: AppColors.gray700),
          size: 40,
          onPressed: onPressed ?? () {},
        ),
        if (showBadge)
          Positioned(
            top: 2,
            right: 3,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
