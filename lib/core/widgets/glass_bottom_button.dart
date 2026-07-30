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

  /// false면 흐리게 보인다. 눌리는 것 자체는 막지 않는다
  /// (눌렀을 때 왜 안 되는지 안내를 띄우기 위함).
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
      minimum: EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: height,
          child: isApple
              ? CNButton(
                  label: label,
                  style: CNButtonStyle.prominentGlass,
                  tint: active ? AppColors.primary : AppColors.gray300,
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
                color: (active ? AppColors.primary : AppColors.gray300)
                    .withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Text(
                label,
                style: AppTextStyles.body1.copyWith(
                  color: Colors.white,
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
