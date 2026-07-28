import 'package:flutter/material.dart';

import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../home/home_screen.dart';

/// 하단 탭바와 탭별 화면을 관리하는 루트 셸
///
/// IndexedStack을 사용해 탭 전환 시에도 각 화면의 상태가 유지된다.
/// 탭 순서: 홈 / 업무 / 프로젝트 / 회의록 / 전체 (AppTabBar와 동일)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    PlaceholderScreen(emoji: '💼', title: '업무'),
    PlaceholderScreen(emoji: '📁', title: '프로젝트'),
    PlaceholderScreen(emoji: '📝', title: '회의록'),
    PlaceholderScreen(emoji: '🗂️', title: '전체'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AppTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
