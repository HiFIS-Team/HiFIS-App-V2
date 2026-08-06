part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 항목 · 지점 고르기
// ---------------------------------------------------------------------------

/// 폰 항목 탭 — 항목 수만큼 균등하게 나눈 밑줄 탭 (업무 탭과 같은 결)
///
/// 알약을 늘어놓으면 화면 폭을 넘겨 옆으로 밀어야 하는데,
/// 항목이 몇 개인지 한눈에 안 보인다. 한 화면에 다 세운다.
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _Metric.values.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onSelect(i),
              scale: 0.94,
              child: Container(
                padding: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == selected
                          ? AppColors.primary
                          : AppColors.gray100,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  // 칸보다 이름이 길면 줄여서 맞춘다
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _Metric.values[i].short,
                      maxLines: 1,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        color: i == selected
                            ? AppColors.primary
                            : AppColors.gray500,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 폰 지점 고르개 — 화면 왼쪽 위 글래스 버튼
///
/// 부품은 **업무 화면 지점 필터와 같은 것**이다
/// ([work_branch_filter.dart](../work/work_branch_filter.dart)) — 아이폰은
/// OS 가 그리는 네이티브 메뉴(`CNPopupMenuButton`), 그 외는 [showGlassMenu].
///
/// 세우는 지점은 권한마다 다르다 ([_branchChoices]).
/// PC 는 머리말 오른쪽의 [_BranchPicker] 를 그대로 쓴다.
class _PhoneBranchFilter extends StatefulWidget {
  _PhoneBranchFilter({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_PhoneBranchFilter> createState() => _PhoneBranchFilterState();
}

class _PhoneBranchFilterState extends State<_PhoneBranchFilter> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다 (아이폰 외 전용)
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  /// 전 지점을 보는 중이 아니면 아이콘을 채운 것으로 바꾼다
  ///
  /// 버튼이 아이콘 하나라 고른 지점 **이름**은 메뉴를 열어야 보인다.
  /// 최소한 "지금 걸려 있다"는 것만이라도 버튼에서 알 수 있게 한다
  /// (업무 화면 지점 필터와 같은 수).
  String get _symbol => widget.selected == _allBranches
      ? 'line.3.horizontal.decrease'
      : 'line.3.horizontal.decrease.circle.fill';

  @override
  Widget build(BuildContext context) {
    if (!isApple) {
      return GlassIconButton(
        key: _key,
        // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
        stableId: 'ranking-branch',
        symbol: _symbol,
        onPressed: _openMenu,
      );
    }

    final choices = _branchChoices;
    return CNPopupMenuButton.icon(
      // 테마가 바뀌면 새로 만든다 (GlassIconButton 과 같은 이유).
      // 고른 지점은 키에 안 넣는다 — 넣으면 바꿀 때마다 네이티브 뷰를 새로 만든다
      key: ValueKey('ranking-branch-${AppColors.isDark}'),
      buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
      size: 40,
      items: [
        CNPopupMenuItem(label: '지점', enabled: false),
        // 네이티브 메뉴에는 체크마크를 못 단다 — 고른 줄은 **아이콘 자리**가 바뀐다
        for (final branch in choices)
          CNPopupMenuItem(
            label: branch,
            icon: CNSymbol(
              widget.selected == branch
                  ? 'checkmark'
                  : branch == _allBranches
                  ? 'square.grid.2x2'
                  : 'building.2',
            ),
          ),
      ],
      // 머리말도 한 칸을 차지한다 — 위 목록에서의 자리가 그대로 온다
      onSelected: (index) {
        if (index == 0) return;
        widget.onSelect(choices[index - 1]);
      },
    );
  }

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final picked = await showGlassMenu<String>(
      context: context,
      anchorKey: _key,
      items: [
        GlassMenuHeader('지점'),
        for (final branch in _branchChoices)
          GlassMenuItem(
            value: branch,
            label: branch,
            icon: branch == _allBranches
                ? CupertinoIcons.square_grid_2x2
                : CupertinoIcons.building_2_fill,
            selected: widget.selected == branch,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked);
  }
}

/// 지점 고르기 — 직원 화면과 같은 모양으로 맞춘다 (PC 머리말 오른쪽)
class _BranchPicker extends StatelessWidget {
  _BranchPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 14,
              color: AppColors.gray500,
            ),
            SizedBox(width: 6),
            Text(
              selected == _allBranches ? '전체 지점' : selected,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_branches.length > 1) ...[
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.gray500,
              ),
            ],
          ],
        ),
      ),
    );

    if (_branches.length < 2) return box;

    return PopupMenuButton<String>(
      onSelected: onSelect,
      tooltip: '',
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gray100),
      ),
      itemBuilder: (context) => [
        for (final branch in _branches)
          PopupMenuItem(
            value: branch,
            height: 42,
            child: Row(
              children: [
                Text(
                  branch,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: branch == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: branch == selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                Text(
                  '${_rankers.where((r) => branch == _allBranches || r.branch == branch).length}명',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
      child: box,
    );
  }
}
