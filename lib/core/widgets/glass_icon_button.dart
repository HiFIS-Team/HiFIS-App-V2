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
    this.frozen = false,
    this.fallbackIcon,
  });

  final String symbol;
  final VoidCallback? onPressed;
  final bool showBadge;

  /// 버튼 지름. 심볼 크기는 비율에 맞춰 함께 커진다.
  final double size;

  /// true면 네이티브 버튼 대신 플러터로 그린 대체 버튼을 보여준다.
  /// 네이티브 뷰는 오버레이의 어두운 배경 위로 눌림 효과를 그려버리므로,
  /// 오버레이가 떠 있는 동안 이 값을 켜서 네이티브 뷰를 트리에서 뺀다.
  final bool frozen;

  /// frozen 상태에서 대신 표시할 아이콘 (SF Symbol은 못 쓰므로 별도 지정)
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (frozen)
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              // 네이티브 글래스의 밝은 림을 흉내내는 헤어라인 테두리
              border: Border.all(color: AppColors.gray100),
            ),
            child: fallbackIcon != null
                ? Icon(
                    // 네이티브 SF 심볼 잉크 실측(≈20pt/40pt 버튼)에 맞춘 크기
                    fallbackIcon,
                    size: size * 0.66,
                    color: AppColors.gray700,
                  )
                : null,
          )
        else
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
