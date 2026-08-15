import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';
import 'glass_surface.dart';

/// 하단 고정 플로팅 글래스 검색 바 — 화면 Stack 안에서 쓰며 키보드와 함께 상승한다
class GlassSearchBar extends StatelessWidget {
  GlassSearchBar({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.float,
            ),
            child: GlassSurface(
              radius: 28,
              // 누르는 면이라 유리가 눌리는 반응을 켠다
              interactive: true,
              // 애플이 아닌 곳에서 쓰던 값 그대로 — 화면이 안 바뀐다
              fallbackColor: AppColors.surface.withValues(alpha: 0.72),
              fallbackBorder: Border.all(color: AppColors.gray100),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        size: 20,
                        color: AppColors.gray500,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: AppTextStyles.body2,
                          cursorColor: AppColors.primary,
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: AppTextStyles.body2.copyWith(
                              color: AppColors.gray400,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
