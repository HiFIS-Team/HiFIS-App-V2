/// 목록 머리말 — 제목과 보조 정보, 그리고 오른쪽 끝까지 이어지는 가는 선
///
/// 조직도(`StaffScreen`)가 쓰던 모양이다. 흰 카드로 목록을 감싸면 카드 안에
/// 또 카드가 들어가서 층이 두 겹이 된다. 선 하나로 구분하면 바탕 위에 카드가
/// 바로 놓여서 화면이 얕아진다.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.info});

  final String title;

  /// 제목 옆 보조 정보 — 인원수·남은 건수처럼 짧은 것
  final Widget? info;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (info != null) ...[SizedBox(width: 8), info!],
        SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: AppColors.gray200)),
      ],
    );
  }
}
