import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/docs/approval_api.dart';
import '../../core/api/home/home_api.dart';
import '../../core/api/project/event_api.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/api/staff/payroll_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../core/widgets/input/mini_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../notice/notice_screen.dart';
import '../notifications/notification_screen.dart';
import '../project/project_screen.dart';
part 'home_inbox.dart';
part 'home_staff.dart';
part 'home_status.dart';
part 'home_cards.dart';

/// 폰 홈 카드 본문의 **최소** 높이 — 내용이 없다고 카드가 줄지 않게 한다
///
/// 네 장(결재 대기·오늘 출근·프로젝트·공지)이 세로로 쌓이는데 한 장만 짧으면
/// 화면이 들쭉날쭉해 보인다. 그래서 늘 세 줄이 들어갈 만큼을 잡아 둔다.
/// 줄 하나가 약 42(이름 15×1.5 + 1 + 직급 13×1.4), 줄 사이가 14 → 42×3 + 14×2.
///
/// **최소값이라 줄이 더 높거나 많으면 카드가 따라 커진다** (넘치지 않는다).
/// 데스크톱은 두 장을 나란히 놓고 `IntrinsicHeight` 로 맞추므로 안 쓴다.
const phoneCardBody = 154.0;

/// 폰 홈 카드에 세우는 줄 수 — 네 장이 같아야 나란히 놓았을 때 안 어긋난다
const phoneCardRows = 3;

/// 홈 화면 — 모든 직원이 처음 보는 화면
///
/// 오늘 근무는 `/me/home` 에서 온다. 지점 집계인 `/dashboard` 와 달리
/// 권한 없이 본인 것만 주는 요약이라 직급에 상관없이 열린다.
///
/// 프로젝트·공지 카드는 각 탭 화면과 **같은 목록**을 읽는다. 그 목록은 탭을
/// 열어야 채워지므로, 홈에서도 요약과 나란히 받아 둔다
/// (`loadNoticesIfNeeded`·`loadProjectsIfNeeded`). 안 그러면 홈부터 본 사람은
/// 카드가 비어 보인다.
/// 요약의 `monthScore` 는 지금 놓을 자리가 없어 안 쓴다 — 화면을 늘리지 않는다.
class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    this.onOpenProjects,
    this.onOpenNotices,
    this.onOpen,
    this.onOpenAttendance,
  });

  /// 카드의 '전체'를 눌렀을 때 해당 탭으로 옮겨달라고 셸에 알린다
  final VoidCallback? onOpenProjects;
  final VoidCallback? onOpenNotices;

  /// 결재 대기 카드가 쓰는 통로 — 갈 곳이 셋이라 하나로 받는다
  final void Function(NotificationTarget)? onOpen;

  /// 오늘 출근 카드의 '전체'가 가는 곳 — 근태·월차
  ///
  /// 대표·관리자의 근태 화면은 본인 집계가 아니라 **오늘 누가 어떤지**를
  /// 이름으로 띄운다. 이 카드가 요약하는 그 내용이라 여기로 보낸다.
  final VoidCallback? onOpenAttendance;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// 오늘 요약 — 도착 전에는 null 이라 근무 카드가 '미출근'으로 그려진다
  ///
  /// 첫 화면이라 통째로 로딩을 돌리면 앱을 열 때마다 빈 화면을 보게 된다.
  /// 인사말·시계는 기기에서 바로 나오므로 그대로 두고 값만 채운다.
  HomeSummary? _summary;

  /// 마지막으로 받아온 시각 — 창을 옮길 때마다 다시 부르지 않게 막는다
  DateTime? _loadedAt;

  /// 다시 받기까지 두는 최소 간격
  ///
  /// macOS 는 **창이 포커스만 잃어도** inactive → resumed 가 오간다.
  /// 그대로 두면 다른 앱을 잠깐 볼 때마다 요청이 나간다 (실제로 몇 초 간격으로
  /// 나갔다). 오늘 근태는 그렇게 자주 바뀌지 않는다.
  static const _minReloadGap = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱을 다시 열면 다시 받는다 — 배경에 둔 사이 출퇴근이나 날짜가 바뀐다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < _minReloadGap) return;
    _load();
  }

  Future<void> _load() async {
    if (currentUser == null) return;
    // 실패해도 찍어 둔다 — 서버가 죽어 있을 때 포커스마다 재시도하지 않게
    _loadedAt = DateTime.now();
    try {
      // 공지·프로젝트 카드가 목록을 그대로 읽는다 — 요약과 같이 받아 둔다.
      // 알림은 카드에 안 쓰지만 헤더 종 배지가 여기서 받은 수를 본다
      final summary =
          (await Future.wait([
                HomeApi.summary(),
                loadNoticesIfNeeded(),
                loadProjectsIfNeeded(),
                loadNotificationsIfNeeded(),
              ])).first
              as HomeSummary;
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(context, messageOf(error));
    }
  }

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
                // 대표·관리자는 출근을 안 해서 근무 카드가 늘 비어 있다.
                // 그 자리에 결재 대기와 오늘 출근을 아래 프로젝트·공지와 같은
                // 두 칸으로 놓는다.
                if (myRole == Role.master || myRole == Role.admin) ...[
                  if (desktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _InboxCard(onOpen: widget.onOpen)),
                          SizedBox(width: 16),
                          Expanded(
                            child: _TodayStaffCard(
                              fill: true,
                              onOpenAll: widget.onOpenAttendance,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _InboxCard(onOpen: widget.onOpen),
                    SizedBox(height: 16),
                    _TodayStaffCard(
                      fill: false,
                      onOpenAll: widget.onOpenAttendance,
                    ),
                  ],
                ] else
                  _HeroStatusCard(attendance: _summary?.attendance),
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
