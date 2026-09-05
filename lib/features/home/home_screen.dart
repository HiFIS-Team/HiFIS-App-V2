import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/docs/approval_api.dart';
import '../../core/api/home/home_api.dart';
import '../../core/api/project/event_api.dart';
import '../../core/api/project/project_api.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/api/staff/payroll_api.dart';
import '../../core/api/work/kindness_api.dart';
import '../../core/api/work/my_task_api.dart';
import '../../core/data/data_signal.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/screen_refresh.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/mini_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../approval/approval_screen.dart';
import '../member/member_screen.dart';
import '../notice/notice_screen.dart';
import '../notifications/notification_screen.dart';
import '../project/project_screen.dart';
import '../schedule/schedule_screen.dart';
import '../../core/widgets/feedback/skeleton.dart';
part 'home_inbox.dart';
part 'home_staff.dart';
part 'home_status.dart';
part 'home_cards.dart';

/// 폰 홈 카드 본문의 **최소** 높이 — 내용이 없다고 카드가 줄지 않게 한다
///
/// 네 장(결재 대기·오늘 출근·프로젝트·공지)이 세로로 쌓이는데 한 장만 짧으면
/// 화면이 들쭉날쭉해 보인다. 그래서 늘 세 줄이 들어갈 만큼을 잡아 둔다.
/// 줄 하나가 약 42(이름 15×1.5 + 1 + 직군 13×1.4), 줄 사이가 14 → 42×3 + 14×2.
///
/// **최소값이라 줄이 더 높거나 많으면 카드가 따라 커진다** (넘치지 않는다).
/// 데스크톱은 두 장을 나란히 놓고 `IntrinsicHeight` 로 맞추므로 안 쓴다.
const phoneCardBody = 154.0;

/// 폰 홈 카드에 세우는 줄 수 — 네 장이 같아야 나란히 놓았을 때 안 어긋난다
const phoneCardRows = 3;

/// PC 홈 카드 **한 쌍**의 최소 높이 — 안이 비어도 네모가 안 줄어든다
///
/// PC 는 네 장을 두 장씩 두 줄로 놓고 `IntrinsicHeight` 로 높이를 맞춘다.
/// 그래서 **한 쌍이 둘 다 비면 그 줄이 통째로 쪼그라든다** — 개발 서버에서는
/// 값이 있어 안 보이다가 앱을 깔고 보니 확 줄어 있었다 (실제로 겪었다).
///
/// 값은 네 줄이 다 찼을 때의 높이다 — 카드 여백 40 · 머리말 24 ·
/// 머리말 아래 14 · 줄 42×4 + 줄 사이 14×3.
///
/// **최소값이라 줄이 더 많으면 카드는 따라 커진다** ([phoneCardBody] 와 같은 뜻).
const desktopCardPair = 290.0;

/// 홈 화면 — 모든 직원이 처음 보는 화면
///
/// 오늘 근무는 `/me/home` 에서 온다. 지점 집계인 `/dashboard` 와 달리
/// 권한 없이 본인 것만 주는 요약이라 직군에 상관없이 열린다.
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

class _HomeScreenState extends State<HomeScreen>
    with ScreenRefresh<HomeScreen> {
  /// 오늘 요약 — 도착 전에는 null 이라 근무 카드가 '미출근'으로 그려진다
  ///
  /// 첫 화면이라 통째로 로딩을 돌리면 앱을 열 때마다 빈 화면을 보게 된다.
  /// 인사말·시계는 기기에서 바로 나오므로 그대로 두고 값만 채운다.
  HomeSummary? _summary;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  ///
  /// **다른 탭 11개와 같은 장치를 쓴다** (2026-08-14). 예전에는 홈만
  /// `WidgetsBindingObserver` 로 직접 재조회했는데, 그러면 **탭을 옮겼다
  /// 돌아와도 안 받아서** 다른 탭에서 결재한 것이 홈 숫자에 안 비쳤다.
  ///
  /// 최소 간격은 믹스인이 들고 있다 (`screenRefreshGap`, 1분). macOS 가
  /// 창 포커스만 잃어도 오가는 문제도 거기서 같이 막힌다 (`apple/macos.md` 3번).
  @override
  Future<void> onScreenRefresh() => _load();

  /// 결재 대기 카드가 여섯 갈래를 다 세운다
  @override
  List<ValueNotifier<int>> get watchSignals => [
    attendanceChanged,
    approvalChanged,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (currentUser == null) return;
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

  void _open(Widget screen) =>
      Navigator.push(context, CupertinoPageRoute(builder: (_) => screen));

  /// 폰 홈 왼쪽 위 바로가기 — 일정 · 전자결재 · 회원
  ///
  /// **폰에는 이 둘의 탭이 없다** (`MainShell._go` 가 갈 데가 없어 그냥 돌아온다).
  /// 데스크톱은 사이드바에 메뉴가 있어서 안 그린다.
  /// 셸 헤더 버튼이 오른쪽 위를 쓰고 있어 왼쪽이 비어 있다.
  ///
  /// **회원은 여기로 돌려놨다** (2026-09-06 요청) — 8월 31일에 업무 탭
  /// '수업 개수' 안으로 넣었더니 홈에서 회원한테 닿는 길이 사라졌다.
  /// 운동일지·개인 운동·영양제가 다 그 화면 안에 있어서 제일 자주 여는 곳이다.
  Widget _shortcuts() => SafeArea(
    bottom: false,
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 8, left: 16),
        child: Row(
          children: [
            GlassIconButton(
              symbol: 'calendar',
              onPressed: () => _open(ScheduleScreen()),
            ),
            SizedBox(width: 10),
            GlassIconButton(
              symbol: 'checkmark.seal',
              onPressed: () => _open(ApprovalScreen()),
            ),
            SizedBox(width: 10),
            GlassIconButton(
              symbol: 'person.2',
              onPressed: () => _open(MemberScreen()),
            ),
          ],
        ),
      ),
    ),
  );

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
                if (myRole.boss) ...[
                  if (desktop)
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: desktopCardPair),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _InboxCard(onOpen: widget.onOpen)),
                            SizedBox(width: 16),
                            Expanded(
                              child: _TodayStaffCard(
                                onOpenAll: widget.onOpenAttendance,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _InboxCard(onOpen: widget.onOpen),
                    SizedBox(height: 16),
                    _TodayStaffCard(onOpenAll: widget.onOpenAttendance),
                  ],
                ] else
                  _HeroStatusCard(attendance: _summary?.attendance),
                SizedBox(height: 16),
                if (desktop)
                  // 두 카드의 높이를 큰 쪽에 맞추고, 둘 다 비어도 안 줄어들게 한다
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: desktopCardPair),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ProjectsCard(
                              count: 5,
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
          // 홈에서만 보이는 바로가기 — 다른 탭에는 안 붙는다
          if (!desktop) _shortcuts(),
        ],
      ),
    );
  }
}
