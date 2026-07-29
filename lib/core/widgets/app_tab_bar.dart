import 'dart:ui';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// 하단 탭바 (iOS 26 리퀴드 글래스)
///
/// cupertino_native의 CNTabBar로 실제 네이티브 UITabBar를 호스팅한다.
/// symbols가 바뀌면 네이티브 바의 아이템도 그대로 교체된다(2단 하단바 전환용).
/// Scaffold에서 `extendBody: true`와 함께 사용해야 콘텐츠가 뒤로 비쳐 보인다.
///
/// macOS에서는 네이티브 바가 깨져 보여서(검은 사각형 아이콘)
/// Flutter로 직접 그린 플로팅 탭바로 대체한다.
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
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _DesktopTabBar(
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

/// macOS용 플로팅 탭바 — 글래스 검색바와 같은 재질(블러 + 반투명 surface)의
/// 알약 모양 바를 가운데 띄우고, 선택 탭은 파란 원으로 표시한다.
class _DesktopTabBar extends StatelessWidget {
  _DesktopTabBar({
    required this.symbols,
    required this.currentIndex,
    this.onTap,
  });

  final List<String> symbols;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// SF Symbol 이름 → Flutter 아이콘 대응표 (탭바에서 쓰는 것만)
  static final Map<String, IconData> _icons = {
    'house.fill': CupertinoIcons.house_fill,
    'briefcase.fill': CupertinoIcons.briefcase_fill,
    'folder.fill': CupertinoIcons.folder_fill,
    'doc.text.fill': CupertinoIcons.doc_text_fill,
    'square.grid.2x2.fill': CupertinoIcons.square_grid_2x2_fill,
    'chevron.backward': CupertinoIcons.chevron_back,
    'calendar.badge.clock': CupertinoIcons.calendar,
    'wonsign.circle.fill': CupertinoIcons.money_dollar_circle_fill,
    'megaphone.fill': Icons.campaign_rounded,
    'trophy.fill': Icons.emoji_events_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
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
                      for (var i = 0; i < symbols.length; i++)
                        _item(i, symbols[i]),
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

  Widget _item(int index, String symbol) {
    final selected = index == currentIndex;
    return Pressable(
      scale: 0.9,
      onTap: () => onTap?.call(index),
      child: SizedBox(
        width: 52,
        height: 54,
        child: Center(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icons[symbol] ?? CupertinoIcons.circle,
              size: 21,
              color: selected ? AppColors.primary : AppColors.gray400,
            ),
          ),
        ),
      ),
    );
  }
}
