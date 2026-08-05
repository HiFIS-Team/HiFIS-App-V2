import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(28),
                    // 네이티브 글래스의 림처럼 보이는 헤어라인
                    border: Border.all(color: AppColors.gray100),
                  ),
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
