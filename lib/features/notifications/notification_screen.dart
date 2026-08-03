import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/notification_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/top_frost.dart';

/// 알림 화면
///
/// 전체 / 안읽음을 전환하며 오늘·이전으로 묶어 보여준다.
/// 눌러서 읽음 처리하고, 갈 곳이 있는 알림은 그 화면으로 넘어간다.
class NotificationScreen extends StatefulWidget {
  NotificationScreen({super.key, this.embedded = false, this.active = true});

  /// 데스크톱 플로팅 패널에 담길 때 true.
  /// 뒤로가기 버튼을 숨긴다 (닫기는 헤더의 X 버튼이 담당).
  final bool embedded;

  /// 지금 보이고 있는지.
  ///
  /// **데스크톱 패널은 닫혀도 트리에 남아 있다** — 흐려질 뿐이라 화면이
  /// 그대로 살아 있고, 그냥 두면 앱을 켠 뒤 딱 한 번만 받는다.
  /// 열릴 때마다 새로 받으려고 열림 상태를 받는다.
  final bool active;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  final _collapse = ScrollCollapse();

  /// true면 안 읽은 알림만 보여준다
  bool _unreadOnly = false;

  /// 홈이 먼저 받아 둔 게 있으면 그걸 보여주면서 조용히 새로 받는다.
  /// 있는 걸 두고 스피너부터 띄우면 열 때마다 화면이 한 번 비워진다
  bool _loading = _items.isEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant NotificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 데스크톱 패널이 다시 열렸다 — 닫혀 있는 동안 쌓인 게 있을 수 있다
    if (widget.active && !oldWidget.active) _load();
  }

  /// 열 때마다 새로 받는다 — 알림은 안 보는 사이에도 계속 쌓인다.
  /// 다른 화면이 먼저 받아 뒀어도 그건 그때 값이라 다시 받는 게 맞다
  Future<void> _load() async {
    try {
      await _loadNotifications();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _scrollController.dispose();
    _collapse.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final before = [for (final item in _items) item.read];
    setState(() {
      for (final item in _items) {
        item.read = true;
      }
    });
    _syncBadge();
    try {
      await NotificationApi.markAllRead();
      if (mounted) AppToast.show(context, '모든 알림을 읽음으로 표시했어요');
    } catch (error) {
      // 되돌린다 — 안 읽은 게 읽은 것처럼 남아 있으면 영영 못 찾는다
      for (var i = 0; i < _items.length; i++) {
        _items[i].read = before[i];
      }
      _syncBadge();
      if (mounted) {
        setState(() {});
        AppToast.show(context, messageOf(error));
      }
    }
  }

  /// 눌렀을 때 — 읽음으로 바꾸고, 갈 곳이 있으면 그 화면으로 보낸다
  void _open(AppNotification item) {
    _read(item);

    final target = _targetOf(item.link);
    if (target == null) return;
    requestedScreen.value = target;
    // 폰은 알림이 화면으로 밀려 올라와 있어서, 닫아야 목적지가 보인다
    if (!widget.embedded) Navigator.pop(context);
  }

  /// 읽음 — 화면을 먼저 바꾸고 서버에 보낸다.
  /// 실패해도 되돌리지 않는다 (다시 받으면 서버 값으로 맞춰진다)
  void _read(AppNotification item) {
    if (item.read) return;
    setState(() => item.read = true);
    _syncBadge();
    NotificationApi.markRead(item.id).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final shown = _unreadOnly ? _items.where((n) => !n.read).toList() : _items;
    final now = DateTime.now();
    final today = shown.where((n) => _isToday(n.createdAt, now)).toList();
    final earlier = shown.where((n) => !_isToday(n.createdAt, now)).toList();
    final unreadCount = _items.where((n) => !n.read).length;

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
                  right: unreadCount > 0 ? '안읽음 $unreadCount' : '안읽음',
                  value: _unreadOnly,
                  onChanged: (value) => setState(() => _unreadOnly = value),
                ),
                SizedBox(height: 20),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  )
                else if (shown.isEmpty)
                  EmptyCard(
                    icon: Icons.notifications_none_rounded,
                    text: _unreadOnly ? '안 읽은 알림이 없어요' : '알림이 없어요',
                  )
                else ...[
                  if (today.isNotEmpty) ...[
                    _SectionLabel('오늘'),
                    SizedBox(height: 10),
                    _NotificationCard(items: today, onTap: _open),
                  ],
                  if (today.isNotEmpty && earlier.isNotEmpty)
                    SizedBox(height: 24),
                  if (earlier.isNotEmpty) ...[
                    _SectionLabel('이전'),
                    SizedBox(height: 10),
                    _NotificationCard(items: earlier, onTap: _open),
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
                  if (unreadCount > 0)
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
}

// ── 데이터 ──

/// 받아 둔 알림 — 헤더 종 배지가 화면 밖에서도 세어야 해서 모듈 전역으로 둔다
final _items = <AppNotification>[];

Future<void> _loadNotifications() async {
  final rows = await NotificationApi.list();
  _items
    ..clear()
    ..addAll(rows);
  _syncBadge();
}

/// 안 읽은 알림 수 — 헤더 종 버튼의 빨간 점이 이걸 본다.
///
/// 알림 화면을 한 번도 안 열어도 배지는 맞아야 해서 홈이 같이 받아 둔다
/// ([loadNotificationsIfNeeded]).
final unreadNotifications = ValueNotifier<int>(0);

void _syncBadge() =>
    unreadNotifications.value = _items.where((n) => !n.read).length;

/// 홈에서 같이 받아 둔다 — 실패해도 홈은 떠야 하므로 조용히 넘긴다.
/// 알림 화면은 열 때마다 따로 새로 받으므로 여기서 한 번 실패해도 괜찮다
Future<void> loadNotificationsIfNeeded() async {
  if (_items.isNotEmpty) return;
  try {
    await _loadNotifications();
  } catch (_) {}
}

/// 알림을 눌렀을 때 갈 화면
///
/// 서버 `link` 를 앱 화면으로 옮긴 것이다. 탭 번호는 플랫폼마다 달라서
/// 여기서는 '어디로' 만 정하고 자리는 `MainShell` 이 고른다.
enum NotificationTarget { attendance, salary, notice, project, ranking }

/// 알림에서 열어달라고 요청한 화면 — `MainShell` 이 보고 탭을 옮긴다
final requestedScreen = ValueNotifier<NotificationTarget?>(null);

/// 서버 링크 → 갈 화면. 갈 데가 없으면 null (읽음 처리만 한다)
///
/// **아직 안 잇는 것들이 있다.**
/// - `/schedule` `/approvals/{id}` — 데스크톱에만 있는 화면이라 폰에서 갈 데가 없다
/// - `/chat/rooms/{id}` — 사내톡이 아직 목업이라 방을 지정해 열 수 없다
NotificationTarget? _targetOf(String? link) {
  if (link == null) return null;
  // 공지·결재는 뒤에 id 가 붙어 온다
  final head = link.split('/').where((s) => s.isNotEmpty).firstOrNull;
  return switch (head) {
    'attendance' => NotificationTarget.attendance,
    'payroll' => NotificationTarget.salary,
    'notices' => NotificationTarget.notice,
    'projects' => NotificationTarget.project,
    'ranking' => NotificationTarget.ranking,
    _ => null,
  };
}

// ── 표시용 계산 ──

bool _isToday(DateTime time, DateTime now) =>
    time.year == now.year && time.month == now.month && time.day == now.day;

/// '방금 · 12분 전 · 오후 2:30 · 어제 · 7.28' 형태
String _timeLabel(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (_isToday(time, now)) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '${time.hour < 12 ? '오전' : '오후'} $hour:${time.minute.toString().padLeft(2, '0')}';
  }
  if (_isToday(time, now.subtract(Duration(days: 1)))) return '어제';
  return '${time.month}.${time.day}';
}

/// 종류별 아이콘 — 목록에서 한눈에 가르는 단서다
IconData _iconOf(NotificationKind kind) => switch (kind) {
  NotificationKind.attendance => Icons.login_rounded,
  NotificationKind.leave => Icons.beach_access_rounded,
  NotificationKind.notice => Icons.campaign_rounded,
  NotificationKind.chat => Icons.chat_bubble_rounded,
  NotificationKind.approval => Icons.assignment_turned_in_rounded,
  NotificationKind.project => Icons.flag_rounded,
  NotificationKind.payroll => Icons.payments_rounded,
  NotificationKind.schedule => Icons.event_rounded,
  NotificationKind.ranking => Icons.emoji_events_rounded,
  NotificationKind.other => Icons.notifications_rounded,
};

/// 종류별 색 — 무채색 원칙을 지키려고 토큰 셋(파랑·주황·초록)만 돌려 쓴다
Color _colorOf(NotificationKind kind) => switch (kind) {
  NotificationKind.attendance ||
  NotificationKind.notice ||
  NotificationKind.chat ||
  NotificationKind.schedule => AppColors.primary,
  NotificationKind.leave ||
  NotificationKind.project ||
  NotificationKind.ranking => AppColors.warning,
  NotificationKind.approval || NotificationKind.payroll => AppColors.success,
  NotificationKind.other => AppColors.gray400,
};

// ── 조각 ──

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
  _NotificationCard({required this.items, required this.onTap});

  final List<AppNotification> items;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            _NotificationTile(item: items[i], onTap: () => onTap(items[i])),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    final color = _colorOf(item.kind);
    final body = item.body;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: unread ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconOf(item.kind),
                color: unread ? color : AppColors.gray400,
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
                  // 본문은 제목만으로 모자란 것들을 채운다 ('· 사유: …' 같은 것)
                  if (body != null && body.isNotEmpty) ...[
                    SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(height: 1.4),
                    ),
                  ],
                  SizedBox(height: 3),
                  Text(
                    _timeLabel(item.createdAt),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (unread) ...[
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
