import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/pressable.dart';

/// macOS 데스크톱용 좌측 사이드바 내비게이션 (인스타그램 데스크톱 패턴)
///
/// 평소에는 아이콘만 있는 좁은 레일로 있다가, 커서를 올리면
/// 펼쳐지면서 메뉴 제목과 섹션 캡션이 나타난다. 펼쳐질 때는
/// 콘텐츠를 밀지 않고 그 위로 떠오른다.
///
/// 선택 인덱스는 섹션을 펼친 순서(0부터)이며,
/// MainShell의 `_desktopPages` 순서와 반드시 일치해야 한다.
class DesktopSidebar extends StatefulWidget {
  DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// 접힌 레일 폭 — MainShell이 콘텐츠 왼쪽 여백으로 쓴다
  static const double railWidth = 72;

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _hovered = false;

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

  /// 펼쳐질 때만 보이는 요소 (메뉴 제목, 섹션 캡션, 워드마크)
  Widget _fade(Widget child) => AnimatedOpacity(
    duration: Duration(milliseconds: 150),
    opacity: _hovered ? 1 : 0,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    // 섹션을 펼치면서 전역 인덱스를 매긴다.
    // 캡션과 항목을 섹션 단위로 묶어야 남는 공간이 섹션 사이에만 분배된다.
    final children = <Widget>[];
    var index = 0;
    for (final (title, items) in _sections) {
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) _sectionHeader(title),
            for (final item in items) _item(index++, item),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _hovered ? 232 : DesktopSidebar.railWidth,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.gray100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 24),
            _logo(),
            SizedBox(height: 16),
            // 업무 탭바처럼 섹션들을 남는 높이에 고르게 분배하고,
            // 창이 낮으면 스크롤로 전환해 잘리지 않게 한다
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 26),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Image.asset(
              'assets/images/hifis_mark.png',
              height: 22,
              cacheHeight: 66,
            ),
            Expanded(
              child: ClipRect(
                child: _fade(
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'HiFIS',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.title3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          // 접힘: 짧은 구분선
          Center(
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 150),
              opacity: _hovered ? 0 : 1,
              child: Container(width: 24, height: 1, color: AppColors.gray100),
            ),
          ),
          // 펼침: 섹션 캡션
          Positioned(
            left: 26,
            top: 0,
            bottom: 0,
            child: _fade(
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int index, (IconData, String) item) {
    final selected = index == widget.selectedIndex;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Pressable(
        scale: 0.97,
        pressedColor: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onSelect(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          height: 44,
          // 오른쪽 경계 헤어라인(1px)이 안쪽 폭을 깎으므로 14가 아닌 13 —
          // 14면 접힘 상태에서 아이콘이 1px 오버플로된다
          padding: EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(
                  item.$1,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.gray500,
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: _fade(
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        item.$2,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.gray600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
