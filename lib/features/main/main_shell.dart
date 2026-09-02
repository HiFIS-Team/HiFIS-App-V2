import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/header_action.dart';
import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/util/push.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/util/app_trail.dart';
import '../../core/widgets/nav/android_tab_bar.dart';
import '../../core/widgets/nav/app_tab_bar.dart';
import '../../core/widgets/nav/branch_scope_button.dart';
import '../../core/widgets/nav/lazy_indexed_stack.dart';
import '../approval/approval_screen.dart';
import '../attendance/attendance_qr_scan.dart';
import '../attendance/attendance_screen.dart';
import '../documents/document_screen.dart';
import '../home/home_screen.dart';
import '../meeting/meeting_screen.dart';
import '../member/member_screen.dart';
import '../messages/chat_store.dart';
import '../messages/desktop_chat_screen.dart';
import '../messages/message_screen.dart';
import '../monitoring/monitoring_screen.dart';
import '../notice/notice_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../project/project_screen.dart';
import '../work/my_task/my_task_miss_modal.dart';
import '../work/peer_review/peer_review_modal.dart';
import '../ranking/ranking_screen.dart';
import '../salary/salary_screen.dart';
import '../schedule/schedule_screen.dart';
import '../staff/staff_screen.dart';
import '../work/work_screen.dart';
import 'desktop_sidebar.dart';
import '../../core/theme/app_shadows.dart';

/// 하단 탭바와 탭별 화면을 관리하는 루트 셸
///
/// 2단 하단바 구조 (토스증권/애플뮤직 패턴):
/// - 메인 바: 홈 / 업무 / 프로젝트 / 회의록 / 전체
/// - "전체"를 누르면 서브 바로 전환: 뒤로 / 근태월차 / 급여 / 공지 / 랭킹
/// IndexedStack을 사용해 탭 전환 시에도 각 화면의 상태가 유지된다.
class MainShell extends StatefulWidget {
  MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    requestedScreen.addListener(_onRequestedScreen);
    PushGuard.tappedLink.addListener(_onPushTap);
    // 앱을 열 때 짚어 줄 것을 **한 장만** 띄운다.
    //
    // **여기서만 부른다** — `AppLifecycleState.resumed` 에 걸면 다른 창을 잠깐
    // 보고 돌아올 때마다 요청이 나간다 (홈에서 실제로 겪었다, macos.md 3번).
    //
    // **겹쳐 띄우지 않는다.** 셋이 겹치는 날이 있는데 그러면 X 를 세 번 눌러야
    // 하고, 안 닫고 나가면 다음에 또 그만큼 쌓인다. 차례는 **놓치면 되돌릴 수
    // 없는 순서**다.
    //
    // | 차례 | 왜 |
    // |---|---|
    // | 동료평가 | 창이 **이틀뿐**이다 — 지나면 못 낸다 (−20) |
    // | 업무 누락 | 다음 근무일까지는 만회할 수 있다 (−20) |
    // | 마감 임박 | 다음에 켤 때 그대로 뜬다 |
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 꺼져 있던 앱을 푸시로 켜면 셸이 뜨기 **전에** 링크가 도착해 있다
      _onPushTap();
      if (await showPeerReviewModal(context) || !mounted) return;
      if (await showMyTaskMissModal(context) || !mounted) return;
      await showProjectDueModal(context);
    });
  }

  @override
  void dispose() {
    requestedScreen.removeListener(_onRequestedScreen);
    PushGuard.tappedLink.removeListener(_onPushTap);
    super.dispose();
  }

  /// 푸시를 눌러서 들어왔다 — 알림함에서 누른 것과 같은 곳으로 보낸다
  void _onPushTap() {
    final link = PushGuard.tappedLink.value;
    if (link == null) return;
    PushGuard.tappedLink.value = null;
    goToNotificationLink(link);
  }

  /// 알림을 눌러 화면을 열어달라고 걸어 둔 요청을 처리한다.
  /// 비우면서 리스너가 한 번 더 돌지만 값이 null이라 바로 빠져나온다
  void _onRequestedScreen() {
    final target = requestedScreen.value;
    if (target == null) return;
    requestedScreen.value = null;
    // 데스크톱은 알림이 패널이라 목적지를 가린 채로 남는다
    _notiOpen.value = false;
    _go(target);
  }

  // 아이콘은 장식이 적은 심플한 심볼로 통일한다
  static const _mainSymbols = [
    'house.fill',
    'briefcase.fill',
    'folder.fill',
    'doc.fill',
    'square.grid.2x2.fill',
  ];

  // 서브 바의 0번은 메인 바로 돌아가는 뒤로가기.
  // 데스크톱 사이드바와 같은 모양 계열로 맞춘다 (급여=지폐, 랭킹=트로피)
  static const _subSymbols = [
    'chevron.backward',
    'clock.fill',
    'banknote.fill',
    'megaphone.fill',
    'trophy.fill',
  ];

  // static으로 두면 핫 리로드 시 페이지 교체가 반영되지 않아 getter로 만든다.
  // IndexedStack이 타입/위치 기준으로 상태를 유지하므로 매 빌드 생성해도 안전하다.
  List<Widget> get _mainPages => [
    HomeScreen(
      onOpenProjects: _goProjects,
      onOpenNotices: _goNotices,
      onOpen: _go,
      onOpenAttendance: () => _go(NotificationTarget.attendance),
    ),
    WorkScreen(),
    ProjectScreen(),
    MeetingScreen(),
  ];

  /// 홈 카드에서 프로젝트로 — 플랫폼마다 탭을 세는 방식이 달라 여기서 나눈다
  void _goProjects() => _go(NotificationTarget.project);

  /// 홈 카드에서 공지로 (폰은 서브 바 안에 있다)
  void _goNotices() => _go(NotificationTarget.notice);

  /// 화면 하나로 옮긴다 — 홈 카드와 알림이 같이 쓴다
  ///
  /// 같은 화면이라도 자리가 셋 다 다르다.
  /// - 데스크톱은 사이드바 순서(`_desktopPages`)
  /// - 안드로이드는 메인 4개 뒤에 서브 4개가 이어진 한 줄
  /// - 아이폰은 메인 바와 서브 바가 갈려서 둘 중 어디인지까지 정해야 한다
  void _go(NotificationTarget target) {
    // 사내톡은 탭이 아니라 **밀려 들어오는 화면**이다 — 어느 플랫폼이든
    // 목록을 띄우고, 그 화면이 `requestedRoomId` 를 집어 방까지 연다
    if (target == NotificationTarget.chat) {
      _goChat();
      return;
    }
    if (isDesktop) {
      // 슬라이드인 화면이 열려 있으면 덮고 있어서 먼저 닫는다
      _paneNavKey.currentState?.popUntil((r) => r.isFirst);
      _paneIndex.value = switch (target) {
        NotificationTarget.project => 3,
        NotificationTarget.work => 1,
        NotificationTarget.attendance => 9,
        NotificationTarget.salary => 10,
        NotificationTarget.notice => 11,
        NotificationTarget.ranking => 12,
        NotificationTarget.approval => 7,
        NotificationTarget.schedule => 4,
        NotificationTarget.meeting => 5,
        NotificationTarget.staff => 8,
        // 위에서 이미 처리했다
        NotificationTarget.chat => _paneIndex.value,
      };
      return;
    }

    // 폰에는 전자결재·일정·조직도 탭이 없다 — 갈 데가 없으면 아무 일도 안 한다
    if (target == NotificationTarget.approval ||
        target == NotificationTarget.schedule ||
        target == NotificationTarget.staff) {
      return;
    }

    if (!isApple) {
      setState(
        () => _androidTab = switch (target) {
          NotificationTarget.project => 2,
          NotificationTarget.work => 1,
          NotificationTarget.attendance => 4,
          NotificationTarget.salary => 5,
          NotificationTarget.notice => 6,
          NotificationTarget.ranking => 7,
          NotificationTarget.meeting => 3,
          NotificationTarget.approval => _androidTab,
          NotificationTarget.schedule => _androidTab,
          NotificationTarget.staff => _androidTab,
          NotificationTarget.chat => _androidTab, // 위에서 이미 처리했다
        },
      );
      return;
    }

    setState(() {
      switch (target) {
        case NotificationTarget.project:
          _subMenu = false;
          _mainIndex = 2;
        case NotificationTarget.work:
          _subMenu = false;
          _mainIndex = 1;
        case NotificationTarget.attendance:
          _subMenu = true;
          _subIndex = 1;
        case NotificationTarget.salary:
          _subMenu = true;
          _subIndex = 2;
        case NotificationTarget.notice:
          _subMenu = true;
          _subIndex = 3;
        case NotificationTarget.ranking:
          _subMenu = true;
          _subIndex = 4;
        case NotificationTarget.meeting:
          _subMenu = false;
          _mainIndex = 3;
        case NotificationTarget.approval:
        case NotificationTarget.schedule:
        case NotificationTarget.staff:
        case NotificationTarget.chat:
          break; // 위에서 걸러진다
      }
    });
  }

  /// 사내톡 열기 — 푸시를 눌러 들어왔을 때
  ///
  /// 폰은 목록을 밀어 올리고, 데스크톱은 전체보기를 띄운다 (우하단 필을 누른
  /// 것과 같은 화면이다). 어느 쪽이든 **그 화면이 방까지 연다**.
  ///
  /// 이미 열려 있으면 위에 하나 더 쌓지 않고 **맨 아래까지 닫고** 다시 연다 —
  /// 안 그러면 푸시를 누를 때마다 사내톡이 겹겹이 쌓인다.
  void _goChat() {
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => isDesktop ? DesktopChatScreen() : MessageScreen(),
      ),
    );
  }

  List<Widget> get _subPages => [
    AttendanceScreen(),
    SalaryScreen(),
    NoticeScreen(),
    RankingScreen(),
  ];

  bool _subMenu = false;
  int _mainIndex = 0;
  int _subIndex = 1;

  /// 탭·사이드바가 여는 화면의 한국어 이름 — **앱 사용 기록에 남는 이름이다**
  ///
  /// 순서가 위 목록들과 맞아야 한다. 어긋나면 엉뚱한 화면 이름이 기록된다.
  static const _phoneNames = [
    // 메인 바
    '홈', '업무', '프로젝트', '회의록',
    // 서브 바 (0번 뒤로가기는 화면이 아니라 뺀다)
    '근태·월차', '급여', '공지', '랭킹',
  ];
  static const _desktopNames = [
    '홈',
    '업무',
    '회원',
    '프로젝트',
    '일정',
    '회의록',
    '문서함',
    '결재',
    '조직도',
    '근태·월차',
    '급여',
    '공지',
    '랭킹',
    '모니터링',
  ];

  /// 화면을 열었다고 남긴다 — 목록 밖 번호면 조용히 넘어간다
  static void _trailScreen(List<String> names, int index) {
    if (index >= 0 && index < names.length) AppTrail.screen(names[index]);
  }

  void _onMainTap(int i) {
    if (i == _mainSymbols.length - 1) {
      // "전체" 탭 → 서브 바로 전환, 첫 서브 화면(근태월차)으로
      setState(() {
        _subMenu = true;
        _subIndex = 1;
      });
      _trailScreen(_phoneNames, _mainSymbols.length - 1);
    } else {
      setState(() => _mainIndex = i);
      _trailScreen(_phoneNames, i);
    }
  }

  void _onSubTap(int i) {
    if (i == 0) {
      // 뒤로가기 → 메인 바 복귀 (이전 탭 유지)
      setState(() => _subMenu = false);
      _trailScreen(_phoneNames, _mainIndex);
    } else {
      setState(() => _subIndex = i);
      // 서브 바는 메인 바(뒤로가기 뺀 4칸) 뒤에 이어 붙는다
      _trailScreen(_phoneNames, _mainSymbols.length - 1 + i - 1);
    }
  }

  // ── macOS 데스크톱 셸 ──

  /// 데스크톱 전용 페이지 목록 — DesktopSidebar의 섹션 펼친 순서와 일치해야 한다
  ///
  /// 맨 뒤 '접속 기록'은 MASTER·ADMIN 에게만 붙는다. 사이드바도 같은 조건으로
  /// 메뉴를 세우므로 **둘이 같은 판정을 써야** 인덱스가 안 어긋난다.
  List<Widget> get _desktopPages => [
    HomeScreen(
      onOpenProjects: _goProjects,
      onOpenNotices: _goNotices,
      onOpen: _go,
      // 오늘 출근 카드의 '전체' — 폰 카드에는 그 버튼이 없어 넘기지 않는다
      onOpenAttendance: () => _go(NotificationTarget.attendance),
    ),
    WorkScreen(),
    MemberScreen(),
    ProjectScreen(),
    ScheduleScreen(),
    MeetingScreen(),
    DocumentScreen(),
    ApprovalScreen(),
    StaffScreen(),
    AttendanceScreen(),
    SalaryScreen(),
    NoticeScreen(),
    RankingScreen(),
    if (MonitoringScreen.visible) MonitoringScreen(),
  ];

  /// 사이드바 선택 인덱스 (_desktopPages 순서 기준)
  final _paneIndex = ValueNotifier<int>(0);

  /// 헤더 알림 패널 열림 상태 (헤더 버튼과 패널 레이어가 함께 본다)
  final _notiOpen = ValueNotifier<bool>(false);

  /// 콘텐츠 영역 전용 내비게이터.
  /// 슬라이드인 화면이 사이드바를 덮지 않고 콘텐츠 안에서만 전환되게 한다.
  final _paneNavKey = GlobalKey<NavigatorState>();

  /// 데스크톱: 좌측 사이드바 + 넓은 콘텐츠 영역 (인스타그램 데스크톱 패턴)
  ///
  /// 사이드바가 펼쳐지고 접힐 때 콘텐츠도 함께 줄었다 늘어난다.
  Widget _buildDesktop() {
    return Scaffold(
      body: Row(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _paneIndex,
            builder: (context, index, child) => DesktopSidebar(
              selectedIndex: index,
              onSelect: (i) {
                // 열려 있는 슬라이드인 화면을 닫고 탭을 바꾼다
                _paneNavKey.currentState?.popUntil((r) => r.isFirst);
                _paneIndex.value = i;
                _trailScreen(_desktopNames, i);
              },
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.surface,
              child: ClipRect(
                child: Navigator(
                  key: _paneNavKey,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    settings: settings,
                    builder: (context) => ValueListenableBuilder<int>(
                      valueListenable: _paneIndex,
                      builder: (context, index, child) {
                        final pages = _desktopPages;
                        // 권한에 따라 메뉴 수가 달라진다 — 맨 뒤 '접속 기록'을
                        // 보던 사람이 로그아웃하면 인덱스가 목록 밖으로 나간다
                        final at = index < pages.length ? index : 0;
                        return Stack(
                          children: [
                            LazyIndexedStack(index: at, children: pages),
                            // 알림 패널 — 헤더 버튼보다 아래 레이어여야 한다.
                            // 위에 두면 패널 그림자가 네이티브 버튼 위를 덮어
                            // 오버레이가 생기면서 버튼 클릭이 먹지 않는다.
                            SafeArea(
                              bottom: false,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  // 종 버튼(오른쪽에서 16+40+10) 오른쪽 끝에 맞춘다
                                  padding: EdgeInsets.only(top: 60, right: 66),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _notiOpen,
                                    builder: (context, open, child) =>
                                        _FloatingPanel(
                                          open: open,
                                          alignment: Alignment.topRight,
                                          reserve: 24,
                                          // 패널은 닫혀도 트리에 남아서, 열림 상태를
                                          // 넘겨야 다시 열 때 새로 받는다
                                          child: NotificationScreen(
                                            embedded: true,
                                            active: open,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            _HeaderLeading(),
                            SafeArea(
                              bottom: false,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 8, right: 16),
                                  child: _HeaderButtons(notiOpen: _notiOpen),
                                ),
                              ),
                            ),
                            // 우하단 사내톡 플로팅 필 + 패널 (인스타그램 데스크톱 패턴)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.only(right: 20, bottom: 20),
                                child: _ChatDock(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 안드로이드 하단바에서 고른 탭 (0~3 메인, 4~7 서브)
  int _androidTab = 0;

  /// 안드로이드: 평평한 바 + 가운데 전체 버튼(반원 메뉴)
  Widget _buildAndroid() {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          LazyIndexedStack(
            index: _androidTab,
            children: [..._mainPages, ..._subPages],
          ),
          // 모든 탭 위에 떠 있는 공통 글래스 헤더
          _HeaderLeading(),
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
          // 하단바와 반원 메뉴 (딤이 화면 전체를 덮어야 해서 한 레이어로 둔다)
          Positioned.fill(
            child: AndroidTabBar(
              index: _androidTab,
              onSelect: (i) => setState(() => _androidTab = i),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktop();
    }
    if (!isApple) {
      return _buildAndroid();
    }
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          LazyIndexedStack(
            index: _subMenu ? _mainPages.length + (_subIndex - 1) : _mainIndex,
            children: [..._mainPages, ..._subPages],
          ),
          // 모든 탭 위에 떠 있는 공통 글래스 헤더
          _HeaderLeading(),
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
      bottomNavigationBar: _subMenu
          ? AppTabBar(
              symbols: _subSymbols,
              currentIndex: _subIndex,
              onTap: _onSubTap,
            )
          : AppTabBar(
              symbols: _mainSymbols,
              currentIndex: _mainIndex,
              onTap: _onMainTap,
            ),
    );
  }
}

/// 데스크톱 플로팅 패널 (사내톡·알림 공통)
///
/// 닫혀 있을 때도 자리는 차지하되 투명하게 두고 터치를 통과시킨다.
/// 열릴 때 [alignment] 기준으로 살짝 커지며 나타난다.
class _FloatingPanel extends StatelessWidget {
  _FloatingPanel({
    required this.open,
    required this.alignment,
    required this.child,
    this.height,
    this.reserve = 24,
  });

  final bool open;
  final Alignment alignment;
  final Widget child;

  /// 높이를 직접 줄 때 사용. 없으면 남는 공간에서 [reserve]를 뺀다.
  final double? height;

  /// 높이를 계산할 때 여백으로 남겨둘 크기
  final double reserve;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 창이 낮으면 패널도 함께 줄어든다
        final h =
            height ?? (constraints.maxHeight - reserve).clamp(240.0, 560.0);
        return IgnorePointer(
          ignoring: !open,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 200),
            opacity: open ? 1 : 0,
            child: AnimatedScale(
              duration: Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              scale: open ? 1 : 0.94,
              alignment: alignment,
              child: Container(
                width: 380,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gray100),
                  boxShadow: AppShadows.modal,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 데스크톱 우하단 사내톡 플로팅 필 + 패널
///
/// 인스타그램 데스크톱의 메시지 필과 같은 위치·역할이지만
/// 앱의 글래스 스타일(블러 + 반투명 surface + 헤어라인)로 그린다.
/// 누르면 사내톡 패널이 위로 떠오르고, 필은 줄어들며 X 버튼으로 바뀐다
/// (인스타그램은 필이 패널에 가려지는데 우리는 모프 애니메이션으로 대체).
class _ChatDock extends StatefulWidget {
  _ChatDock();

  @override
  State<_ChatDock> createState() => _ChatDockState();
}

class _ChatDockState extends State<_ChatDock> {
  bool _open = false;

  /// 패널을 닫고 콘텐츠 영역 전체를 쓰는 전체보기로 전환한다
  void _expand() {
    setState(() => _open = false);
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => DesktopChatScreen()),
    );
  }

  /// 아이콘 + `사내톡` + 좌우 여백만 있을 때의 폭
  static const double _pillBase = 94;

  /// 아바타 지름과 겹쳐 놓는 간격
  static const double _avatarSize = 24;
  static const double _avatarStep = 16;

  /// 필에 세우는 최근 대화 상대 수 — 넷째부터는 안 그린다
  static const int _maxPeople = 3;

  int get _peopleCount {
    final rooms = ChatStore.instance.rooms.length;
    return rooms < _maxPeople ? rooms : _maxPeople;
  }

  /// 펼친 필의 전체 폭 — 접힘(X 버튼) 폭은 높이와 같은 44
  ///
  /// **대화가 늘 때마다 아바타 하나만큼 늘어난다.** 하나도 없으면 아이콘과
  /// 글씨만 남아서 제일 좁고, 셋이 차면 158 로 예전 폭과 같아진다.
  double get _pillWidth {
    final people = _peopleCount;
    if (people == 0) return _pillBase;
    return _pillBase + 8 + _avatarSize + _avatarStep * (people - 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 창이 낮으면 패널 높이를 줄여 잘리지 않게 한다
        final panelHeight = (constraints.maxHeight - 84).clamp(240.0, 560.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 사내톡 패널 — 필 위로 떠오른다
            // (필 안의 배지·아바타가 스토어를 따라가야 해서 아래에서 듣는다)
            _FloatingPanel(
              open: _open,
              alignment: Alignment.bottomRight,
              height: panelHeight,
              // 패널 전용 내비게이터 — 채팅방·새 채팅 화면이
              // 콘텐츠 영역 전체가 아니라 패널 안에서 열린다
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: (_) =>
                      MessageScreen(embedded: true, onExpand: _expand),
                ),
              ),
            ),
            SizedBox(height: 12),
            // 새 메시지가 오면 필의 빨간 점·아바타가 바로 따라간다
            ListenableBuilder(
              listenable: ChatStore.instance,
              builder: (context, _) => _buildPill(),
            ),
          ],
        );
      },
    );
  }

  /// 사내톡 필 ↔ X 버튼 모프
  Widget _buildPill() {
    return Pressable(
      onTap: () => setState(() => _open = !_open),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.popup,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: _open ? 44 : _pillWidth,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.gray100),
              ),
              // 폭이 줄어드는 동안 안쪽 내용은 원래 크기를 유지한 채
              // 오른쪽 기준으로 잘려 나가야 자연스럽게 접힌다
              child: OverflowBox(
                minWidth: 0,
                maxWidth: _pillWidth,
                minHeight: 42,
                maxHeight: 42,
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _pillWidth,
                  height: 42,
                  child: Stack(
                    children: [
                      // 펼침: 아이콘 + 사내톡 + 아바타 (가로·세로 모두 가운데)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 150),
                          opacity: _open ? 0 : 1,
                          child: _pillContent(),
                        ),
                      ),
                      // 접힘: X (필의 오른쪽 끝 원 안에 자리한다)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 42,
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 150),
                          opacity: _open ? 1 : 0,
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.gray700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 필 아바타 색 — DM 은 상대 색, 그룹은 이름에서 만든 색
  Color _pillColor(ChatRoom room) =>
      chatRoomPeer(room)?.color ?? staffOf(chatRoomTitle(room)).color;

  Widget _pillContent() {
    // 최근 대화 상대 — 목록 맨 위에서 [_maxPeople] 개까지만 뽑는다
    final people = [
      for (final room in ChatStore.instance.rooms.take(_maxPeople))
        (chatRoomTitle(room).characters.first, _pillColor(room)),
    ];

    // 폭을 내용에 맞춰 잡으므로 남는 자리 없이 가운데에 선다.
    // 대화가 없으면 아이콘과 글씨만 남아 저절로 가운데 정렬된다.
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 17,
                color: AppColors.gray700,
              ),
              // 안 읽은 방이 있으면 빨간 점 — 알림 종과 같은 규칙
              if (ChatStore.instance.unreadRooms.value > 0)
                Positioned(
                  right: -3,
                  top: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 7),
          Text(
            '사내톡',
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          // 최근 대화 상대 아바타 겹침 스택 (대화가 없으면 안 그린다 —
          // 비어 있으면 폭이 음수가 된다)
          if (people.isNotEmpty) ...[
            SizedBox(width: 8),
            SizedBox(
              width: _avatarSize + _avatarStep * (people.length - 1),
              height: _avatarSize,
              child: Stack(
                children: [
                  for (var i = 0; i < people.length; i++)
                    Positioned(
                      left: i * _avatarStep,
                      child: Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          color: people[i].$2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            people[i].$1,
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 상단 우측 글래스 버튼 묶음 (모든 탭 공통)
///
/// 바코드 오버레이가 떠 있는 동안에는 버튼 모양은 그대로 두고
/// 터치만 비활성화한다. 글래스 눌림 효과가 딤 위로 그려지는 것을 막기 위함.
/// 화면이 끼워 넣는 버튼 — **화면 왼쪽 끝**에 선다
///
/// 오른쪽 뭉치(`_HeaderButtons`)와 **다른 레이어**다. 그 Row 는
/// `Align(topRight)` 라, 거기에 아무리 앞에 넣어도 오른쪽 뭉치의 왼쪽일 뿐
/// 화면 왼쪽 끝이 아니다 (그렇게 만들었다가 고쳤다 — 2026-08-14).
///
/// 값은 [headerAction] 이 들고, 업무 화면이 탭마다 갈아 끼운다.
///
/// **여럿이 설 수 있다** (2026-09-02) — 수업 개수 탭이 회원 목록과 운동 일지를
/// 나란히 세운다. `stableId` 에 자리 번호를 붙여야 네이티브 버튼이 서로
/// 안 섞인다 (같은 값이면 심볼만 바뀌고 둘이 한 버튼으로 보인다).
class _HeaderLeading extends StatelessWidget {
  _HeaderLeading();

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Align(
      alignment: Alignment.topLeft,
      // 오른쪽 뭉치와 같은 높이·같은 여백 (top 8 · 가장자리 16)
      child: Padding(
        padding: EdgeInsets.only(top: 8, left: 16),
        child: ValueListenableBuilder<List<HeaderAction>>(
          valueListenable: headerAction,
          builder: (context, actions, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                // 오른쪽 뭉치와 같은 간격
                if (i > 0) SizedBox(width: 10),
                GlassIconButton(
                  symbol: actions[i].symbol,
                  stableId: 'header-leading-$i',
                  onPressed: actions[i].onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _HeaderButtons extends StatefulWidget {
  _HeaderButtons({this.notiOpen});

  /// 데스크톱 알림 패널 열림 상태. null이면(폰) 알림을 화면 전환으로 연다.
  final ValueNotifier<bool>? notiOpen;

  @override
  State<_HeaderButtons> createState() => _HeaderButtonsState();
}

class _HeaderButtonsState extends State<_HeaderButtons> {
  bool _overlayOpen = false;

  /// 카운터 QR 을 찍는다 (2026-08-28)
  ///
  /// 예전에는 **자기 바코드를 띄우는 창**이었다. 카운터 스캐너가 그걸 읽었는데
  /// 그 기계를 걷어내면서 띄울 이유가 없어졌다 — 이제 바로 카메라가 열린다.
  Future<void> _openScan() async {
    setState(() => _overlayOpen = true);
    await showAttendanceQrScan(context);
    if (mounted) setState(() => _overlayOpen = false);
  }

  /// 알림 버튼 — 데스크톱은 화면 전환 대신 패널을 열고 종이 X로 바뀐다
  ///
  /// 빨간 점은 **안 읽은 알림이 있을 때만** 뜬다. 한동안 늘 켜둔 채였는데,
  /// 그러면 눌러서 다 읽어도 그대로라 배지가 아무 뜻이 없었다.
  Widget _bell() {
    final noti = widget.notiOpen;
    if (noti == null) {
      return ValueListenableBuilder<int>(
        valueListenable: unreadNotifications,
        builder: (context, unread, child) => GlassIconButton(
          symbol: 'bell',
          showBadge: unread > 0,
          enabled: !_overlayOpen,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => NotificationScreen()),
          ),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: noti,
      builder: (context, open, child) => ValueListenableBuilder<int>(
        valueListenable: unreadNotifications,
        builder: (context, unread, child) => GlassIconButton(
          // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
          stableId: 'noti',
          symbol: open ? 'xmark' : 'bell',
          showBadge: !open && unread > 0,
          enabled: !_overlayOpen,
          onPressed: () => noti.value = !noti.value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 출퇴근 QR 은 매장 카운터에서 폰으로 찍는 것이라 데스크톱에서는 뺀다.
    //
    // **MASTER·ADMIN 에게도 안 보인다.** 출퇴근을 찍는 건 현장에서 일하는
    // 사람(MANAGER·MEMBER)이고, 대표·관리자는 운영 전담이라 스캔할 일이 없다.
    // 데스크톱이 원래 그랬는데 폰만 전원에게 떠 있었다.
    final desktop = isDesktop;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!desktop) ...[
          if (myRole.doesFieldWork) ...[
            GlassIconButton(
              // 심볼은 그대로 둔다 — 찍는다는 뜻이 QR 에도 그대로 맞고,
              // 자리를 외운 사람에게 아이콘이 바뀌면 못 찾는다
              symbol: 'barcode.viewfinder',
              enabled: !_overlayOpen,
              onPressed: _openScan,
            ),
            SizedBox(width: 10),
          ],
          // 지점 고르개 — 바코드 **다음 자리**다.
          //
          // MASTER·ADMIN 은 바코드가 없어서 이 줄의 맨 앞이 되고,
          // MANAGER 는 바코드 오른쪽에 나란히 선다 (둘 다 해당되는 유일한 권한).
          // MEMBER 는 아예 안 뜬다.
          //
          // 예전에는 업무·랭킹이 화면 안에 각자 고르개를 갖고 있었다. 그러면
          // 옆 화면으로 옮길 때 값이 초기화되고 둘이 서로 다른 지점을 가리켰다.
          if (branchScopeVisible) ...[
            BranchScopeButton(enabled: !_overlayOpen),
            SizedBox(width: 10),
          ],
          // 데스크톱은 우하단 사내톡 필이 있어 헤더 메시지 버튼을 뺀다.
          // 빨간 점은 알림 종과 같은 규칙 — 안 읽은 방이 있을 때만 뜬다
          ValueListenableBuilder<int>(
            valueListenable: ChatStore.instance.unreadRooms,
            builder: (context, unread, child) => GlassIconButton(
              symbol: 'message',
              showBadge: unread > 0,
              enabled: !_overlayOpen,
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => MessageScreen()),
              ),
            ),
          ),
          SizedBox(width: 10),
        ],
        // 지점 고르개 — 조직도·업무·랭킹이 같이 보는 값이라 화면마다 두지 않고
        // 여기 하나만 둔다. **MASTER·ADMIN 에게만, 데스크톱에서만** 뜬다
        // (폰은 업무 화면이 제 왼쪽 위에 따로 띄운다).
        if (desktop && branchScopeVisible) ...[
          BranchScopeButton(enabled: !_overlayOpen),
          SizedBox(width: 10),
        ],
        _bell(),
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
