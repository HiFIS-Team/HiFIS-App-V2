import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// PC 화면 맨 위 머리말 — 제목 + 한 줄 설명 (+ 우측 컨트롤)
///
/// 화면마다 `Text(제목)` 하나만 덩그러니 놓여 있어서 위가 비어 보였다.
/// 무엇을 하는 화면인지 한 줄을 붙이고, 지점 선택처럼 화면 전체에 걸리는
/// 컨트롤은 오른쪽 끝에 세워 어느 화면에서나 같은 자리에 오게 한다.
class DesktopHeader extends StatelessWidget {
  DesktopHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;

  /// 이 화면이 무엇을 하는 곳인지 한 줄
  final String? subtitle;

  /// 오른쪽 끝 컨트롤 (지점 선택 등)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.display),
              if (subtitle != null) ...[
                SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 제목이 두 줄이어도 컨트롤은 가운데에 걸린다
        if (trailing != null) ...[SizedBox(width: 16), trailing!],
      ],
    );
  }
}
