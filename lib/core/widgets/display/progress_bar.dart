import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 목표 대비 진행을 보여주는 가로 막대
///
/// 값이 바뀌면 차오르는 애니메이션이 붙는다 — 숫자만 바뀌면 눈에 안 띈다.
class ProgressBar extends StatelessWidget {
  ProgressBar({
    super.key,
    required this.ratio,
    this.color,
    this.height = 8,
    this.track,
  });

  /// 0~1 (넘치면 가득 찬 것으로 본다)
  final double ratio;

  final Color? color;
  final double height;

  /// 막대 뒤 트랙 색 (흰 카드 위가 아니면 한 톤 진하게 준다)
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: track ?? AppColors.gray100),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) =>
                FractionallySizedBox(widthFactor: value, child: child),
            child: Container(height: height, color: color ?? AppColors.primary),
          ),
        ],
      ),
    );
  }
}
