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
import '../profile/profile_screen.dart';

/// 홈 화면 (디자인 시스템 데모용 샘플)
///
/// 데이터는 전부 하드코딩된 목업이며, 기능 개발 시 실제 데이터로 교체한다.
class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 64, 20, 110),
              children: [
                _GreetingCard(),
                SizedBox(height: 16),
                _HeroStatusCard(),
                SizedBox(height: 16),
                _ProjectsCard(),
                SizedBox(height: 16),
                _NoticeCard(),
              ],
            ),
          ),
          // 상단 고정 글래스 버튼 — 콘텐츠가 유리 뒤로 스크롤된다
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8, right: 16),
                child: _HeaderButtons(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 우측 글래스 버튼 묶음
///
/// 바코드 오버레이가 떠 있는 동안에는 버튼 모양은 그대로 두고
/// 터치만 비활성화한다. 글래스 눌림 효과가 딤 위로 그려지는 것을 막기 위함.
class _HeaderButtons extends StatefulWidget {
  _HeaderButtons();

  @override
  State<_HeaderButtons> createState() => _HeaderButtonsState();
}

class _HeaderButtonsState extends State<_HeaderButtons> {
  bool _overlayOpen = false;

  Future<void> _openBarcode() async {
    setState(() => _overlayOpen = true);
    await showAttendanceBarcode(context);
    if (mounted) setState(() => _overlayOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconButton(
          symbol: 'barcode.viewfinder',
          enabled: !_overlayOpen,
          onPressed: _openBarcode,
        ),
        SizedBox(width: 10),
        GlassIconButton(
          symbol: 'message',
          enabled: !_overlayOpen,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => MessageScreen()),
          ),
        ),
        SizedBox(width: 10),
        GlassIconButton(
          symbol: 'bell',
          showBadge: true,
          enabled: !_overlayOpen,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => NotificationScreen()),
          ),
        ),
        SizedBox(width: 10),
        GlassIconButton(
          symbol: 'person',
          enabled: !_overlayOpen,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => ProfileScreen()),
          ),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  _GreetingCard();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_todayLabel, style: AppTextStyles.caption),
          SizedBox(height: 4),
          Text('좋은 아침이에요 👋', style: AppTextStyles.title1),
          // 이름에만 브랜드 그라데이션 포인트
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppColors.primary, Color(0xFF7C5CFC)],
            ).createShader(bounds),
            child: Text('은후님', style: AppTextStyles.title1),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusCard extends StatefulWidget {
  _HeroStatusCard();

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
    _timer = Timer.periodic(Duration(seconds: 1), (_) => setState(() {}));
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
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('오늘 근무', style: AppTextStyles.label),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.all(Radius.circular(100)),
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
          SizedBox(height: 16),
          Text(
            timeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 20),
          _WorkGauge(rate: rate),
          SizedBox(height: 10),
          // 근무 시작 시간 — 진행률 — 종료 시간
          Row(
            children: [
              Text('09:00', style: AppTextStyles.caption),
              Spacer(),
              Text(
                percentText,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text('18:00', style: AppTextStyles.caption),
            ],
          ),
          SizedBox(height: 18),
          // 실제 출퇴근 스캔 기록
          Row(
            children: [
              _ScanRecord(label: '출근', time: checkInText),
              Spacer(),
              _ScanRecord(label: '퇴근', time: checkOutText),
            ],
          ),
        ],
      ),
    );
  }

}

class _ScanRecord extends StatelessWidget {
  _ScanRecord({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final recorded = time != '--:--';
    return Row(
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(width: 8),
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
  _WorkGauge({required this.rate});

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
                    gradient: LinearGradient(
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
                    boxShadow: [
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

class _CardHeader extends StatelessWidget {
  _CardHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.title3),
        SizedBox(width: 6),
        Text(
          '$count',
          style: AppTextStyles.title3.copyWith(color: AppColors.gray400),
        ),
        Spacer(),
        // TODO: 목록 페이지 연결
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(
              children: [
                Text('전체', style: AppTextStyles.label),
                SizedBox(width: 2),
                Icon(
                  CupertinoIcons.arrow_right,
                  size: 14,
                  color: AppColors.gray600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  _ProjectsCard();

  @override
  Widget build(BuildContext context) {
    // 내가 참여 중인 프로젝트만 마감 임박순 3개 (기능 연동 시 실제 데이터로 교체)
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '프로젝트', count: 3),
          SizedBox(height: 14),
          _ProjectRow(
            name: '여름 회원 이벤트 프로모션',
            members: '나 외 4명',
            dday: 'D-2',
            color: AppColors.error,
          ),
          SizedBox(height: 14),
          _ProjectRow(
            name: 'PT룸 장비 교체',
            members: '나 외 2명',
            dday: 'D-5',
            color: AppColors.warning,
          ),
          SizedBox(height: 14),
          _ProjectRow(
            name: '신규 트레이너 온보딩',
            members: '나 외 3명',
            dday: 'D-12',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  _ProjectRow({
    required this.name,
    required this.members,
    required this.dday,
    required this.color,
  });

  final String name;
  final String members;
  final String dday;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // TODO: 프로젝트 상세 페이지 연결
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          // 일정 카드 스타일의 세로 색 막대
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(members, style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dday,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  _NoticeCard();

  @override
  Widget build(BuildContext context) {
    // 최신 공지 5개 (기능 연동 시 실제 데이터로 교체)
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '공지', count: 5),
          SizedBox(height: 4),
          _NoticeRow(
            title: '8월 근무표가 확정되었습니다',
            author: '관리자',
            time: '오늘',
            pinned: true,
          ),
          Divider(),
          _NoticeRow(
            title: '여름 휴가 신청 안내',
            author: '박지현',
            time: '어제',
          ),
          Divider(),
          _NoticeRow(
            title: '센터 청소 일정 변경',
            author: '김민수',
            time: '3일 전',
          ),
          Divider(),
          _NoticeRow(
            title: '7월 우수사원 발표',
            author: '관리자',
            time: '4일 전',
          ),
          Divider(),
          _NoticeRow(
            title: '정수기 정기 점검 안내',
            author: '관리자',
            time: '6일 전',
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  _NoticeRow({
    required this.title,
    required this.author,
    required this.time,
    this.pinned = false,
  });

  final String title;
  final String author;
  final String time;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    // TODO: 공지 상세 페이지 연결
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PIN',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text('$author · $time', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
