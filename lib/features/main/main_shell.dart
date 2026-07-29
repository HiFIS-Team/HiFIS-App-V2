import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_tab_bar.dart';
import 'desktop_sidebar.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../attendance/attendance_barcode_overlay.dart';
import '../home/home_screen.dart';
import '../work/work_screen.dart';
import '../messages/message_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';

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

  // 서브 바의 0번은 메인 바로 돌아가는 뒤로가기
  static const _subSymbols = [
    'chevron.backward',
    'clock.fill',
    'wonsign.circle.fill',
    'megaphone.fill',
    'chart.bar.fill',
  ];

  // static으로 두면 핫 리로드 시 페이지 교체가 반영되지 않아 getter로 만든다.
  // IndexedStack이 타입/위치 기준으로 상태를 유지하므로 매 빌드 생성해도 안전하다.
  List<Widget> get _mainPages => [
    HomeScreen(),
    WorkScreen(),
    PlaceholderScreen(emoji: '📁', title: '프로젝트'),
    PlaceholderScreen(emoji: '📝', title: '회의록'),
  ];

  List<Widget> get _subPages => [
    PlaceholderScreen(emoji: '🗓️', title: '근태·월차'),
    PlaceholderScreen(emoji: '💰', title: '급여'),
    PlaceholderScreen(emoji: '📣', title: '공지'),
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
    HomeScreen(),
    WorkScreen(),
    PlaceholderScreen(emoji: '📁', title: '프로젝트'),
    PlaceholderScreen(emoji: '📅', title: '일정'),
    PlaceholderScreen(emoji: '📝', title: '회의록'),
    PlaceholderScreen(emoji: '🗂️', title: '문서함'),
    PlaceholderScreen(emoji: '✅', title: '전자결재'),
    PlaceholderScreen(emoji: '👥', title: '직원'),
    PlaceholderScreen(emoji: '🗓️', title: '근태·월차'),
    PlaceholderScreen(emoji: '💰', title: '급여'),
    PlaceholderScreen(emoji: '📣', title: '공지'),
    PlaceholderScreen(emoji: '🏆', title: '랭킹'),
  ];

  /// 사이드바 선택 인덱스 (_desktopPages 순서 기준)
  final _paneIndex = ValueNotifier<int>(0);

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
                          IndexedStack(index: index, children: _desktopPages),
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

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _buildDesktop();
    }
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
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

/// 상단 우측 글래스 버튼 묶음 (모든 탭 공통)
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
    // 출퇴근 바코드는 폰을 직원 리더기에 찍는 용도라 데스크톱에서는 뺀다
    final desktop = defaultTargetPlatform == TargetPlatform.macOS;
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
        ],
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
