import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';

/// 목록이 비었을 때 자리를 채우는 카드 — 둥근 사각 아이콘과 안내 문구
///
/// 알림·공지·프로젝트·회의록이 같은 모양을 쓴다.
class EmptyCard extends StatelessWidget {
  EmptyCard({
    super.key,
    required this.icon,
    required this.text,
    this.framed = true,
  });

  final IconData icon;
  final String text;

  /// false면 카드 면과 여백을 빼고 아이콘·문구만 그린다.
  /// **이미 카드 안**에 들어갈 때 쓴다 (카드 안에 카드가 겹치면 안 된다).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: framed ? EdgeInsets.symmetric(vertical: 52) : EdgeInsets.zero,
      decoration: framed ? AppDecorations.card() : null,
      child: Column(
        // 높이가 정해진 칸(Expanded 등) 안에서도 내용만큼만 잡는다.
        // 기본값(max)이면 목록 높이를 그대로 채워 카드가 길게 늘어난다.
        mainAxisSize: MainAxisSize.min,
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
