part of 'document_screen.dart';

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
                child: AppButton(
                  label: '취소',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: widget.confirm,
                  filled: ready,
                  // 아직 못 낼 상태면 회색
                  color: ready ? null : AppColors.gray200,
                  textColor: ready ? null : AppColors.gray500,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 우클릭 메뉴 ──

/// 메뉴 한 줄 (label이 null이면 구분선)
class _MenuEntry {
  _MenuEntry({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  _MenuEntry.divider()
    : label = null,
      icon = null,
      onTap = null,
      danger = false;

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;

  bool get isDivider => label == null;
}

/// 누른 자리에 메뉴를 띄운다 (맥 우클릭 메뉴와 같은 결)
///
/// 화면 밖으로 나가지 않게 [_MenuLayout]이 위치를 잡아주고,
/// 바깥을 누르면 닫힌다.
Future<void> _showDocumentMenu(
  BuildContext context,
  Offset position,
  List<_MenuEntry> entries,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) => CustomSingleChildLayout(
      delegate: _MenuLayout(position),
      child: _ContextMenu(entries: entries),
    ),
  );
}

/// 누른 지점 근처에 두되, 화면 밖으로 넘어가면 안쪽으로 당긴다
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.position);

  final Offset position;

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = position.dx.clamp(
      _margin,
      (size.width - childSize.width - _margin).clamp(_margin, size.width),
    );
    final y = position.dy.clamp(
      _margin,
      (size.height - childSize.height - _margin).clamp(_margin, size.height),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      oldDelegate.position != position;
}

class _ContextMenu extends StatelessWidget {
  _ContextMenu({required this.entries});

  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 190,
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100),
          boxShadow: [
            BoxShadow(
              color: AppShadows.ink.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries)
              if (entry.isDivider)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Container(height: 1, color: AppColors.gray100),
                )
              else
                _MenuRow(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  _MenuRow({required this.entry});

  final _MenuEntry entry;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = entry.danger ? AppColors.error : AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // 메뉴를 먼저 닫아야 팝업이 겹쳐 뜨지 않는다
          Navigator.pop(context);
          entry.onTap!();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
                ? (entry.danger
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primaryLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(entry.icon, size: 15, color: color),
              SizedBox(width: 9),
              Text(
                entry.label!,
                style: AppTextStyles.body2.copyWith(fontSize: 13, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
