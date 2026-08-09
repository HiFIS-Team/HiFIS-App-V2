part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 항목 · 지점 고르기
// ---------------------------------------------------------------------------

/// 폰 항목 탭 — 밑줄 탭 (업무 탭과 같은 결)
///
/// 알약을 늘어놓으면 화면 폭을 넘겨 옆으로 밀어야 하는데,
/// 항목이 몇 개인지 한눈에 안 보인다. 한 화면에 다 세운다.
///
/// **칸을 6등분하지 않는다.** 등분하면 글자 길이가 달라서 남는 여백이
/// 칸마다 달라진다 — `프로젝트`·`환경정비`(4자)는 칸을 꽉 채워 서로 붙고,
/// `매출`·`친절`(2자)은 양옆이 남아 멀어 보였다 (실제로 그렇게 보였다).
/// **칸 = 글자 폭 + 똑같은 여백**으로 잡으면 어느 두 글자 사이든 간격이 같다.
/// 칸끼리는 여전히 붙어 있어서 **밑줄은 지금처럼 한 줄로 이어진다.**
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  /// 글자 폭을 잴 때 쓰는 스타일 — **늘 굵게** 잰다
  ///
  /// 고른 칸만 굵어지는데, 그때그때 재면 탭을 옮길 때마다 칸 폭이 달라져서
  /// 글자들이 좌우로 흔들린다. 제일 넓은 상태로 고정해 둔다.
  static TextStyle get _measureStyle =>
      AppTextStyles.body2.copyWith(fontSize: 14, fontWeight: FontWeight.w700);

  double _widthOf(String text, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _measureStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final metric in _Metric.values) _widthOf(metric.short, scaler),
    ];
    final textTotal = widths.fold<double>(0, (sum, w) => sum + w);

    return LayoutBuilder(
      builder: (context, box) {
        // 글자만으로도 폭이 모자라면(글자 크기를 크게 키운 기기) 예전처럼 등분한다.
        // 그때는 `FittedBox` 가 줄여서 맞춘다 — 넘쳐서 잘리는 것보다 낫다.
        final gap = (box.maxWidth - textTotal) / widths.length;
        final last = _Metric.values.length - 1;
        return Row(
          children: [
            for (var i = 0; i < _Metric.values.length; i++)
              // 마지막 칸은 남는 폭을 그대로 받는다 — 소수점이 쌓여 1px 넘치면
              // 줄이 통째로 빨간 넘침 줄무늬가 된다
              if (gap <= 0 || i == last)
                Expanded(child: _tab(i))
              else
                SizedBox(width: widths[i] + gap, child: _tab(i)),
          ],
        );
      },
    );
  }

  Widget _tab(int i) {
    return Pressable(
      onTap: () => onSelect(i),
      scale: 0.94,
      child: Container(
        padding: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: i == selected ? AppColors.primary : AppColors.gray100,
              width: 2,
            ),
          ),
        ),
        child: Center(
          // 칸보다 이름이 길면 줄여서 맞춘다 (칸을 등분으로 되돌린 경우)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _Metric.values[i].short,
              maxLines: 1,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: i == selected ? AppColors.primary : AppColors.gray500,
                fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
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
