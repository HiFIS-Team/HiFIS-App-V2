import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 줄 안에 들어가는 작은 처리 버튼 — 카드가 좁아서 기본 버튼(높이 56)은 못 쓴다
///
/// 홈 결재 대기 카드와 일정 하루 팝업이 같이 쓴다. 같은 일(승인·반려)을 하는
/// 자리라 모양이 갈리면 안 된다.
class MiniButton extends StatelessWidget {
  MiniButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;

  /// 승인은 채우고 반려는 테두리만 — 실수로 반려를 먼저 누르지 않게
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
