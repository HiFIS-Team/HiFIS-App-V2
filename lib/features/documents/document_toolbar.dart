part of 'document_screen.dart';

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
    required this.onMove,
    required this.onQuery,
    required this.onToggleView,
    required this.onNewFolder,
    required this.onUpload,
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

  /// 경로 줄에 끌어다 놓았을 때 — 그 폴더로 옮긴다
  final void Function(_Item item, _Item folder) onMove;

  final ValueChanged<String> onQuery;
  final VoidCallback onToggleView;
  final VoidCallback onNewFolder;
  final VoidCallback onUpload;
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
                ? _Breadcrumb(path: path, onTap: onCrumb, onMove: onMove)
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
          SizedBox(width: 6),
          _RoundButton(
            icon: Icons.create_new_folder_rounded,
            tooltip: '새 폴더',
            onTap: onNewFolder,
          ),
          SizedBox(width: 10),
          Pressable(
            onTap: onUpload,
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
                  Icon(Icons.upload_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '파일 올리기',
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
///
/// 항목을 **끌어다 놓으면 그 폴더로 옮겨진다.** 폴더 안에서 밖으로 꺼내는
/// 길이 여기뿐이다 — 지금 보고 있는 목록에는 상위 폴더가 안 나온다.
class _Breadcrumb extends StatelessWidget {
  _Breadcrumb({required this.path, required this.onTap, required this.onMove});

  final List<_Item> path;
  final ValueChanged<int> onTap;
  final void Function(_Item item, _Item folder) onMove;

  @override
  Widget build(BuildContext context) {
    // `reverse` 는 경로가 길 때 **끝(지금 폴더)** 이 보이게 하는 것이라,
    // 그냥 두면 짧은 경로가 오른쪽 검색창 옆에 가서 붙는다.
    // 최소 폭을 뷰포트만큼 줘서 짧을 때는 왼쪽에 서게 한다
    // (즐겨찾기·최근 항목 이름과 같은 자리).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                _DropFolder(
                  folder: path[i],
                  onMove: onMove,
                  radius: 8,
                  child: Pressable(
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
                ),
              ],
            ],
          ),
        ),
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
          // 화면 배경이 gray50과 같은 색이라 흰 면 + 테두리로 띄운다
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
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
        // 화면 배경이 gray50과 같은 색이라 흰 면 + 테두리로 띄운다
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
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
