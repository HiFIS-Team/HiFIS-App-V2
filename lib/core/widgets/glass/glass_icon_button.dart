import 'dart:ui';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../util/sf_symbols.dart';
import '../input/pressable.dart';
import '../../theme/app_shadows.dart';

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
    this.enabled = true,
    this.symbolColor,
    this.stableId,
  });

  final String symbol;

  /// 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 할 때 쓰는 고정 식별자.
  /// (예: 알림 버튼의 종 ↔ X 전환) 형제 버튼과 겹치지 않는 값을 준다.
  final String? stableId;
  final VoidCallback? onPressed;
  final bool showBadge;

  /// 심볼 색. 기본은 gray700, 파괴적 동작(나가기 등)은 error 색을 쓴다.
  final Color? symbolColor;

  /// 버튼 지름. 심볼 크기는 비율에 맞춰 함께 커진다.
  final double size;

  /// false면 모양은 그대로 두고 네이티브 버튼이 터치만 무시한다.
  /// 글래스 눌림 효과는 오버레이의 딤보다 위에 그려지므로,
  /// 오버레이가 떠 있는 동안 이 값을 꺼서 눌림 자체를 막는다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isApple)
          CNButton.icon(
            // 패키지의 setBrightness가 아이콘 설정을 유실하는 버그가 있어,
            // 테마가 바뀌면 네이티브 버튼을 새로 생성한다.
            key: ValueKey('glass-${stableId ?? symbol}-${AppColors.isDark}'),
            // **색을 안 준다.** 안 주면 패키지가 `.label` 로 두고, 리퀴드
            // 글래스가 **뒤에 뭐가 있느냐에 맞춰 심볼 색을 뒤집는다**
            // (vibrancy). 회색으로 못 박으면 그 자동 대비가 죽어서 어두운
            // 사진 위에서 아이콘이 안 보인다 (사내톡에서 실제로 걸릴 자리).
            //
            // 뜻이 있는 색(삭제 빨강·완료 파랑)은 그대로 넘긴다.
            icon: CNSymbol(symbol, size: size * 0.42, color: symbolColor),
            size: size,
            enabled: enabled,
            onPressed: onPressed ?? () {},
          )
        else
          _fallback(),
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

  /// 애플이 아닌 플랫폼용 — 네이티브 글래스를 못 쓰므로
  /// 블러 + 반투명 흰 원으로 최대한 비슷하게 그린다.
  Widget _fallback() {
    return Pressable(
      onTap: enabled ? (onPressed ?? () {}) : () {},
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppShadows.ink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gray100),
              ),
              child: Icon(
                iconForSymbol(symbol),
                size: size * 0.46,
                color: symbolColor ?? AppColors.gray700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
