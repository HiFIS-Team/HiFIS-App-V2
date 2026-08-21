part of 'document_screen.dart';

// ── 좌측 사이드바 ──

/// 파인더의 좌측 사이드바 — 위치 목록과 폴더 트리
class _Sidebar extends StatelessWidget {
  _Sidebar({
    required this.scope,
    required this.place,
    required this.current,
    required this.expanded,
    required this.onPickScope,
    required this.onPickPlace,
    required this.onJump,
    required this.onToggleExpand,
    required this.onMove,
  });

  /// 지금 보고 있는 갈래 (전사 · 개인)
  final DocScope scope;
  final ValueChanged<DocScope> onPickScope;

  final _Place place;
  final _Item current;
  final Set<_Item> expanded;
  final ValueChanged<_Place> onPickPlace;

  /// 트리에서 고른 폴더까지의 경로를 통째로 넘긴다
  final ValueChanged<List<_Item>> onJump;
  final ValueChanged<_Item> onToggleExpand;

  /// 트리 폴더에 끌어다 놓았을 때 — 멀리 있는 폴더로 옮기는 길이다
  final void Function(_Item item, _Item folder) onMove;

  /// 폴더를 재귀로 펼쳐 트리 줄을 만든다
  List<Widget> _tree(List<_Item> parents, _Item folder, int depth) {
    final rows = <Widget>[];
    for (final child in folder.children!.where((i) => i.isFolder)) {
      final path = [...parents, child];
      final hasFolders = child.children!.any((i) => i.isFolder);
      rows.add(
        _DropFolder(
          folder: child,
          onMove: onMove,
          radius: 10,
          child: _TreeRow(
            folder: child,
            depth: depth,
            selected: place == _Place.all && current == child,
            expandable: hasFolders,
            expanded: expanded.contains(child),
            onTap: () => onJump(path),
            onToggle: () => onToggleExpand(child),
          ),
        ),
      );
      if (hasFolders && expanded.contains(child)) {
        rows.addAll(_tree(path, child, depth + 1));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 글래스 헤더 버튼 영역만큼 비워둔다
        SizedBox(height: 64),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text('문서함', style: AppTextStyles.title2),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 24),
            children: [
              _caption('문서함'),
              for (final value in DocScope.values)
                _ScopeRow(
                  scope: value,
                  selected: scope == value,
                  onTap: () => onPickScope(value),
                ),
              SizedBox(height: 18),
              _caption('위치'),
              for (final value in _Place.values)
                _PlaceRow(
                  place: value,
                  selected: place == value,
                  onTap: () => onPickPlace(value),
                ),
              SizedBox(height: 18),
              _caption('폴더'),
              ..._tree([], _root, 0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _caption(String text) => Padding(
    padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
      ),
    ),
  );
}

/// 위치 한 줄 (전체 문서 · 최근 항목 · 즐겨찾기)
class _PlaceRow extends StatelessWidget {
  _PlaceRow({required this.place, required this.selected, required this.onTap});

  final _Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              place.icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.gray500,
            ),
            SizedBox(width: 8),
            Text(
              place.label,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 문서함 갈래 한 줄 (전사 문서 · 내 문서) — 위치 줄과 같은 모양이다
class _ScopeRow extends StatelessWidget {
  _ScopeRow({required this.scope, required this.selected, required this.onTap});

  final DocScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              scope == DocScope.company
                  ? Icons.apartment_rounded
                  : Icons.lock_outline_rounded,
              size: 16,
              color: selected ? AppColors.primary : AppColors.gray500,
            ),
            SizedBox(width: 8),
            Text(
              scope.label,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 폴더 트리 한 줄 — 앞의 화살표로 하위 폴더를 펼친다
class _TreeRow extends StatelessWidget {
  _TreeRow({
    required this.folder,
    required this.depth,
    required this.selected,
    required this.expandable,
    required this.expanded,
    required this.onTap,
    required this.onToggle,
  });

  final _Item folder;
  final int depth;
  final bool selected;
  final bool expandable;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.fromLTRB(6.0 + depth * 12, 8, 10, 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: expandable
                  ? MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onToggle,
                        child: Icon(
                          expanded
                              ? CupertinoIcons.chevron_down
                              : CupertinoIcons.chevron_right,
                          size: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                    )
                  : null,
            ),
            Icon(
              Icons.folder_rounded,
              size: 16,
              color: selected ? AppColors.primary : AppColors.gray400,
            ),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 13,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
