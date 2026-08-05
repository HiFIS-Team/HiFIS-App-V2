import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 줄 안에 들어가는 작은 처리 버튼 — 카드가 좁아서 기본 버튼(높이 56)은 못 쓴다
///
/// 홈 결재 대기 카드와 일정 하루 팝업이 같이 쓴다. 같은 일(승인·반려)을 하는
/// 자리라 모양이 갈리면 안 된다.
///
/// **[DecideButtons] 의 작은 판이다.** 색·글씨 규칙을 그대로 따른다 —
/// 승인만 파랗게 채우고 반려는 테두리만 두르되 글씨는 빨갛게. 예전에는 반려가
/// 회색 바탕에 회색 글씨라, 같은 일을 하는데 프로젝트·전자결재에서는 빨갛고
/// 홈에서는 회색이었다. 놓는 차례도 **반려가 왼쪽**으로 맞췄다.
class MiniButton extends StatelessWidget {
  MiniButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.filled,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;

  /// 서버에 보내는 중 — 안 눌린다 ([DecideButtons.busy] 와 같은 이유)
  final bool busy;

  /// 승인은 채우고 반려는 테두리만 — 실수로 반려를 먼저 누르지 않게
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? () {} : onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        // 도는 동안 옅어져서 지금은 못 누른다는 걸 보여준다
        foregroundDecoration: busy
            ? BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: AppColors.gray200),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.error,
          ),
        ),
      ),
    );
  }
}
