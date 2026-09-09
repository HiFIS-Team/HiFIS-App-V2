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
  const SectionHeader({
    super.key,
    required this.title,
    this.info,
    this.trailing,
  });

  final String title;

  /// 제목 옆 보조 정보 — 인원수·남은 건수처럼 짧은 것
  final Widget? info;

  /// **선 오른쪽 끝**에 서는 컨트롤 (달 이동 등)
  ///
  /// [info] 와 자리가 다르다 — 저기는 제목에 붙는 **값**이고 여기는 누르는
  /// **것**이다. 화면 머리말(`DesktopHeader.trailing`)이 컨트롤을 오른쪽 끝에
  /// 세우는 것과 같은 규칙이라, 눈이 같은 자리에서 찾는다.
  final Widget? trailing;

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
        if (trailing != null) ...[SizedBox(width: 14), trailing!],
      ],
    );
  }
}
