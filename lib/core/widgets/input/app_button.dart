import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 앱 기본 버튼 — 팝업·모달 아래와 PC 하단 고정 자리에 쓴다
///
/// 확인 팝업, 급여 신청서, PC 하단 버튼이 저마다 같은 모양을 따로 그리고
/// 있어서 한 곳으로 모았다. 높이 50 · 라디우스 14 · 굵은 글씨로 통일한다.
/// (폰의 떠 있는 캡슐 버튼은 [BottomActionButton]이 따로 그린다)
class AppButton extends StatelessWidget {
  AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
    this.color,
    this.textColor,
    this.shrinkWrap = false,
  });

  final String label;
  final VoidCallback onTap;

  /// 서버에 쓰는 중 — 스피너로 바뀌고 **더 눌리지 않는다**
  ///
  /// **글자를 `'제출 중...'` 으로 바꾸지 않는다.** 그러면 버튼 폭이 글자 길이만큼
  /// 흔들려서 옆 버튼까지 밀린다. 스피너는 자리를 그대로 쓴다.
  ///
  /// 네트워크가 느릴 때 두 번 눌리면 서버에 같은 요청이 두 번 간다 —
  /// 두 번째는 400 이라 **성공 토스트 뒤에 에러 토스트가 따라 뜬다.**
  final bool busy;

  /// 주요 동작이면 true — 포인트 컬러로 채운다
  final bool filled;

  /// 면 색을 직접 줄 때 (되돌리기 어려운 동작의 빨간 버튼 등)
  final Color? color;
  final Color? textColor;

  /// true면 글자 폭만큼만 차지한다 (취소 버튼처럼 옆에 붙일 때)
  final bool shrinkWrap;

  static const double height = 50;

  @override
  Widget build(BuildContext context) {
    final background =
        color ?? (filled ? AppColors.primary : AppColors.gray100);
    final foreground =
        textColor ?? (filled ? Colors.white : AppColors.textSecondary);

    final button = Pressable(
      onTap: busy ? () {} : onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: shrinkWrap ? EdgeInsets.symmetric(horizontal: 24) : null,
        decoration: BoxDecoration(
          // 도는 동안 옅어져서 지금은 못 누른다는 걸 보여준다
          color: busy ? background.withValues(alpha: 0.6) : background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            : Text(
                label,
                maxLines: 1,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
      ),
    );

    return shrinkWrap ? IntrinsicWidth(child: button) : button;
  }
}
