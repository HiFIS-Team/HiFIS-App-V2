import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../attendance/attendance_barcode_overlay.dart';
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
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 110),
              children: const [
                _GreetingCard(),
                SizedBox(height: 16),
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
                      symbol: 'barcode.viewfinder',
                      onPressed: () => showAttendanceBarcode(context),
                    ),
                    const SizedBox(width: 10),
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
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_todayLabel, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          const Text('좋은 아침이에요 👋', style: AppTextStyles.title1),
          // 이름에만 브랜드 그라데이션 포인트
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, Color(0xFF7C5CFC)],
            ).createShader(bounds),
            child: const Text('은후님', style: AppTextStyles.title1),
          ),
        ],
      ),
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

class _HeroStatusCard extends StatefulWidget {
  const _HeroStatusCard();

  @override
  State<_HeroStatusCard> createState() => _HeroStatusCardState();
}

class _HeroStatusCardState extends State<_HeroStatusCard> {
  // 목업 근무 시간 (근태 기능 연동 시 실제 출퇴근 기록으로 교체)
  static const _checkInHour = 9;
  static const _checkOutHour = 18;

  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // 실시간 시계 갱신
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final checkIn = DateTime(now.year, now.month, now.day, _checkInHour);
    final checkOut = DateTime(now.year, now.month, now.day, _checkOutHour);
    final total = checkOut.difference(checkIn);

    var elapsed = now.isBefore(checkIn)
        ? Duration.zero
        : now.difference(checkIn);
    if (elapsed > total) elapsed = total;
    final remaining = total - elapsed;
    final rate = elapsed.inMinutes / total.inMinutes;

    // 상태 4종: 미출근/퇴근(회색), 출근(초록), 휴게(주황)
    // 목업 기준 — 근무 09~18시, 휴게 12~13시. 근태 연동 시 실제 상태로 교체.
    final String status;
    final Color statusColor;
    if (now.isBefore(checkIn)) {
      status = '미출근';
      statusColor = AppColors.gray500;
    } else if (!now.isBefore(checkOut)) {
      status = '퇴근';
      statusColor = AppColors.gray500;
    } else if (now.hour == 12) {
      status = '휴게';
      statusColor = AppColors.warning;
    } else {
      status = '출근';
      statusColor = AppColors.success;
    }

    // 실제 출퇴근 스캔 기록 자리 (바코드 스캔 연동 시 스캔 시각으로 교체)
    final checkInText = elapsed > Duration.zero ? '09:00' : '--:--';
    final checkOutText = remaining == Duration.zero ? '18:00' : '--:--';
    final percentText = '${(rate * 100).round()}%';

    final timeText =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('오늘 근무', style: AppTextStyles.label),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(100)),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            timeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          _WorkGauge(rate: rate),
          const SizedBox(height: 10),
          // 근무 시작 시간 — 진행률 — 종료 시간
          Row(
            children: [
              const Text('09:00', style: AppTextStyles.caption),
              const Spacer(),
              Text(
                percentText,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text('18:00', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 18),
          // 실제 출퇴근 스캔 기록
          Row(
            children: [
              _ScanRecord(label: '출근', time: checkInText),
              const Spacer(),
              _ScanRecord(label: '퇴근', time: checkOutText),
            ],
          ),
        ],
      ),
    );
  }

}

class _ScanRecord extends StatelessWidget {
  const _ScanRecord({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final recorded = time != '--:--';
    return Row(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(width: 8),
        Text(
          time,
          style: AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.w600,
            color: recorded ? AppColors.textPrimary : AppColors.gray300,
          ),
        ),
      ],
    );
  }
}

class _WorkGauge extends StatelessWidget {
  const _WorkGauge({required this.rate});

  /// 0.0(출근 전) ~ 1.0(퇴근)
  final double rate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbX = (constraints.maxWidth - 14) * rate;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // 트랙
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              // 채워진 게이지
              FractionallySizedBox(
                widthFactor: rate,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              // 현재 위치 썸
              Positioned(
                left: thumbX,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33101828),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
      decoration: AppDecorations.card(radius: 20),
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
      decoration: AppDecorations.card(),
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
