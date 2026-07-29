import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/pressable.dart';

/// macOS 데스크톱용 좌측 사이드바 내비게이션 (ChatGPT 데스크톱 패턴)
///
/// 메뉴를 성격별 섹션(업무/문서/직원/소식)으로 묶어서 보여준다.
/// 선택 인덱스는 섹션을 펼친 순서(0부터)이며,
/// MainShell의 `_desktopPages` 순서와 반드시 일치해야 한다.
class DesktopSidebar extends StatelessWidget {
  DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// (섹션 제목, 메뉴 목록) — 제목이 null이면 캡션 없이 그린다
  static final List<(String?, List<(IconData, String)>)> _sections = [
    (null, [(CupertinoIcons.house_fill, '홈')]),
    (
      '업무',
      [
        (CupertinoIcons.briefcase_fill, '업무'),
        (CupertinoIcons.folder_fill, '프로젝트'),
        (CupertinoIcons.calendar, '일정'),
        (CupertinoIcons.doc_text_fill, '회의록'),
      ],
    ),
    (
      '문서',
      [
        (CupertinoIcons.tray_full_fill, '문서함'),
        (CupertinoIcons.checkmark_seal_fill, '전자결재'),
      ],
    ),
    (
      '직원',
      [
        (CupertinoIcons.person_2_fill, '직원'),
        (CupertinoIcons.clock_fill, '근태·월차'),
        (CupertinoIcons.money_dollar_circle_fill, '급여'),
      ],
    ),
    (
      '소식',
      [(Icons.campaign_rounded, '공지'), (Icons.emoji_events_rounded, '랭킹')],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 섹션을 펼치면서 전역 인덱스를 매긴다
    final children = <Widget>[];
    var index = 0;
    for (final (title, items) in _sections) {
      if (title != null) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Text(
              title,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.gray400,
              ),
            ),
          ),
        );
      }
      for (final item in items) {
        children.add(_item(index++, item));
      }
    }

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
          SizedBox(height: 16),
          // 창이 낮아도 메뉴가 잘리지 않게 스크롤 가능하게 둔다
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: 16),
              children: children,
            ),
          ),
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
          height: 40,
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
