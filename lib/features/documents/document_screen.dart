import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/pressable.dart';

part 'document_models.dart';

/// 문서함 화면 (목업)
///
/// 컴퓨터의 파일 탐색기처럼 폴더를 만들어 문서를 담아둔다.
/// 맥 파인더의 구조를 따라 좌측에 위치·폴더 목록, 우측에 현재 폴더의
/// 내용을 보여주고, 아이콘 보기와 목록 보기를 오갈 수 있다.
class DocumentScreen extends StatefulWidget {
  DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  /// 지금 열려 있는 폴더까지의 경로 (첫 칸은 항상 최상위)
  final List<_Item> _path = [_root];

  /// 좌측에서 고른 위치 (폴더를 직접 열면 [_Place.all]로 돌아온다)
  _Place _place = _Place.all;

  /// 목록에서 고른 항목 — 이름 바꾸기·삭제의 대상
  _Item? _selected;

  /// true면 목록 보기, false면 아이콘 보기
  bool _listView = false;

  String _query = '';

  _Item get _current => _path.last;

  /// 좌측 트리에서 펼쳐둔 폴더
  final Set<_Item> _expanded = {};

  // ── 이동 ──

  void _open(_Item item) {
    if (!item.isFolder) {
      // 미리보기는 아직 없다 — 무엇을 눌렀는지만 알려준다
      AppToast.show(context, '${item.name} 미리보기는 준비 중이에요');
      return;
    }
    setState(() {
      _place = _Place.all;
      _path.add(item);
      _selected = null;
      _query = '';
    });
  }

  /// 브레드크럼에서 [index] 칸으로 되돌아간다
  void _goTo(int index) {
    setState(() {
      _place = _Place.all;
      _path.removeRange(index + 1, _path.length);
      _selected = null;
    });
  }

  void _goUp() {
    if (_path.length > 1) _goTo(_path.length - 2);
  }

  /// 좌측 위치를 고르면 경로는 최상위로 되돌린다
  void _pickPlace(_Place place) {
    setState(() {
      _place = place;
      _path.removeRange(1, _path.length);
      _selected = null;
      _query = '';
    });
  }

  /// 좌측 트리에서 폴더를 고르면 그 폴더까지의 경로를 통째로 세운다
  void _jumpTo(List<_Item> path) {
    setState(() {
      _place = _Place.all;
      _path
        ..removeRange(1, _path.length)
        ..addAll(path);
      _selected = null;
      _query = '';
    });
  }

  // ── 편집 ──

  Future<void> _newFolder() async {
    final name = await _askName(context, title: '새 폴더', confirm: '만들기');
    if (name == null || !mounted) return;

    final folder = _Item.folder(name: name);
    setState(() {
      // 위치 보기 중에 만들면 최상위에 생긴다
      final target = _place == _Place.all ? _current : _root;
      target.children!.add(folder);
      target.updated = DateTime.now();
      _selected = folder;
    });
    AppToast.show(context, '폴더를 만들었어요');
  }

  Future<void> _rename(_Item item) async {
    final name = await _askName(
      context,
      title: '이름 바꾸기',
      confirm: '바꾸기',
      initial: item.name,
    );
    if (name == null || !mounted) return;
    setState(() {
      item.name = name;
      item.updated = DateTime.now();
    });
  }

  void _delete(_Item item) {
    final parent = _parentOf(_root, item) ?? _current;
    setState(() {
      parent.children?.remove(item);
      _expanded.remove(item);
      if (_selected == item) _selected = null;
      // 열어둔 폴더를 지웠으면 그 위로 빠져나온다
      final index = _path.indexOf(item);
      if (index > 0) _path.removeRange(index, _path.length);
    });
    AppToast.show(context, '${item.name}을(를) 삭제했어요');
  }

  void _toggleStar(_Item item) {
    setState(() => item.starred = !item.starred);
  }

  // ── 보여줄 목록 ──

  List<_Item> get _visible {
    final list = switch (_place) {
      _Place.all => [..._current.children!],
      // 위치 보기는 폴더 구조와 상관없이 조건에 맞는 파일을 그러모은다
      _Place.recent =>
        _collect(_root).where((i) => !i.isFolder).toList()
          ..sort((a, b) => b.updated.compareTo(a.updated)),
      _Place.starred => _collect(_root).where((i) => i.starred).toList(),
    };

    final query = _query.trim();
    final filtered = query.isEmpty
        ? list
        : list.where((i) => i.name.contains(query)).toList();

    if (_place == _Place.recent) return filtered.take(30).toList();

    // 파인더처럼 폴더가 먼저, 그다음 이름순
    filtered.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: ColoredBox(
              color: AppColors.surface,
              child: _Sidebar(
                place: _place,
                current: _current,
                expanded: _expanded,
                onPickPlace: _pickPlace,
                onJump: _jumpTo,
                onToggleExpand: (folder) => setState(() {
                  if (!_expanded.remove(folder)) _expanded.add(folder);
                }),
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: Column(
              children: [
                _Toolbar(
                  place: _place,
                  path: _path,
                  query: _query,
                  listView: _listView,
                  selected: _selected,
                  canGoUp: _place == _Place.all && _path.length > 1,
                  onGoUp: _goUp,
                  onCrumb: _goTo,
                  onQuery: (v) => setState(() => _query = v),
                  onToggleView: () => setState(() => _listView = !_listView),
                  onNewFolder: _newFolder,
                  onRename: () => _rename(_selected!),
                  onDelete: () => _delete(_selected!),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  // 항목 바깥 빈 곳을 누르면 선택을 푼다 (파인더와 같게).
                  // 항목 위의 탭은 항목 쪽이 먼저 가져가므로 여기까지 안 온다.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = null),
                    child: items.isEmpty
                        ? _Empty(place: _place, searching: _query.isNotEmpty)
                        : _listView
                        ? _ListBody(
                            items: items,
                            selected: _selected,
                            onSelect: (i) => setState(() => _selected = i),
                            onOpen: _open,
                            onStar: _toggleStar,
                            onRename: _rename,
                            onDelete: _delete,
                          )
                        : _GridBody(
                            items: items,
                            selected: _selected,
                            onSelect: (i) => setState(() => _selected = i),
                            onOpen: _open,
                            onStar: _toggleStar,
                            onRename: _rename,
                            onDelete: _delete,
                          ),
                  ),
                ),
                _StatusBar(items: items, selected: _selected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 사이드바 ──

/// 파인더의 좌측 사이드바 — 위치 목록과 폴더 트리
class _Sidebar extends StatelessWidget {
  _Sidebar({
    required this.place,
    required this.current,
    required this.expanded,
    required this.onPickPlace,
    required this.onJump,
    required this.onToggleExpand,
  });

  final _Place place;
  final _Item current;
  final Set<_Item> expanded;
  final ValueChanged<_Place> onPickPlace;

  /// 트리에서 고른 폴더까지의 경로를 통째로 넘긴다
  final ValueChanged<List<_Item>> onJump;
  final ValueChanged<_Item> onToggleExpand;

  /// 폴더를 재귀로 펼쳐 트리 줄을 만든다
  List<Widget> _tree(List<_Item> parents, _Item folder, int depth) {
    final rows = <Widget>[];
    for (final child in folder.children!.where((i) => i.isFolder)) {
      final path = [...parents, child];
      final hasFolders = child.children!.any((i) => i.isFolder);
      rows.add(
        _TreeRow(
          folder: child,
          depth: depth,
          selected: place == _Place.all && current == child,
          expandable: hasFolders,
          expanded: expanded.contains(child),
          onTap: () => onJump(path),
          onToggle: () => onToggleExpand(child),
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
      scale: 0.98,
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
      scale: 0.98,
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

// ── 상단 툴바 ──

/// 경로 표시와 동작 버튼 — 파인더의 창 위쪽 줄에 해당한다
class _Toolbar extends StatelessWidget {
  _Toolbar({
    required this.place,
    required this.path,
    required this.query,
    required this.listView,
    required this.selected,
    required this.canGoUp,
    required this.onGoUp,
    required this.onCrumb,
    required this.onQuery,
    required this.onToggleView,
    required this.onNewFolder,
    required this.onRename,
    required this.onDelete,
  });

  final _Place place;
  final List<_Item> path;
  final String query;
  final bool listView;
  final _Item? selected;
  final bool canGoUp;
  final VoidCallback onGoUp;
  final ValueChanged<int> onCrumb;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleView;
  final VoidCallback onNewFolder;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 상단 글래스 헤더 버튼과 겹치지 않게 내려 잡는다
      padding: EdgeInsets.fromLTRB(20, 64, 20, 14),
      child: Row(
        children: [
          _RoundButton(
            icon: CupertinoIcons.chevron_left,
            enabled: canGoUp,
            onTap: onGoUp,
          ),
          SizedBox(width: 10),
          Expanded(
            child: place == _Place.all
                ? _Breadcrumb(path: path, onTap: onCrumb)
                : Text(place.label, style: AppTextStyles.title3),
          ),
          SizedBox(width: 12),
          _SearchBox(query: query, onChanged: onQuery),
          SizedBox(width: 10),
          if (selected != null) ...[
            _RoundButton(
              icon: CupertinoIcons.pencil,
              tooltip: '이름 바꾸기',
              onTap: onRename,
            ),
            SizedBox(width: 6),
            _RoundButton(
              icon: CupertinoIcons.delete,
              tooltip: '삭제',
              danger: true,
              onTap: onDelete,
            ),
            SizedBox(width: 10),
          ],
          _RoundButton(
            icon: listView
                ? CupertinoIcons.square_grid_2x2
                : CupertinoIcons.list_bullet,
            tooltip: listView ? '아이콘 보기' : '목록 보기',
            onTap: onToggleView,
          ),
          SizedBox(width: 10),
          Pressable(
            onTap: onNewFolder,
            scale: 0.95,
            child: Container(
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.create_new_folder_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '새 폴더',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 현재 경로 — 칸을 누르면 그 폴더로 되돌아간다
class _Breadcrumb extends StatelessWidget {
  _Breadcrumb({required this.path, required this.onTap});

  final List<_Item> path;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (var i = 0; i < path.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 11,
                  color: AppColors.gray300,
                ),
              ),
            Pressable(
              onTap: () => onTap(i),
              scale: 0.96,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  path[i].name,
                  style: i == path.length - 1
                      ? AppTextStyles.title3
                      : AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 툴바의 동그란 아이콘 버튼
class _RoundButton extends StatelessWidget {
  _RoundButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.gray300
        : danger
        ? AppColors.error
        : AppColors.textSecondary;

    final button = Pressable(
      onTap: enabled ? onTap : () {},
      scale: enabled ? 0.92 : 1,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 툴바 검색 칸
class _SearchBox extends StatefulWidget {
  _SearchBox({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(_SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 폴더를 옮기면 검색어가 비워지므로 칸도 같이 비운다
    if (widget.query != _controller.text) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 14, color: AppColors.gray500),
          SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.body2.copyWith(fontSize: 13),
              cursorColor: AppColors.primary,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: '이름 검색',
                hintStyle: AppTextStyles.body2.copyWith(
                  fontSize: 13,
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

// ── 본문: 아이콘 보기 ──

class _GridBody extends StatelessWidget {
  _GridBody({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onRename,
    required this.onDelete,
  });

  final List<_Item> items;
  final _Item? selected;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onStar;
  final ValueChanged<_Item> onRename;
  final ValueChanged<_Item> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 칸이 찌그러지지 않게 남는 폭에 맞춰 열 수를 정한다
        final columns = ((constraints.maxWidth - 40) / 128).floor().clamp(2, 8);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.92,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _GridTile(
            item: items[index],
            selected: items[index] == selected,
            onSelect: () => onSelect(items[index]),
            onOpen: () => onOpen(items[index]),
            onStar: () => onStar(items[index]),
            onRename: () => onRename(items[index]),
            onDelete: () => onDelete(items[index]),
          ),
        );
      },
    );
  }
}

/// 아이콘 보기 칸 하나 — 큰 아이콘 아래 이름
class _GridTile extends StatefulWidget {
  _GridTile({
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onRename,
    required this.onDelete,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onStar;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 더블클릭을 걸어두면 한 번 눌러도 두 번째를 기다리느라 반응이 늦다.
        // 폴더는 바로 열고, 파일은 고른 뒤 한 번 더 누르면 연다.
        onTap: () {
          if (item.isFolder || widget.selected) {
            widget.onOpen();
          } else {
            widget.onSelect();
          }
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : _hover
                ? AppColors.gray50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(item.kind.icon, size: 44, color: item.kind.color),
                  if (item.starred)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  height: 1.3,
                  color: widget.selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              SizedBox(height: 3),
              // 자리를 늘 잡아둬야 커서를 올릴 때 칸이 흔들리지 않는다
              SizedBox(
                height: 18,
                child: _hover || widget.selected
                    ? _RowActions(
                        starred: item.starred,
                        onStar: widget.onStar,
                        onRename: widget.onRename,
                        onDelete: widget.onDelete,
                      )
                    : Text(
                        item.isFolder
                            ? '${item.children!.length}개 항목'
                            : item.sizeLabel,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 본문: 목록 보기 ──

class _ListBody extends StatelessWidget {
  _ListBody({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onRename,
    required this.onDelete,
  });

  final List<_Item> items;
  final _Item? selected;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onStar;
  final ValueChanged<_Item> onRename;
  final ValueChanged<_Item> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 열 제목 — 목록 보기에서만 나온다
        Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 10),
          child: Row(
            children: [
              Expanded(child: _head('이름')),
              SizedBox(width: 130, child: _head('수정한 날짜')),
              SizedBox(width: 90, child: _head('크기')),
              SizedBox(width: 92, child: _head('종류')),
              SizedBox(width: 84),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.gray100),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, index) => _ListRow(
              item: items[index],
              selected: items[index] == selected,
              onSelect: () => onSelect(items[index]),
              onOpen: () => onOpen(items[index]),
              onStar: () => onStar(items[index]),
              onRename: () => onRename(items[index]),
              onDelete: () => onDelete(items[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _head(String text) => Text(
    text,
    style: AppTextStyles.caption.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    ),
  );
}

/// 목록 보기 한 줄
class _ListRow extends StatefulWidget {
  _ListRow({
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onRename,
    required this.onDelete,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onStar;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 아이콘 보기와 같은 규칙 — 더블클릭 대기가 없어 바로 반응한다
        onTap: () {
          if (item.isFolder || widget.selected) {
            widget.onOpen();
          } else {
            widget.onSelect();
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : _hover
                ? AppColors.gray50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(item.kind.icon, size: 19, color: item.kind.color),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 13,
                          color: widget.selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.starred) ...[
                      SizedBox(width: 5),
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  _stamp(item.updated),
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  item.isFolder ? '--' : item.sizeLabel,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  item.kind.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(
                width: 84,
                child: _hover || widget.selected
                    ? _RowActions(
                        starred: item.starred,
                        onStar: widget.onStar,
                        onRename: widget.onRename,
                        onDelete: widget.onDelete,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 커서를 올렸을 때 나오는 줄 동작 (즐겨찾기 · 이름 바꾸기 · 삭제)
class _RowActions extends StatelessWidget {
  _RowActions({
    required this.starred,
    required this.onStar,
    required this.onRename,
    required this.onDelete,
  });

  final bool starred;
  final VoidCallback onStar;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          starred ? Icons.star_rounded : Icons.star_border_rounded,
          starred ? AppColors.warning : AppColors.gray400,
          onStar,
          '즐겨찾기',
        ),
        _action(CupertinoIcons.pencil, AppColors.gray500, onRename, '이름 바꾸기'),
        _action(CupertinoIcons.delete, AppColors.error, onDelete, '삭제'),
      ],
    );
  }

  Widget _action(
    IconData icon,
    Color color,
    VoidCallback onTap,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}

// ── 빈 화면 · 하단 상태 줄 ──

class _Empty extends StatelessWidget {
  _Empty({required this.place, required this.searching});

  final _Place place;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final text = searching
        ? '검색 결과가 없어요'
        : switch (place) {
            _Place.all => '이 폴더는 비어 있어요',
            _Place.recent => '최근에 손댄 문서가 없어요',
            _Place.starred => '즐겨찾기한 문서가 없어요',
          };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              searching ? Icons.search_rounded : Icons.folder_open_rounded,
              size: 28,
              color: AppColors.gray400,
            ),
          ),
          SizedBox(height: 14),
          Text(
            text,
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 파인더 아래쪽 줄 — 항목 수와 고른 항목을 알려준다
class _StatusBar extends StatelessWidget {
  _StatusBar({required this.items, required this.selected});

  final List<_Item> items;
  final _Item? selected;

  @override
  Widget build(BuildContext context) {
    final folders = items.where((i) => i.isFolder).length;
    final files = items.length - folders;

    return Container(
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.gray20,
        border: Border(top: BorderSide(color: AppColors.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '폴더 $folders · 문서 $files',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          if (selected != null)
            Text(
              selected!.isFolder
                  ? '${selected!.name} 선택됨'
                  : '${selected!.name} · ${selected!.sizeLabel}',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 이름 입력 팝업 ──

/// 새 폴더·이름 바꾸기에 함께 쓰는 이름 입력 팝업.
/// 비우고 확인하면 아무 일도 일어나지 않도록 null을 돌려준다.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
}) {
  return showAppDialog<String>(
    context,
    (context) => _NameDialog(title: title, confirm: confirm, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  _NameDialog({
    required this.title,
    required this.confirm,
    required this.initial,
  });

  final String title;
  final String confirm;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim().isNotEmpty;

    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: AppTextStyles.title3),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: AppTextStyles.body2,
              cursorColor: AppColors.primary,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '이름을 입력하세요',
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: _submit,
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ready ? AppColors.primary : AppColors.gray200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.confirm,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ready ? Colors.white : AppColors.gray500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
