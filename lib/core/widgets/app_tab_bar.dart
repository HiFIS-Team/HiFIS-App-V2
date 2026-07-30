import 'dart:ui';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../util/sf_symbols.dart';
import 'pressable.dart';

/// 하단 탭바 (iOS 26 리퀴드 글래스)
///
/// cupertino_native의 CNTabBar로 실제 네이티브 UITabBar를 호스팅한다.
/// symbols가 바뀌면 네이티브 바의 아이템도 그대로 교체된다(2단 하단바 전환용).
/// Scaffold에서 `extendBody: true`와 함께 사용해야 콘텐츠가 뒤로 비쳐 보인다.
///
/// 애플이 아닌 플랫폼에서는 패키지가 아이콘을 빈 원으로 대체해버려서,
/// 같은 모양의 떠 있는 글래스 바를 Flutter로 직접 그린다.
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
    if (!isApple) {
      return _FallbackTabBar(
        symbols: symbols,
        currentIndex: currentIndex,
        onTap: onTap,
      );
    }
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

/// 네이티브 탭바를 못 쓰는 플랫폼용 — 블러 + 반투명 알약 바
class _FallbackTabBar extends StatelessWidget {
  _FallbackTabBar({
    required this.symbols,
    required this.currentIndex,
    this.onTap,
  });

  final List<String> symbols;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < symbols.length; i++) _item(i),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final selected = index == currentIndex;
    return Pressable(
      scale: 0.9,
      onTap: () => onTap?.call(index),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconForSymbol(symbols[index]),
              size: 22,
              color: selected ? AppColors.primary : AppColors.gray400,
            ),
          ),
        ),
      ),
    );
  }
}
