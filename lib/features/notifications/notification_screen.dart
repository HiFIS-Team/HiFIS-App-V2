import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';

/// 알림 화면 (목업)
///
/// 데이터는 하드코딩된 샘플이며, 기능 개발 시 실제 알림 데이터로 교체한다.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
              children: const [
                Text('알림', style: AppTextStyles.title1),
                SizedBox(height: 20),
                _SectionLabel('오늘'),
                SizedBox(height: 10),
                _NotificationCard(
                  tiles: [
                    _NotificationTile(
                      icon: Icons.beach_access_rounded,
                      color: AppColors.warning,
                      title: '박지현님이 휴가를 신청했어요',
                      time: '방금 전',
                      unread: true,
                    ),
                    _NotificationTile(
                      icon: Icons.login_rounded,
                      color: AppColors.primary,
                      title: '김민수님이 출근했어요',
                      time: '오전 9:02',
                      unread: true,
                    ),
                    _NotificationTile(
                      icon: Icons.payments_rounded,
                      color: AppColors.success,
                      title: '7월 급여 정산이 완료됐어요',
                      time: '오전 8:00',
                    ),
                  ],
                ),
                SizedBox(height: 24),
                _SectionLabel('이전'),
                SizedBox(height: 10),
                _NotificationCard(
                  tiles: [
                    _NotificationTile(
                      icon: Icons.campaign_rounded,
                      color: AppColors.primary,
                      title: '새로운 공지가 등록됐어요',
                      time: '어제',
                    ),
                    _NotificationTile(
                      icon: Icons.logout_rounded,
                      color: AppColors.gray400,
                      title: '이서연님이 퇴근했어요',
                      time: '어제',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label, style: AppTextStyles.label),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.tiles});

  final List<_NotificationTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: tiles),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    this.unread = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String time;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTextStyles.body2)),
          const SizedBox(width: 8),
          Text(time, style: AppTextStyles.caption),
          if (unread) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
