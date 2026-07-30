import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';

/// 알림 화면 (목업)
///
/// 데이터는 하드코딩된 샘플이며, 기능 개발 시 실제 알림 데이터로 교체한다.
class NotificationScreen extends StatefulWidget {
  NotificationScreen({super.key, this.embedded = false});

  /// 데스크톱 플로팅 패널에 담길 때 true.
  /// 뒤로가기 버튼을 숨긴다 (닫기는 헤더의 X 버튼이 담당).
  final bool embedded;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  double _collapse = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final t = ((_scrollController.offset - 30) / 30).clamp(0.0, 1.0);
    if (t != _collapse) setState(() => _collapse = t);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(20, 68, 20, 40),
              children: [
                _SectionLabel('오늘'),
                SizedBox(height: 10),
                _NotificationCard(
                  tiles: [
                    _NotificationTile(
                      icon: Icons.beach_access_rounded,
                      color: AppColors.warning,
                      title: '김피스님이 휴가를 신청했어요',
                      time: '방금 전',
                      unread: true,
                    ),
                    _NotificationTile(
                      icon: Icons.login_rounded,
                      color: AppColors.primary,
                      title: '박준현님이 출근했어요',
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
                      title: '유찬빈님이 퇴근했어요',
                      time: '어제',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 스크롤 시 상단 프로그레시브 블러 — 콘텐츠가 헤더 뒤로 흐려진다
          TopFrost(collapse: _collapse, color: AppColors.background),
          // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: Text('알림', style: AppTextStyles.title3)),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          if (!widget.embedded)
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
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(label, style: AppTextStyles.label),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  _NotificationCard({required this.tiles});

  final List<_NotificationTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: AppDecorations.card(),
      child: Column(children: tiles),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  _NotificationTile({
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
      padding: EdgeInsets.symmetric(vertical: 12),
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
          SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTextStyles.body2)),
          SizedBox(width: 8),
          Text(time, style: AppTextStyles.caption),
          if (unread) ...[
            SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
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
