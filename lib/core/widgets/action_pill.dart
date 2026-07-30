import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_icon_button.dart';
import 'pressable.dart';

/// 화면 우상단 주요 동작 알약 (새 프로젝트·새 회의록·공지 작성)
///
/// 폰 목록 화면들이 같은 자리에 같은 모양으로 쓴다.
class ActionPill extends StatelessWidget {
  ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 9, 15, 9),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 폰 상세 화면 공통 껍데기 — 상단 가운데 제목 + 좌측 뒤로가기 글래스 버튼
///
/// 본문은 스스로 스크롤하는 위젯([ListView] 등)을 넘긴다.
class PhoneDetailScaffold extends StatelessWidget {
  PhoneDetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;

  /// 우측 상단에 놓을 버튼 (없으면 제목만)
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Expanded(child: child),
              ],
            ),
          ),
          // 터치는 아래로 통과시켜 뒤로가기 버튼만 눌리게 한다
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: Text(title, style: AppTextStyles.title3)),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (action != null)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: action,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
