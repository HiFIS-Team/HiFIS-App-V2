part of 'document_screen.dart';

// ── 본문: 아이콘 보기 ──

class _GridBody extends StatelessWidget {
  _GridBody({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStar,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onMenu,
  });

  final List<_Item> items;
  final _Item? selected;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onStar;
  final ValueChanged<_Item> onDownload;
  final ValueChanged<_Item> onRename;
  final ValueChanged<_Item> onDelete;

  /// 우클릭한 항목과 커서 위치
  final void Function(_Item item, Offset position) onMenu;

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
            onDownload: () => onDownload(items[index]),
            onRename: () => onRename(items[index]),
            onDelete: () => onDelete(items[index]),
            onMenu: (position) => onMenu(items[index], position),
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
        onSecondaryTapDown: (d) => widget.onMenu(d.globalPosition),
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
                        item: item,
                        onStar: widget.onStar,
                        onDownload: widget.onDownload,
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
