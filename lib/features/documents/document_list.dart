part of 'document_screen.dart';

// ── 본문: 목록 보기 ──

class _ListBody extends StatelessWidget {
  _ListBody({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onMenu,
    required this.onMove,
    required this.canDrag,
  });

  final List<_Item> items;
  final _Item? selected;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onStar;
  final ValueChanged<_Item> onDownload;
  final ValueChanged<_Item> onRename;
  final ValueChanged<_Item> onDelete;

  /// 끌어다 놓아 옮기기
  final void Function(_Item item, _Item folder) onMove;

  /// 즐겨찾기·최근 항목은 폴더 구조와 상관없는 목록이라 끌지 않는다
  final bool canDrag;

  /// 우클릭한 항목과 커서 위치
  final void Function(_Item item, Offset position) onMenu;

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
              SizedBox(width: 108),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.gray100),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final row = _ListRow(
                item: item,
                selected: item == selected,
                onSelect: () => onSelect(item),
                onOpen: () => onOpen(item),
                onStar: () => onStar(item),
                onDownload: () => onDownload(item),
                onRename: () => onRename(item),
                onDelete: () => onDelete(item),
                onMenu: (position) => onMenu(item, position),
              );
              if (!canDrag) return row;
              // 폴더는 놓을 자리이면서 자기도 옮겨진다
              final draggable = _DragItem(item: item, child: row);
              return item.isFolder
                  ? _DropFolder(
                      folder: item,
                      onMove: onMove,
                      radius: 10,
                      child: draggable,
                    )
                  : draggable;
            },
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
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onMenu,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onStar;
  final VoidCallback onDownload;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  /// 우클릭한 커서 위치
  final ValueChanged<Offset> onMenu;

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
        onSecondaryTapDown: (d) => widget.onMenu(d.globalPosition),
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
                  item.updatedLabel,
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
                width: 108,
                child: _hover || widget.selected
                    ? _RowActions(
                        item: item,
                        onStar: widget.onStar,
                        onDownload: widget.onDownload,
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

/// 커서를 올렸을 때 나오는 줄 동작 (즐겨찾기 · 내려받기 · 이름 바꾸기 · 삭제)
///
/// **폴더에는 즐겨찾기·내려받기가 없다** — 서버가 문서에만 준다.
/// 자리를 늘 같게 잡아 두려고 폴더는 두 칸을 비워 둔다.
class _RowActions extends StatelessWidget {
  _RowActions({
    required this.item,
    required this.onStar,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
  });

  final _Item item;
  final VoidCallback onStar;
  final VoidCallback onDownload;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isFolder)
          SizedBox(width: 44)
        else ...[
          _action(
            item.starred ? Icons.star_rounded : Icons.star_border_rounded,
            item.starred ? AppColors.warning : AppColors.gray400,
            onStar,
            '즐겨찾기',
          ),
          _action(
            Icons.download_rounded,
            AppColors.gray500,
            onDownload,
            '내려받기',
          ),
        ],
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

    // 판이 통째로 비는 자리라 전자결재·프로젝트와 같은 안내를 쓴다
    return EmptyState(
      icon: searching ? Icons.search_rounded : Icons.folder_open_rounded,
      title: '문서함',
      text: text,
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
