/// 고르개 — 목록 화면 오른쪽 위의 **리퀴드 글래스 필터**
///
/// 하나 고르면 그것만 남는다. 지금 셋이 같이 쓴다.
///
/// | 화면 | 무엇을 세우나 |
/// |---|---|
/// | 세션 기록 | 사람 |
/// | 환경정비 수행 내역 | 사람 · **환경정비 항목** |
///
/// 원래 사람 전용(`PeopleFilterButton`)이었는데 환경정비에 항목 필터가
/// 붙으면서 넓혔다 (2026-08-31). 세우는 것이 사람이든 항목이든 **id·이름
/// 쌍**이라 다룰 것이 같다 — 다른 것은 줄에 붙는 아이콘뿐이다.
///
/// **명단 전체를 세울지는 부르는 쪽이 정한다.** 세션 기록·사람 필터는 지금
/// 화면에 이름이 있는 사람만 넘긴다 — 스무 명이 넘는 메뉴에서 오늘 일한 세
/// 명을 찾게 하면 고르는 일이 더 번거롭다. 환경정비 **항목**은 반대로 지점
/// 항목을 다 세운다 — 그날 기록이 없는 항목도 골라야 날짜를 넘겨 가며
/// "그건 며칠에 했지" 를 찾을 수 있다.
///
/// 메뉴는 지점 고르개([BranchScopeButton])·랭킹 직군 필터와 같은 부품이다 —
/// 아이폰은 OS 가 그리는 네이티브 메뉴, 그 외는 [showGlassMenu].
/// **macOS 는 네이티브를 안 쓴다** — 같은 패키지가 메뉴를 버튼 왼쪽에 고정해서
/// 창 밖으로 새어 나간다 (지점 고르개와 같은 이유).
library;

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../util/platform.dart';
import '../../util/sf_symbols.dart';
import '../glass/glass_icon_button.dart';
import '../glass/glass_menu.dart';

/// 고를 수 있는 것 하나 — 사람이면 직원 id, 항목이면 환경정비 항목 id
typedef FilterOption = ({String id, String name});

class PickFilterButton extends StatefulWidget {
  PickFilterButton({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.stableId,
    this.icon = CupertinoIcons.person,
    this.symbol = 'person',
  });

  /// 세울 것들 — 보일 차례대로 넘겨준다 (이 위젯은 다시 안 세운다)
  final List<FilterOption> options;

  /// null 이면 '전체'
  final String? selected;
  final ValueChanged<String?> onSelect;

  /// 네이티브 버튼을 다시 만들지 않게 붙이는 고정 식별자 — 화면마다 다르게 준다
  final String stableId;

  /// 메뉴 줄에 붙는 아이콘 — 애플이 아닐 때 쓴다
  final IconData icon;

  /// 같은 아이콘의 SF 심볼 이름 — **버튼과 네이티브 메뉴가 같이 쓴다**
  ///
  /// 버튼은 걸려 있으면 `.fill` 을 붙인 것으로 바꾼다 (`person` →
  /// `person.fill`). 새 값을 쓸 때는 **둘 다** [sfSymbols] 매핑표에 넣는다 —
  /// 안 넣으면 안드로이드·윈도우에서 빈 원이 된다.
  final String symbol;

  @override
  State<PickFilterButton> createState() => _PickFilterButtonState();
}

class _PickFilterButtonState extends State<PickFilterButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  static const _allLabel = '전체';

  /// 걸려 있으면 채운 아이콘 — 버튼이 아이콘 하나라 고른 것의 **이름**은
  /// 메뉴를 열어야 보인다. 최소한 "지금 걸려 있다"는 건 알 수 있게 한다.
  ///
  /// **거르는 대상을 그린다** (사람이면 사람, 항목이면 태그). 예전에는 둘 다
  /// 필터 아이콘이었는데, 환경정비에서 두 버튼이 나란히 서면서 어느 쪽이
  /// 무엇인지 구분이 안 됐다 (2026-08-31).
  String get _symbol =>
      widget.selected == null ? widget.symbol : '${widget.symbol}.fill';

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final options = widget.options;
    final picked = await showGlassMenu<int>(
      context: context,
      anchorKey: _key,
      width: 200,
      items: [
        GlassMenuItem(
          // null 은 '안 골랐다'와 구분이 안 돼서 전체에 따로 값을 준다
          value: -1,
          label: _allLabel,
          icon: CupertinoIcons.square_grid_2x2,
          selected: widget.selected == null,
        ),
        for (var i = 0; i < options.length; i++)
          GlassMenuItem(
            value: i,
            label: options[i].name,
            icon: widget.icon,
            selected: widget.selected == options[i].id,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked == -1 ? null : options[picked].id);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    if (isApple && !isDesktop) {
      return CNPopupMenuButton.icon(
        // 테마가 바뀌면 새로 만든다 (패키지의 setBrightness 가 아이콘을 유실).
        // **고른 것은 키에 안 넣는다** — 넣으면 고를 때마다 뷰를 새로 만든다.
        key: ValueKey('${widget.stableId}-${AppColors.isDark}'),
        buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
        size: 40,
        items: [
          // 네이티브 메뉴에는 체크마크를 못 단다 — 고른 줄은 **아이콘 자리**가
          // 체크로 바뀐다
          CNPopupMenuItem(
            label: _allLabel,
            icon: CNSymbol(
              widget.selected == null ? 'checkmark' : 'square.grid.2x2',
            ),
          ),
          for (final option in options)
            CNPopupMenuItem(
              label: option.name,
              icon: CNSymbol(
                widget.selected == option.id ? 'checkmark' : widget.symbol,
              ),
            ),
        ],
        onSelected: (index) =>
            widget.onSelect(index == 0 ? null : options[index - 1].id),
      );
    }

    return GlassIconButton(
      key: _key,
      // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
      stableId: widget.stableId,
      symbol: _symbol,
      onPressed: _openMenu,
    );
  }
}
