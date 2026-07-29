import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/pressable.dart';

/// macOS 데스크톱용 좌측 사이드바 내비게이션 (ChatGPT 데스크톱 패턴)
///
/// 폰의 2단 하단바(메인 바 + "전체" 서브 바)를 한 줄로 펼쳐서 보여준다.
/// 인덱스 0~3은 메인 탭, 4~7은 서브 탭 페이지에 대응한다.
class DesktopSidebar extends StatelessWidget {
  DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static final List<(IconData, String)> _mainItems = [
    (CupertinoIcons.house_fill, '홈'),
    (CupertinoIcons.briefcase_fill, '업무'),
    (CupertinoIcons.folder_fill, '프로젝트'),
    (CupertinoIcons.doc_text_fill, '회의록'),
  ];

  static final List<(IconData, String)> _subItems = [
    (CupertinoIcons.calendar, '근태·월차'),
    (CupertinoIcons.money_dollar_circle_fill, '급여'),
    (Icons.campaign_rounded, '공지'),
    (Icons.emoji_events_rounded, '랭킹'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.gray100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/hifis_mark.png',
                  height: 22,
                  cacheHeight: 66,
                ),
                SizedBox(width: 8),
                Text(
                  'HiFIS',
                  style: AppTextStyles.title3.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          for (var i = 0; i < _mainItems.length; i++) _item(i, _mainItems[i]),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Container(height: 1, color: AppColors.gray100),
          ),
          for (var i = 0; i < _subItems.length; i++)
            _item(_mainItems.length + i, _subItems[i]),
        ],
      ),
    );
  }

  Widget _item(int index, (IconData, String) item) {
    final selected = index == selectedIndex;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Pressable(
        scale: 0.97,
        pressedColor: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                item.$1,
                size: 19,
                color: selected ? AppColors.primary : AppColors.gray500,
              ),
              SizedBox(width: 10),
              Text(
                item.$2,
                style: AppTextStyles.label.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
