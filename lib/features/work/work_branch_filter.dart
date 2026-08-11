part of 'work_screen.dart';

/// 업무 화면 지점 고르개 — **MASTER·ADMIN 만** 본다
///
/// 다섯 항목이 전부 지점별로 봐야 하는 데이터라, 항목마다 고르개를 두지 않고
/// 화면 머리에 하나만 둔다. 여기서 고른 지점이 다섯 항목에 같이 걸린다.
///
/// 부품은 **사내톡 헤더 필터와 같은 것**이다 — 아이폰은 OS 가 그리는 네이티브
/// 메뉴(`CNPopupMenuButton`), 그 외는 [showGlassMenu]. macOS 를 네이티브에서
/// 뺀 이유도 거기와 같다 (패키지가 메뉴를 버튼 왼쪽에 붙여서 새어 나간다).
///
/// **MEMBER·MANAGER 에게는 안 그린다.** 서버 `branch_filter` 가 그 둘을 본인
/// 지점으로 고정해서, 골라 봐야 바뀌는 것이 없다.
class _BranchFilter extends StatefulWidget {
  _BranchFilter({required this.branchId, required this.onSelect});

  /// 고른 지점 — null 이면 전 지점
  final String? branchId;

  final ValueChanged<String?> onSelect;

  /// 이 사람에게 고르개를 보여줄 것인가
  static bool get visible => myRole == Role.master || myRole == Role.admin;

  @override
  State<_BranchFilter> createState() => _BranchFilterState();
}

class _BranchFilterState extends State<_BranchFilter> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다 (아이폰 외 전용)
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다 (사내톡에서 겪었다)
  bool _open = false;

  /// 세울 지점 — 조직도 필터와 같은 기준
  ///
  /// **HQ는 안 세운다.** 지점이 아니라 전사이고, 이름이 하필 `전 지점` 이라
  /// 맨 위 '전 지점'과 글자가 겹친다. HQ 소속인 사람의 기록은 '전 지점'에서 보인다.
  List<Branch> get _choices {
    final directory = StaffDirectory.instance;
    return [...directory.branches.where((branch) => !branch.isHq)]..sort(
      (a, b) =>
          directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
    );
  }

  /// 전 지점을 보는 중이 아니면 아이콘을 채운 것으로 바꾼다
  ///
  /// 버튼이 아이콘 하나라 고른 지점 **이름**은 메뉴를 열어야 보인다.
  /// 그래서 최소한 "지금 걸려 있다"는 것만이라도 버튼에서 알 수 있게 한다
  /// (사내톡이 '읽지 않음' 을 켰을 때 아이콘을 바꾸는 것과 같은 수).
  String get _symbol => widget.branchId == null
      ? 'line.3.horizontal.decrease'
      : 'line.3.horizontal.decrease.circle.fill';

  @override
  Widget build(BuildContext context) {
    if (!isApple || isDesktop) {
      return GlassIconButton(
        key: _key,
        // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
        stableId: 'work-branch',
        symbol: _symbol,
        onPressed: _openMenu,
      );
    }

    return CNPopupMenuButton.icon(
      // 테마가 바뀌면 새로 만든다 — 패키지의 setBrightness 가 아이콘 설정을
      // 유실하는 버그가 있다 (GlassIconButton 과 같은 이유).
      //
      // **고른 지점은 키에 안 넣는다.** 넣으면 지점을 바꿀 때마다 네이티브 뷰를
      // 새로 만든다. 키가 그대로면 `didUpdateWidget` 이 돌아서 바뀐 것만 들어간다.
      key: ValueKey('work-branch-${AppColors.isDark}'),
      buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
      size: 40,
      items: [
        CNPopupMenuItem(label: '지점', enabled: false),
        // 네이티브 메뉴에는 체크마크를 못 단다 — 패키지가 `UIAction.state` 를
        // 안 넘긴다. 그래서 고른 줄은 **아이콘 자리**가 체크로 바뀐다
        CNPopupMenuItem(
          label: allBranchesLabel,
          icon: CNSymbol(
            widget.branchId == null ? 'checkmark' : 'square.grid.2x2',
          ),
        ),
        for (final branch in _choices)
          CNPopupMenuItem(
            label: branch.name,
            icon: CNSymbol(
              widget.branchId == branch.id ? 'checkmark' : 'building.2',
            ),
          ),
      ],
      // 머리말도 한 칸을 차지한다 — 위 목록에서의 자리가 그대로 온다
      onSelected: (index) {
        if (index == 0) return;
        widget.onSelect(index == 1 ? null : _choices[index - 2].id);
      },
    );
  }

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final choices = _choices;
    final picked = await showGlassMenu<String>(
      context: context,
      anchorKey: _key,
      items: [
        GlassMenuHeader('지점'),
        GlassMenuItem(
          // null 은 '안 골랐다'와 구분이 안 돼서 전체에 따로 값을 준다
          value: _allBranches,
          label: allBranchesLabel,
          icon: CupertinoIcons.square_grid_2x2,
          selected: widget.branchId == null,
        ),
        for (final branch in choices)
          GlassMenuItem(
            value: branch.id,
            label: branch.name,
            icon: CupertinoIcons.building_2_fill,
            selected: widget.branchId == branch.id,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked == _allBranches ? null : picked);
  }
}

/// 메뉴에서 '전체'를 고른 것 — 밖을 눌러 닫은 null 과 갈라야 한다
const _allBranches = '__all__';
