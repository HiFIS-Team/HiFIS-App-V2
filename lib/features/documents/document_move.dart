part of 'document_screen.dart';

// ── 끌어다 옮기기 ──
//
// 파인더처럼 항목을 집어 폴더 위에 놓으면 그 안으로 들어간다.
// **경로 줄(브레드크럼)에 놓으면 위로 뺀다** — 폴더 안에서 밖으로 꺼내는 길이
// 그것뿐이라, 이게 없으면 한 번 들어간 파일을 못 꺼낸다.
//
// OS 에서 파일을 끌어오는 `DropTarget`(desktop_drop)과는 다른 것이다.
// 저쪽은 컴퓨터 → 문서함이고 여기는 문서함 안에서의 이동이다. 서로 안 겹친다.

/// [node] 가 [ancestor] 안에 들어 있는가 — 폴더를 자기 하위로 넣는 걸 막는다
///
/// 서버도 막지만(`400 INVALID_MOVE`) 놓기 전에 거절해야 화면이 안 흔들린다.
bool _isDescendant(_Item ancestor, _Item node) {
  if (!ancestor.isFolder) return false;
  for (final child in ancestor.children!) {
    if (identical(child, node)) return true;
    if (_isDescendant(child, node)) return true;
  }
  return false;
}

/// [item] 을 [folder] 로 옮길 수 있는가
bool _canDropInto(_Item item, _Item folder) {
  if (!folder.isFolder) return false;
  if (identical(item, folder)) return false;
  // 이미 그 안에 있으면 옮길 것이 없다
  if (folder.children!.contains(item)) return false;
  // 폴더를 자기 하위로는 못 넣는다 (넣으면 트리가 끊긴다)
  return !_isDescendant(item, folder);
}

/// 끌 수 있게 감싼다 — 잡고 움직이면 이름표가 커서를 따라온다
class _DragItem extends StatelessWidget {
  _DragItem({required this.item, required this.child});

  final _Item item;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Draggable<_Item>(
      data: item,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragLabel(item: item),
      // 끌려 나간 자리는 옅게 남긴다 — 아예 비우면 목록이 한 칸 접힌다
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }
}

/// 커서를 따라다니는 이름표
class _DragLabel extends StatelessWidget {
  _DragLabel({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        // 커서 끝에 딱 붙으면 놓을 자리가 안 보인다 — 살짝 띄운다
        padding: EdgeInsets.only(left: 12, top: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gray100),
            boxShadow: AppShadows.popup,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.kind.icon, size: 16, color: item.kind.color),
              SizedBox(width: 8),
              Text(
                item.name,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 놓을 수 있는 자리로 감싼다 — 올려두면 파란 테두리가 뜬다
class _DropFolder extends StatelessWidget {
  _DropFolder({
    required this.folder,
    required this.onMove,
    required this.child,
    this.radius = 14,
  });

  /// 놓았을 때 들어갈 폴더
  final _Item folder;

  final void Function(_Item item, _Item folder) onMove;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_Item>(
      onWillAcceptWithDetails: (details) => _canDropInto(details.data, folder),
      onAcceptWithDetails: (details) => onMove(details.data, folder),
      builder: (context, candidate, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            // 자리를 늘 잡아둬야 올렸을 때 칸이 1px 흔들리지 않는다
            color: candidate.isEmpty ? Colors.transparent : AppColors.primary,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
