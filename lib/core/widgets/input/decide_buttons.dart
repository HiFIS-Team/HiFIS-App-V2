import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 결재 버튼 한 쌍 (반려 · 승인)
///
/// 프로젝트 기한 연장 카드와 전자결재 상세가 같이 쓴다. 같은 일을 하는
/// 자리라 모양이 갈리면 안 된다. 홈 카드·일정 하루 팝업처럼 줄 안에
/// 들어가는 작은 자리는 [MiniButton] 을 쓴다.
///
/// **반려가 왼쪽, 승인이 오른쪽이다.** 승인만 파랗게 채우고 반려는 테두리만
/// 두르되 글씨는 빨갛게 한다 — 되돌릴 수 없는 쪽이라 눈에 띄어야 한다.
class DecideButtons extends StatelessWidget {
  DecideButtons({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.fill = false,
  });

  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// true면 가로를 꽉 채운다 (폰에서 버튼을 아래로 내릴 때)
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final reject = Pressable(
      onTap: onReject,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text(
          '반려',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final approve = Pressable(
      onTap: onApprove,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '승인',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: fill
          ? [
              Expanded(child: reject),
              SizedBox(width: 8),
              Expanded(child: approve),
            ]
          : [reject, SizedBox(width: 6), approve],
    );
  }
}
