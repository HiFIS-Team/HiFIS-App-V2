import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/see_all_button.dart';
import '../notice/notice_screen.dart';
import '../project/project_screen.dart';

/// 홈 화면 (디자인 시스템 데모용 샘플)
///
/// 데이터는 전부 하드코딩된 목업이며, 기능 개발 시 실제 데이터로 교체한다.
class HomeScreen extends StatefulWidget {
  HomeScreen({super.key, this.onOpenProjects, this.onOpenNotices});

  /// 카드의 '전체'를 눌렀을 때 해당 탭으로 옮겨달라고 셸에 알린다
  final VoidCallback? onOpenProjects;
  final VoidCallback? onOpenNotices;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 상세를 보고 돌아오면 진행률·읽음 표시가 바뀌어 있을 수 있다
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 데스크톱은 화면이 넓어서 프로젝트·공지를 나란히 배치한다
    final desktop = isDesktop;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 64, 20, bottomBarInset(context)),
              children: [
                _GreetingCard(),
                SizedBox(height: 16),
                _HeroStatusCard(),
                SizedBox(height: 16),
                if (desktop)
                  // 두 카드의 높이를 큰 쪽에 맞춰 같게 만든다
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ProjectsCard(
                            count: 5,
                            fill: true,
                            onOpenAll: widget.onOpenProjects,
                            onChanged: _refresh,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _NoticeCard(
                            onOpenAll: widget.onOpenNotices,
                            onChanged: _refresh,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _ProjectsCard(
                    onOpenAll: widget.onOpenProjects,
                    onChanged: _refresh,
                  ),
                  SizedBox(height: 16),
                  _NoticeCard(
                    onOpenAll: widget.onOpenNotices,
                    onChanged: _refresh,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
            child: Text('$me님', style: AppTextStyles.title1),
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
              Expanded(child: Text('오늘 근무', style: AppTextStyles.label)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  _CardHeader({required this.title, required this.count, this.onOpenAll});

  final String title;
  final int count;

  /// 눌리면 해당 탭으로 이동한다
  final VoidCallback? onOpenAll;

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
        if (onOpenAll != null) SeeAllButton(onTap: onOpenAll!),
      ],
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  _ProjectsCard({
    this.count = 3,
    this.fill = false,
    this.onOpenAll,
    required this.onChanged,
  });

  /// 표시할 프로젝트 수 (데스크톱은 5개까지)
  final int count;

  /// true면 카드 높이에 맞춰 행 간격을 고르게 벌린다 (데스크톱 나란히 배치용)
  final bool fill;

  final VoidCallback? onOpenAll;

  /// 상세를 보고 돌아왔을 때 홈을 갱신한다
  final VoidCallback onChanged;

  /// 폰은 상세를 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, ProjectBrief brief) async {
    if (isDesktop) {
      requestedProject.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 진행 중인 프로젝트를 마감 임박순으로
    final briefs = projectBriefs(count);

    final rows = [
      for (final brief in briefs)
        _ProjectRow(brief: brief, onTap: () => _open(context, brief)),
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '프로젝트', count: rows.length, onOpenAll: onOpenAll),
          SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '진행 중인 프로젝트가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else if (fill)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  _ProjectRow({required this.brief, required this.onTap});

  final ProjectBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Row(
        children: [
          // 일정 카드 스타일의 세로 색 막대
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: brief.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(brief.members, style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brief.ddayColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              brief.dday,
              style: AppTextStyles.caption.copyWith(
                color: brief.ddayColor,
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
  _NoticeCard({this.onOpenAll, required this.onChanged});

  final VoidCallback? onOpenAll;

  /// 본문을 보고 돌아왔을 때 홈을 갱신한다 (읽음 표시)
  final VoidCallback onChanged;

  /// 폰은 본문을 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, NoticeBrief brief) async {
    if (isDesktop) {
      requestedNotice.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 고정 공지가 위, 그다음 최신순으로 5개
    final briefs = noticeBriefs(5);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '공지', count: noticeCount, onOpenAll: onOpenAll),
          SizedBox(height: 4),
          if (briefs.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(0, 18, 0, 26),
              child: Center(
                child: Text(
                  '올라온 공지가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < briefs.length; i++) ...[
              if (i > 0) Divider(),
              _NoticeRow(
                brief: briefs[i],
                onTap: () => _open(context, briefs[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  _NoticeRow({required this.brief, required this.onTap});

  final NoticeBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = brief.title;
    final pinned = brief.pinned;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                // 아직 안 읽은 공지는 목록과 같은 파란 점으로 표시한다
                if (brief.unread) ...[
                  SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              '${brief.author} · ${brief.time}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
