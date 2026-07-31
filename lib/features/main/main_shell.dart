import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/android_tab_bar.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/pressable.dart';
import 'desktop_sidebar.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/lazy_indexed_stack.dart';
import '../approval/approval_screen.dart';
import '../documents/document_screen.dart';
import '../attendance/attendance_barcode_overlay.dart';
import '../attendance/attendance_screen.dart';
import '../home/home_screen.dart';
import '../meeting/meeting_screen.dart';
import '../messages/desktop_chat_screen.dart';
import '../work/work_screen.dart';
import '../messages/message_screen.dart';
import '../notice/notice_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../project/project_screen.dart';
import '../schedule/schedule_screen.dart';
import '../salary/salary_screen.dart';
import '../staff/staff_screen.dart';

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
    HomeScreen(onOpenProjects: _goProjects, onOpenNotices: _goNotices),
    WorkScreen(),
    ProjectScreen(),
    MeetingScreen(),
  ];

  /// 홈 카드에서 프로젝트로 — 플랫폼마다 탭을 세는 방식이 달라 여기서 나눈다
  void _goProjects() {
    if (isDesktop) {
      _paneIndex.value = 2;
    } else if (!isApple) {
      setState(() => _androidTab = 2);
    } else {
      setState(() {
        _subMenu = false;
        _mainIndex = 2;
      });
    }
  }

  /// 홈 카드에서 공지로 (폰은 서브 바 안에 있다)
  void _goNotices() {
    if (isDesktop) {
      _paneIndex.value = 10;
    } else if (!isApple) {
      setState(() => _androidTab = 6);
    } else {
      setState(() {
        _subMenu = true;
        _subIndex = 3;
      });
    }
  }

  List<Widget> get _subPages => [
    AttendanceScreen(),
    SalaryScreen(),
    NoticeScreen(),
    PlaceholderScreen(emoji: '🏆', title: '랭킹'),
  ];

  bool _subMenu = false;
  int _mainIndex = 0;
  int _subIndex = 1;

  void _onMainTap(int i) {
    if (i == _mainSymbols.length - 1) {
      // "전체" 탭 → 서브 바로 전환, 첫 서브 화면(근태월차)으로
      setState(() {
        _subMenu = true;
        _subIndex = 1;
      });
    } else {
      setState(() => _mainIndex = i);
    }
  }

  void _onSubTap(int i) {
    if (i == 0) {
      // 뒤로가기 → 메인 바 복귀 (이전 탭 유지)
      setState(() => _subMenu = false);
    } else {
      setState(() => _subIndex = i);
    }
  }

  // ── macOS 데스크톱 셸 ──

  /// 데스크톱 전용 페이지 목록 — DesktopSidebar의 섹션 펼친 순서와 일치해야 한다
  List<Widget> get _desktopPages => [
    HomeScreen(onOpenProjects: _goProjects, onOpenNotices: _goNotices),
    WorkScreen(),
    ProjectScreen(),
    ScheduleScreen(),
    MeetingScreen(),
    DocumentScreen(),
    ApprovalScreen(),
    StaffScreen(),
    AttendanceScreen(),
    SalaryScreen(),
    NoticeScreen(),
    PlaceholderScreen(emoji: '🏆', title: '랭킹'),
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
                      builder: (context, index, child) => Stack(
                        children: [
                          LazyIndexedStack(
                            index: index,
                            children: _desktopPages,
                          ),
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
                                        child: NotificationScreen(
                                          embedded: true,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
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
                      ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ],
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

  /// 펼친 필의 전체 폭 — 접힘(X 버튼) 폭은 높이와 같은 44
  static const double _pillWidth = 158;

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
            _buildPill(),
          ],
        );
      },
    );
  }

  /// 사내톡 필 ↔ X 버튼 모프
  Widget _buildPill() {
    return Pressable(
      scale: 0.95,
      onTap: () => setState(() => _open = !_open),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
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
                      // 펼침: 아이콘 + 사내톡 + 아바타 (세로 가운데 정렬)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 150),
                          opacity: _open ? 0 : 1,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(14, 0, 10, 0),
                            child: _pillContent(),
                          ),
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

  Widget _pillContent() {
    // 사내톡 목업의 최근 대화 상대 3명 (기능 연동 시 실제 데이터로 교체)
    final people = [
      ('민', AppColors.primary),
      ('김', AppColors.warning),
      ('유', AppColors.success),
    ];

    return Row(
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 17,
          color: AppColors.gray700,
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
        Spacer(),
        // 최근 대화 상대 아바타 겹침 스택
        SizedBox(
          width: 24.0 + 16 * (people.length - 1),
          height: 24,
          child: Stack(
            children: [
              for (var i = 0; i < people.length; i++)
                Positioned(
                  left: i * 16.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: people[i].$2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
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
    );
  }
}

/// 상단 우측 글래스 버튼 묶음 (모든 탭 공통)
///
/// 바코드 오버레이가 떠 있는 동안에는 버튼 모양은 그대로 두고
/// 터치만 비활성화한다. 글래스 눌림 효과가 딤 위로 그려지는 것을 막기 위함.
class _HeaderButtons extends StatefulWidget {
  _HeaderButtons({this.notiOpen});

  /// 데스크톱 알림 패널 열림 상태. null이면(폰) 알림을 화면 전환으로 연다.
  final ValueNotifier<bool>? notiOpen;

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

  /// 알림 버튼 — 데스크톱은 화면 전환 대신 패널을 열고 종이 X로 바뀐다
  Widget _bell() {
    final noti = widget.notiOpen;
    if (noti == null) {
      return GlassIconButton(
        symbol: 'bell',
        showBadge: true,
        enabled: !_overlayOpen,
        onPressed: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => NotificationScreen()),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: noti,
      builder: (context, open, child) => GlassIconButton(
        // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
        stableId: 'noti',
        symbol: open ? 'xmark' : 'bell',
        showBadge: !open,
        enabled: !_overlayOpen,
        onPressed: () => noti.value = !noti.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 출퇴근 바코드는 폰을 직원 리더기에 찍는 용도라 데스크톱에서는 뺀다
    final desktop = isDesktop;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!desktop) ...[
          GlassIconButton(
            symbol: 'barcode.viewfinder',
            enabled: !_overlayOpen,
            onPressed: _openBarcode,
          ),
          SizedBox(width: 10),
          // 데스크톱은 우하단 사내톡 필이 있어 헤더 메시지 버튼을 뺀다
          GlassIconButton(
            symbol: 'message',
            enabled: !_overlayOpen,
            onPressed: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => MessageScreen()),
            ),
          ),
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
