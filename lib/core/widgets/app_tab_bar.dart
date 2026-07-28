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
    return CNTabBar(
      items: const [
        CNTabBarItem(label: '홈', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: '직원', icon: CNSymbol('person.2.fill')),
        CNTabBarItem(label: '일정', icon: CNSymbol('calendar')),
        CNTabBarItem(label: '내 정보', icon: CNSymbol('person.crop.circle.fill')),
      ],
      currentIndex: currentIndex,
      onTap: (i) => onTap?.call(i),
    );
  }
}
