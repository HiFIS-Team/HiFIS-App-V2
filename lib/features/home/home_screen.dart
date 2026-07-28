import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../messages/message_screen.dart';
import '../notifications/notification_screen.dart';

/// 홈 화면 (디자인 시스템 데모용 샘플)
///
/// 데이터는 전부 하드코딩된 목업이며, 기능 개발 시 실제 데이터로 교체한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: const [
                _Header(),
                SizedBox(height: 24),
                _HeroStatusCard(),
                SizedBox(height: 32),
                _SectionTitle('빠른 메뉴'),
                SizedBox(height: 14),
                _QuickMenuGrid(),
                SizedBox(height: 32),
                _SectionTitle('최근 활동'),
                SizedBox(height: 14),
                _RecentActivityCard(),
              ],
            ),
          ),
          // 상단 고정 글래스 버튼 — 콘텐츠가 유리 뒤로 스크롤된다
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassIconButton(
                      symbol: 'message',
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const MessageScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      symbol: 'bell',
                      showBadge: true,
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const GlassIconButton(symbol: 'person'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppTabBar(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_todayLabel, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        const Text('좋은 아침이에요,\n은후님', style: AppTextStyles.title1),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: AppTextStyles.title2),
    );
  }
}

class _HeroStatusCard extends StatelessWidget {
  const _HeroStatusCard();

  static const _total = 26;
  static const _working = 21;

  @override
  Widget build(BuildContext context) {
    final rate = _working / _total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘 근무 현황',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '전체보기',
                  style: AppTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_total명 중 $_working명 출근',
            style: AppTextStyles.title1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.25)),
                  FractionallySizedBox(
                    widthFactor: rate,
                    child: Container(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              _HeroStatItem(count: 21, label: '출근'),
              _HeroStatDivider(),
              _HeroStatItem(count: 3, label: '휴가'),
              _HeroStatDivider(),
              _HeroStatItem(count: 2, label: '미출근'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: AppTextStyles.title2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  const _HeroStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _QuickMenuGrid extends StatelessWidget {
  const _QuickMenuGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickMenuCard(
                emoji: '⏰',
                title: '근태 관리',
                subtitle: '출퇴근 기록',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickMenuCard(
                emoji: '💸',
                title: '급여 정산',
                subtitle: '이번 달 급여',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickMenuCard(
                emoji: '👥',
                title: '직원 목록',
                subtitle: '전체 직원 관리',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickMenuCard(
                emoji: '📅',
                title: '일정 관리',
                subtitle: '근무 스케줄',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickMenuCard extends StatelessWidget {
  const _QuickMenuCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(height: 14),
                Text(title, style: AppTextStyles.body1),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: AppShadows.card,
      ),
      child: const Column(
        children: [
          _ActivityTile(
            icon: Icons.login_rounded,
            color: AppColors.primary,
            title: '김민수님이 출근했어요',
            time: '오전 9:02',
          ),
          _ActivityTile(
            icon: Icons.beach_access_rounded,
            color: AppColors.warning,
            title: '박지현님의 휴가 신청이 도착했어요',
            time: '오전 8:40',
          ),
          _ActivityTile(
            icon: Icons.logout_rounded,
            color: AppColors.gray400,
            title: '이서연님이 퇴근했어요',
            time: '어제',
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String time;

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
        ],
      ),
    );
  }
}

