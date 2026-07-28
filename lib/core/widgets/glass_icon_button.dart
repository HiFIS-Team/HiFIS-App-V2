import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 리퀴드 글래스 원형 아이콘 버튼 (헤더 아이콘, 뒤로가기 등 공통)
///
/// symbol은 SF Symbol 이름을 사용한다. (예: 'bell', 'chevron.backward')
class GlassIconButton extends StatelessWidget {
  GlassIconButton({
    super.key,
    required this.symbol,
    this.onPressed,
    this.showBadge = false,
    this.size = 40,
  });

  final String symbol;
  final VoidCallback? onPressed;
  final bool showBadge;

  /// 버튼 지름. 심볼 크기는 비율에 맞춰 함께 커진다.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CNButton.icon(
          // 패키지의 setBrightness가 아이콘 설정을 유실하는 버그가 있어,
          // 테마가 바뀌면 네이티브 버튼을 새로 생성한다.
          key: ValueKey('glass-$symbol-${AppColors.isDark}'),
          icon: CNSymbol(symbol, size: size * 0.42, color: AppColors.gray700),
          size: size,
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
