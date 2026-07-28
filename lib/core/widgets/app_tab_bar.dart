import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

/// 하단 탭바 (iOS 26 리퀴드 글래스)
///
/// cupertino_native의 CNTabBar로 실제 네이티브 UITabBar를 호스팅한다.
/// Scaffold에서 `extendBody: true`와 함께 사용해야 콘텐츠가 뒤로 비쳐 보인다.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, this.currentIndex = 0, this.onTap});

  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    // 탭 순서: 홈 / 업무 / 프로젝트 / 회의록 / 전체 (라벨 없이 아이콘만 표시)
    return CNTabBar(
      items: const [
        CNTabBarItem(label: '', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: '', icon: CNSymbol('briefcase.fill')),
        CNTabBarItem(label: '', icon: CNSymbol('folder.fill')),
        CNTabBarItem(label: '', icon: CNSymbol('doc.text.fill')),
        CNTabBarItem(label: '', icon: CNSymbol('square.grid.2x2.fill')),
      ],
      currentIndex: currentIndex,
      onTap: (i) => onTap?.call(i),
    );
  }
}
