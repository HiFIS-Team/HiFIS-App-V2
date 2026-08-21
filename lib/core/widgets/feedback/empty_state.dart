/// 화면이 통째로 빌 때 그 자리를 채우는 안내 — 큰 원 · 제목 · 한 줄
///
/// [EmptyCard] 와 자리가 다르다.
/// - **[EmptyCard]** 카드나 목록 **안**의 한 칸이 빌 때 (작은 둥근 사각 아이콘)
/// - **여기** 화면·판이 **통째로** 빌 때 (큰 원 테두리 + 제목)
///
/// 전자결재 상세 판이 쓰던 모양이다. 프로젝트 2단 화면도 같은 모양을 손으로
/// 그리고 있었고 문서함만 작은 카드 모양이라 결이 갈렸다.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  /// 여기가 무슨 자리인지 — `전자결재` `프로젝트` 처럼 화면 이름
  final String title;

  /// 왜 비었는지 한 줄
  final String text;

  /// 눌러서 바로 만들 수 있으면 버튼을 단다 (둘 다 있어야 그린다)
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Center(
              child: Icon(icon, size: 38, color: AppColors.textPrimary),
            ),
          ),
          SizedBox(height: 20),
          Text(title, style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          if (label != null && action != null) ...[
            SizedBox(height: 24),
            Pressable(
              onTap: action,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
