import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

/// 하단 탭바 (iOS 26 리퀴드 글래스)
///
/// cupertino_native의 CNTabBar로 실제 네이티브 UITabBar를 호스팅한다.
/// symbols가 바뀌면 네이티브 바의 아이템도 그대로 교체된다(2단 하단바 전환용).
/// Scaffold에서 `extendBody: true`와 함께 사용해야 콘텐츠가 뒤로 비쳐 보인다.
class AppTabBar extends StatelessWidget {
  AppTabBar({
    super.key,
    required this.symbols,
    this.currentIndex = 0,
    this.onTap,
  });

  /// 각 탭의 SF Symbol 이름 (라벨 없이 아이콘만 표시)
  final List<String> symbols;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return CNTabBar(
      items: [
        for (final symbol in symbols)
          CNTabBarItem(label: '', icon: CNSymbol(symbol)),
      ],
      currentIndex: currentIndex,
      onTap: (i) => onTap?.call(i),
    );
  }
}
