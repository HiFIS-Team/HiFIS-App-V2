import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/top_frost.dart';

/// 알림 화면 (목업)
///
/// 전체 / 안읽음을 전환하며 오늘·이전으로 묶어 보여준다.
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
  final _collapse = ScrollCollapse();

  /// true면 안 읽은 알림만 보여준다
  bool _unreadOnly = false;

  final List<_Noti> _items = [
    _Noti(
      icon: Icons.beach_access_rounded,
      color: AppColors.warning,
      title: '이준경님이 휴가를 신청했어요',
      time: '방금 전',
      unread: true,
    ),
    _Noti(
      icon: Icons.login_rounded,
      color: AppColors.primary,
      title: '박준현님이 출근했어요',
      time: '오전 9:02',
      unread: true,
    ),
    _Noti(
      icon: Icons.payments_rounded,
      color: AppColors.success,
      title: '7월 급여 정산이 완료됐어요',
      time: '오전 8:00',
    ),
    _Noti(
      icon: Icons.campaign_rounded,
      color: AppColors.primary,
      title: '새로운 공지가 등록됐어요',
      time: '어제',
      today: false,
    ),
    _Noti(
      icon: Icons.logout_rounded,
      color: AppColors.gray400,
      title: '유찬빈님이 퇴근했어요',
      time: '어제',
      today: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _scrollController.dispose();
    _collapse.dispose();
    super.dispose();
  }

  int get _unreadCount => _items.where((n) => n.unread).length;

  void _markAllRead() {
    setState(() {
      for (final item in _items) {
        item.unread = false;
      }
    });
    AppToast.show(context, '모든 알림을 읽음으로 표시했어요');
  }

  @override
  Widget build(BuildContext context) {
    final shown = _unreadOnly ? _items.where((n) => n.unread).toList() : _items;
    final today = shown.where((n) => n.today).toList();
    final earlier = shown.where((n) => !n.today).toList();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(20, 68, 20, 40),
              children: [
                ModeSwitch(
                  left: '전체',
                  right: _unreadCount > 0 ? '안읽음 $_unreadCount' : '안읽음',
                  value: _unreadOnly,
                  onChanged: (value) => setState(() => _unreadOnly = value),
                ),
                SizedBox(height: 20),
                if (shown.isEmpty)
                  EmptyCard(
                    icon: Icons.notifications_none_rounded,
                    text: _unreadOnly ? '안 읽은 알림이 없어요' : '알림이 없어요',
                  )
                else ...[
                  if (today.isNotEmpty) ...[
                    _SectionLabel('오늘'),
                    SizedBox(height: 10),
                    _NotificationCard(items: today, onRead: _read),
                  ],
                  if (today.isNotEmpty && earlier.isNotEmpty)
                    SizedBox(height: 24),
                  if (earlier.isNotEmpty) ...[
                    _SectionLabel('이전'),
                    SizedBox(height: 10),
                    _NotificationCard(items: earlier, onRead: _read),
                  ],
                ],
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
          // 좌측 상단 뒤로가기 / 우측 상단 모두 읽음 (글래스 버튼 고정)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                children: [
                  if (!widget.embedded)
                    GlassIconButton(
                      symbol: 'chevron.backward',
                      onPressed: () => Navigator.pop(context),
                    ),
                  Spacer(),
                  if (_unreadCount > 0)
                    GlassIconButton(
                      symbol: 'checkmark',
                      onPressed: _markAllRead,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _read(_Noti item) {
    if (!item.unread) return;
    setState(() => item.unread = false);
  }
}

/// 알림 한 건 (읽음 상태가 바뀌므로 가변)
class _Noti {
  _Noti({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    this.today = true,
    this.unread = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String time;

  /// false면 '이전' 묶음
  final bool today;
  bool unread;
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
  _NotificationCard({required this.items, required this.onRead});

  final List<_Noti> items;
  final ValueChanged<_Noti> onRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            _NotificationTile(item: items[i], onTap: () => onRead(items[i])),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  _NotificationTile({required this.item, required this.onTap});

  final _Noti item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.unread;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: unread ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: unread ? item.color : AppColors.gray400,
                size: 20,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.body2.copyWith(
                      // 안 읽은 알림만 진하게
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(item.time, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (unread) ...[
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
      ),
    );
  }
}
