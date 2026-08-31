import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/input/pressable.dart';
import '../auth/logout.dart';
import '../monitoring/monitoring_screen.dart';

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

  /// (섹션 제목, 메뉴 목록) — 제목이 null이면 캡션 없이 그린다.
  /// 아이콘은 장식이 적은 심플한 라운드 세트로 통일한다.
  ///
  /// **static 이 아니라 getter 다.** 맨 아래 '관리'가 MASTER·ADMIN 에게만
  /// 붙어서 로그인한 사람에 따라 목록이 달라진다.
  /// [MainShell.desktopPages] 와 **순서가 같아야 한다.**
  static List<(String?, List<(IconData, String)>)> get sections => [
    (null, [(Icons.home_rounded, '홈')]),
    (
      '업무',
      [
        (Icons.work_rounded, '업무'),
        (Icons.people_alt_rounded, '회원'),
        (Icons.folder_rounded, '프로젝트'),
        (Icons.calendar_today_rounded, '일정'),
        (Icons.insert_drive_file_rounded, '회의록'),
      ],
    ),
    ('문서', [(Icons.inbox_rounded, '문서함'), (Icons.approval_rounded, '전자결재')]),
    (
      '직원',
      [
        (Icons.people_rounded, '직원'),
        (Icons.schedule_rounded, '근태·월차'),
        (Icons.payments_rounded, '급여'),
      ],
    ),
    (
      '소식',
      [(Icons.campaign_rounded, '공지'), (Icons.emoji_events_rounded, '랭킹')],
    ),
    if (MonitoringScreen.visible)
      ('관리', [(Icons.monitor_heart_rounded, '모니터링')]),
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
    for (final (title, items) in _DesktopSidebarState.sections) {
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
            SizedBox(height: 14),
            _logo(),
            SizedBox(height: 10),
            // 업무 탭바처럼 섹션들을 남는 높이에 고르게 분배하고,
            // 창이 낮으면 스크롤로 전환해 잘리지 않게 한다
            Expanded(
              // 레일이 좁아 스크롤바가 뜨면 메뉴 위를 덮는다.
              // 스크롤은 살리고 막대만 숨긴다
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
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
            // 스크롤 영역 밖이라 창이 낮아도 늘 같은 자리에 남는다
            _bottomDivider(),
            _logoutItem(),
            SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  /// 사이드바 마크 크기 — 폭은 마크 비율(1.92:1)을 따라간다
  static const _logoHeight = 18.0;
  static const _logoWidth = _logoHeight * 1.92;

  /// 메뉴 아이콘의 왼쪽 선 — 바깥 여백 12 + 칸 안쪽 여백 13
  static const _iconLeft = 25.0;

  Widget _logo() {
    // 마크가 가로로 길어서(1.92:1) 아이콘(20)보다 훨씬 넓다. 왼쪽을 맞추면
    // 접혔을 때 중심이 오른쪽으로 밀리고, 중심을 맞추면 펼쳤을 때 왼쪽이
    // 어긋난다. 그래서 상태에 따라 옮긴다 — 접힘은 아이콘과 같은 축(가운데),
    // 펼침은 아이콘과 같은 왼쪽 선.
    final railInner = DesktopSidebar.railWidth - 1; // 오른쪽 경계 헤어라인 1px
    return AnimatedPadding(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: _hovered ? _iconLeft : (railInner - _logoWidth) / 2,
        right: 6,
      ),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Image.asset(
              'assets/images/hifis_mark.png',
              height: _logoHeight,
              cacheHeight: (_logoHeight * 3).round(),
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
      height: 30,
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

  Widget _item(int index, (IconData, String) item) => _row(
    icon: item.$1,
    label: item.$2,
    selected: index == widget.selectedIndex,
    onTap: () => widget.onSelect(index),
  );

  /// 맨 아래 로그아웃 — 화면 이동이 아니라서 선택 표시가 없다.
  Widget _logoutItem() => _row(
    icon: Icons.logout_rounded,
    label: '로그아웃',
    selected: false,
    onTap: () => confirmLogout(context),
  );

  /// 펼치면 사이드바 폭에 맞춰 늘어나는 헤어라인
  Widget _bottomDivider() => SizedBox(
    height: 18,
    child: Center(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _hovered ? 208 : 24,
        height: 1,
        color: AppColors.gray100,
      ),
    ),
  );

  Widget _row({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => _SidebarRow(
    icon: icon,
    label: label,
    selected: selected,
    expanded: _hovered,
    onTap: onTap,
  );
}

/// 메뉴 한 칸 — **호버 상태를 자기가 들고 있다.**
///
/// 예전에는 사이드바 State 가 `_hoverIndex` 를 들고 `setState` 를 했다. 그러면
/// 커서가 칸 하나를 지날 때마다 사이드바 전체(메뉴 열다섯 칸 + 캡션 + 로고)가
/// 다시 빌드돼서, 레일 위로 마우스를 훑으면 눈에 띄게 굼떴다. 배경색이 바뀌는
/// 건 커서가 올라간 그 칸뿐이라 리빌드도 그 칸에서 끝내야 한다.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// 사이드바가 펼쳐졌는지 — 제목을 보일지 정한다
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Pressable(
          onTap: widget.onTap,
          // 호버 배경은 애니메이션 없이 즉시 — 페이드가 있으면 커서를
          // 빠르게 지나갈 때 이전 항목의 배경이 잔상처럼 깜빡인다
          child: Container(
            height: 44,
            // 오른쪽 경계 헤어라인(1px)이 안쪽 폭을 깎으므로 14가 아닌 13 —
            // 14면 접힘 상태에서 아이콘이 1px 오버플로된다
            padding: EdgeInsets.symmetric(horizontal: 13),
            // 인스타그램처럼 배경색은 호버한 칸에만 — 선택 표시는 색·굵기로만
            decoration: BoxDecoration(
              color: _hovered ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: widget.selected
                        ? AppColors.primary
                        : AppColors.gray500,
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: 150),
                      opacity: widget.expanded ? 1 : 0,
                      child: Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 15,
                            fontWeight: widget.selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: widget.selected
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
      ),
    );
  }
}
