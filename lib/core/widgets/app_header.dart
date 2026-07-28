import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 앱 공통 상단 헤더
///
/// 왼쪽 로고 + 오른쪽 메시지/알림/프로필 아이콘.
/// 로고 이미지가 확정되면 [_Logo]를 Image.asset으로 교체한다.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.showNotificationBadge = false});

  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          const _Logo(),
          const Spacer(),
          const _HeaderIconButton(icon: Icons.mode_comment_outlined),
          const SizedBox(width: 2),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            showBadge: showNotificationBadge,
          ),
          const SizedBox(width: 2),
          const _HeaderIconButton(icon: Icons.person_outline_rounded),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'HiFIS',
      style: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.primary,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.showBadge = false});

  final IconData icon;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: AppColors.gray600, size: 26),
            if (showBadge)
              Positioned(
                top: 1,
                right: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
