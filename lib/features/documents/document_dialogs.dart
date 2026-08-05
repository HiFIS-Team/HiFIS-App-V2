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

// ── 설명·태그 팝업 ──

/// 서버에 보낼 설명과 태그
typedef _Info = ({String desc, List<String> tags});

/// 문서의 설명·태그를 고친다. 취소하면 null 이다
///
/// **올릴 때 묻지 않는다.** 파일을 여러 개 끌어다 놓는 게 흔한데 그때마다
/// 팝업이 뜨면 담는 일이 안 끝난다. 올린 뒤 필요한 것에만 붙인다.
Future<_Info?> _askInfo(BuildContext context, _Item item) {
  return showAppDialog<_Info>(context, (context) => _InfoDialog(item: item));
}

class _InfoDialog extends StatefulWidget {
  _InfoDialog({required this.item});

  final _Item item;

  @override
  State<_InfoDialog> createState() => _InfoDialogState();
}

class _InfoDialogState extends State<_InfoDialog> {
  late final _desc = TextEditingController(text: widget.item.desc ?? '');
  late final _tags = TextEditingController(text: widget.item.tags.join(', '));

  @override
  void dispose() {
    _desc.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, (
      desc: _desc.text.trim(),
      // 쉼표로 끊고 빈 칸은 버린다 — `계약서, , 2026` 이 태그 셋이 되면 안 된다
      tags: [
        for (final tag in _tags.text.split(','))
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 380),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('설명·태그', style: AppTextStyles.title3),
          SizedBox(height: 4),
          Text(
            widget.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Text('설명', style: AppTextStyles.label),
          SizedBox(height: 8),
          _InfoField(
            controller: _desc,
            hint: '무슨 파일인지 한 줄로 적어주세요',
            lines: 3,
            autofocus: true,
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Text('태그', style: AppTextStyles.label),
              SizedBox(width: 6),
              Text('쉼표로 나눠요', style: AppTextStyles.caption),
            ],
          ),
          SizedBox(height: 8),
          _InfoField(
            controller: _tags,
            hint: '계약서, 2026',
            onSubmitted: _submit,
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
                child: AppButton(label: '저장', filled: true, onTap: _submit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 설명·태그 입력칸 — 이름 팝업과 같은 면·높이다
class _InfoField extends StatelessWidget {
  _InfoField({
    required this.controller,
    required this.hint,
    this.lines = 1,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int lines;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: lines > 1
          ? AppDecorations.fieldPaddingMultiline
          : AppDecorations.fieldPadding,
      decoration: AppDecorations.field(),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: AppTextStyles.body2,
        cursorColor: AppColors.primary,
        minLines: lines,
        maxLines: lines,
        textInputAction: lines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: (_) => onSubmitted?.call(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
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
          boxShadow: AppShadows.modal,
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
