import 'package:flutter/material.dart';

import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../home/home_screen.dart';

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
    PlaceholderScreen(emoji: '💼', title: '업무'),
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
      body: IndexedStack(
        index: _subMenu ? _mainPages.length + (_subIndex - 1) : _mainIndex,
        children: [..._mainPages, ..._subPages],
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
