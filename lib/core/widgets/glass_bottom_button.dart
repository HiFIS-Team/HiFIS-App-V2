import 'dart:ui';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../util/sf_symbols.dart';
import 'pressable.dart';

/// 화면 아래에 떠 있는 리퀴드 글래스 알약 버튼
///
/// 하단 탭바와 같은 자리·높이에 놓여서, 탭바가 없는 화면(새로 만들기 등)에서
/// 주요 동작을 그 자리에 그대로 이어받는다.
/// 애플이 아닌 플랫폼은 네이티브 글래스를 못 쓰므로 블러 + 반투명으로 대체한다.
class GlassBottomButton extends StatelessWidget {
  GlassBottomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.active = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// 아직 조건이 안 갖춰졌으면 false — 맑은 글래스로 두고,
  /// 갖춰지면 파란 프로미넌트 글래스로 채운다.
  /// 비활성화(enabled: false)하면 iOS가 글래스 재질을 빼버리므로
  /// 누르는 것 자체는 막지 않고 동작 쪽에서 안내를 띄운다.
  final bool active;

  /// 탭바와 같은 높이
  static const double height = 56;

  /// 스크롤 콘텐츠가 버튼에 가리지 않도록 아래에 남겨야 할 여백
  static double inset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + height + 34;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: SizedBox(
          height: height,
          child: isApple
              ? CNButton(
                  // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                  key: ValueKey('glass-cta-$label-${AppColors.isDark}'),
                  label: label,
                  style: active
                      ? CNButtonStyle.prominentGlass
                      : CNButtonStyle.glass,
                  tint: AppColors.primary,
                  height: height,
                  onPressed: onPressed,
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Pressable(
      onTap: onPressed,
      scale: 0.97,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 조건이 갖춰지기 전에는 반투명 흰 글래스, 갖춰지면 파랗게 찬다
                color: active
                    ? AppColors.primary.withValues(alpha: 0.88)
                    : AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  color: active ? Colors.transparent : AppColors.gray100,
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.body1.copyWith(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
