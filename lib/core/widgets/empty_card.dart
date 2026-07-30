import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';

/// 목록이 비었을 때 자리를 채우는 카드 — 둥근 사각 아이콘과 안내 문구
///
/// 알림·공지·프로젝트·회의록이 같은 모양을 쓴다.
class EmptyCard extends StatelessWidget {
  EmptyCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 52),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 28, color: AppColors.gray400),
          ),
          SizedBox(height: 14),
          Text(
            text,
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
