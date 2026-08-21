part of 'staff_screen.dart';

// ---------------------------------------------------------------------------
// 검색 · 필터 · 보기 전환
// ---------------------------------------------------------------------------

/// 지점 고르기 — 지점이 하나뿐이면 글자만 보여준다
class _BranchPicker extends StatefulWidget {
  _BranchPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_BranchPicker> createState() => _BranchPickerState();
}

class _BranchPickerState extends State<_BranchPicker> {
  /// 메뉴를 알약 아래에 띄우려면 알약 자리를 알아야 한다
  ///
  /// **build 안에서 만들면 안 된다** — 새 GlobalKey 는 매번 하위 트리를 새로
  /// 만들게 한다. State 에 한 번만 둔다.
  final _key = GlobalKey();

  Future<void> _open() async {
    final selected = widget.selected;
    final picked = await showGlassMenu<String>(
      context: context,
      anchorKey: _key,
      width: 230,
      items: [
        for (final branch in _branches)
          GlassMenuItem(
            value: branch,
            label: branch,
            icon: CupertinoIcons.location_solid,
            selected: branch == selected,
            trailing: Text(
              '${_members.where((m) => _inBranch(m, branch) && m.active).length}명',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
      ],
    );
    if (picked != null) widget.onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.location_solid, size: 14, color: AppColors.gray500),
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
    );

    final box = Container(
      key: _key,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(widthFactor: 1, child: label),
    );

    if (_branches.length < 2) return box;

    return Pressable(onTap: _open, child: box);
  }
}

class _SearchBar extends StatefulWidget {
  _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // 흰 카드와 겹쳐 보이지 않게 배경 위에 눕히는 회색 면
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 15, color: AppColors.gray500),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.body2.copyWith(fontSize: 14),
              cursorColor: AppColors.primary,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: '이름·이메일 검색',
                hintStyle: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 필터 — 팀 이름 옆에 인원 수를 같이 보여준다
class _RankChips extends StatelessWidget {
  _RankChips({
    required this.scope,
    required this.selected,
    required this.onSelect,
  });

  /// 지금 보고 있는 지점·재직 상태의 명단
  final List<_Member> scope;
  final String selected;
  final ValueChanged<String> onSelect;

  int _countOf(String rank) {
    final group = _rankGroupOf(rank);
    if (group == null) return scope.length; // '전체'
    return scope.where((m) => group.has(m.rank)).length;
  }

  @override
  Widget build(BuildContext context) {
    // 탭을 옮길 때마다 칩이 늘었다 줄었다 하면 자리를 못 외운다.
    // 직군은 항상 같은 자리에 두고, 아무도 없으면 0으로 알린다.
    //
    // **접지 않고 가로로 민다.** 사이드바에 마우스를 올리면 폭이 160 줄어드는데,
    // 접히게 두면 마지막 칩만 아랫줄로 내려가고 옆 검색창 밑에 구멍이 남는다.
    // 폭이 넉넉하면 지금과 똑같이 한 줄로 보이고, 좁을 때만 밀어서 본다.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 칩이 눌릴 때 살짝 커지는데(Pressable) 잘리지 않게 위아래를 조금 띄운다
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final rank in _ranks) ...[
            if (rank != _ranks.first) SizedBox(width: 8),
            Builder(
              builder: (context) {
                final count = _countOf(rank);
                final on = rank == selected;
                // 비어 있는 직군은 눌러도 볼 게 없어 한 톤 흐리게 둔다
                final empty = count == 0 && !on;

                return Pressable(
                  onTap: () => onSelect(rank),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 140),
                    height: 38,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // 칸이 남는 폭을 다 먹지 않게 내용만큼만 잡는다
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rank,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? Colors.white
                                : empty
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '$count',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? Colors.white.withValues(alpha: 0.8)
                                : empty
                                ? AppColors.gray300
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 보기 · 목록 보기 전환
class _ViewToggle extends StatelessWidget {
  _ViewToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          _button(Icons.grid_view_rounded, true),
          _button(Icons.format_list_bulleted_rounded, false),
        ],
      ),
    );
  }

  Widget _button(IconData icon, bool value) {
    final selected = grid == value;
    return Pressable(
      onTap: () => onChanged(value),
      child: Container(
        width: 42,
        alignment: Alignment.center,
        decoration: segmentFill(selected: selected),
        child: Icon(
          icon,
          size: 17,
          color: selected ? AppColors.primary : AppColors.gray500,
        ),
      ),
    );
  }
}

/// 팀 머리말 — 이름 + 인원 + 나머지 폭을 채우는 헤어라인
class _SectionHeader extends StatelessWidget {
  _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => SectionHeader(
    title: title,
    info: Text('$count명', style: AppTextStyles.caption),
  );
}
