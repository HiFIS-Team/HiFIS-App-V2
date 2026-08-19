/// 사람 고르개 — 목록 화면 오른쪽 위의 **리퀴드 글래스 필터**
///
/// 한 명을 고르면 그 사람 기록만 남는다. 지금 **세션 기록**과 **환경정비
/// 수행 내역**이 같이 쓴다 (2026-08-19 — 원래 세션 기록에만 있던 것을 뺐다).
///
/// **명단 전체를 세우지 않는다.** 지금 화면에 이름이 있는 사람만 넘겨받는다 —
/// 스무 명이 넘는 메뉴에서 오늘 일한 세 명을 찾게 하면 고르는 일이 더 번거롭다.
/// 누구를 세울지는 부르는 쪽이 정한다.
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

/// 고를 수 있는 사람 한 명
typedef FilterPerson = ({String id, String name});

class PeopleFilterButton extends StatefulWidget {
  PeopleFilterButton({
    super.key,
    required this.people,
    required this.selected,
    required this.onSelect,
    required this.stableId,
  });

  /// 지금 화면에 이름이 있는 사람 (이름순으로 넘겨준다)
  final List<FilterPerson> people;

  /// null 이면 '전체'
  final String? selected;
  final ValueChanged<String?> onSelect;

  /// 네이티브 버튼을 다시 만들지 않게 붙이는 고정 식별자 — 화면마다 다르게 준다
  final String stableId;

  @override
  State<PeopleFilterButton> createState() => _PeopleFilterButtonState();
}

class _PeopleFilterButtonState extends State<PeopleFilterButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  static const _allLabel = '전체';

  /// 걸려 있으면 채운 아이콘 — 버튼이 아이콘 하나라 고른 사람 **이름**은
  /// 메뉴를 열어야 보인다. 최소한 "지금 걸려 있다"는 건 알 수 있게 한다.
  String get _symbol => widget.selected == null
      ? 'line.3.horizontal.decrease'
      : 'line.3.horizontal.decrease.circle.fill';

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final people = widget.people;
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
        for (var i = 0; i < people.length; i++)
          GlassMenuItem(
            value: i,
            label: people[i].name,
            icon: CupertinoIcons.person,
            selected: widget.selected == people[i].id,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked == -1 ? null : people[picked].id);
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.people;
    if (isApple && !isDesktop) {
      return CNPopupMenuButton.icon(
        // 테마가 바뀌면 새로 만든다 (패키지의 setBrightness 가 아이콘을 유실).
        // **고른 사람은 키에 안 넣는다** — 넣으면 고를 때마다 뷰를 새로 만든다.
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
          for (final person in people)
            CNPopupMenuItem(
              label: person.name,
              icon: CNSymbol(
                widget.selected == person.id ? 'checkmark' : 'person',
              ),
            ),
        ],
        onSelected: (index) =>
            widget.onSelect(index == 0 ? null : people[index - 1].id),
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
