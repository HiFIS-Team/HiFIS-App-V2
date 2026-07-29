import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/app_tab_bar.dart';
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
  static const _mainSymbols = [
    'house.fill',
    'briefcase.fill',
    'folder.fill',
    'doc.text.fill',
    'square.grid.2x2.fill',
  ];

  // 서브 바의 0번은 메인 바로 돌아가는 뒤로가기
  static const _subSymbols = [
    'chevron.backward',
    'calendar.badge.clock',
    'wonsign.circle.fill',
    'megaphone.fill',
    'trophy.fill',
  ];

  static final _mainPages = [
    HomeScreen(),
    WorkScreen(),
    PlaceholderScreen(emoji: '📁', title: '프로젝트'),
    PlaceholderScreen(emoji: '📝', title: '회의록'),
  ];

  static final _subPages = [
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

  @override
  Widget build(BuildContext context) {
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
