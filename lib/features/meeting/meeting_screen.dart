import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';

/// 회의록 화면 (목업)
///
/// 데스크톱은 좌측 목록 + 우측 본문 2단 구조.
/// 본문은 마크다운으로 적고, 평소에는 렌더링된 모습으로 읽는다.
/// 모바일 화면은 아직 준비 중 — PC를 먼저 다듬는다.
class MeetingScreen extends StatefulWidget {
  MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  _Note? _selected;

  /// 새로 만든 회의록은 바로 편집 모드로 연다
  bool _startEditing = false;

  List<_Note> get _sorted =>
      [..._notes]..sort((a, b) => b.date.compareTo(a.date));

  _Note? _syncSelection(List<_Note> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  void _create() {
    final now = DateTime.now();
    final note = _Note(
      title: '',
      date: DateTime(now.year, now.month, now.day),
      members: [me],
      body: '',
      updated: now,
    );
    setState(() {
      _notes.add(note);
      _selected = note;
      _startEditing = true;
    });
  }

  void _delete(_Note note) {
    setState(() {
      _notes.remove(note);
      _selected = null;
    });
    AppToast.show(context, '회의록을 삭제했어요');
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '📝', title: '회의록');

    final list = _sorted;
    final selected = _syncSelection(list);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _NoteList(
                notes: list,
                selected: selected,
                onSelect: (note) => setState(() {
                  _selected = note;
                  _startEditing = false;
                }),
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyNote(onCreate: _create)
                : _NoteView(
                    // 회의록을 바꾸면 편집 상태·스크롤을 새로 시작한다
                    key: ValueKey(selected),
                    note: selected,
                    editing: _startEditing,
                    onChanged: () => setState(() {}),
                    onDelete: () => _delete(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 목록 ──

class _NoteList extends StatelessWidget {
  _NoteList({
    required this.notes,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Note> notes;
  final _Note? selected;
  final ValueChanged<_Note> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 글래스 헤더 버튼 영역만큼 비워둔다
        SizedBox(height: 64),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text('회의록', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notes.length}',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Pressable(
                onTap: onCreate,
                scale: 0.94,
                pressedColor: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
                padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text(
                      '새 회의록',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    '작성된 회의록이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _NoteTile(
                    note: notes[i],
                    selected: notes[i] == selected,
                    onTap: () => onSelect(notes[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatefulWidget {
  _NoteTile({required this.note, required this.selected, required this.onTap});

  final _Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                note.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _date(note.date),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  AvatarStack(names: note.members, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  _EmptyNote({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.description_outlined,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('회의록', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '회의 내용을 마크다운으로 적어보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: 24),
          Pressable(
            onTap: onCreate,
            scale: 0.97,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '새 회의록',
                style: AppTextStyles.body2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 우측 본문 ──

class _NoteView extends StatefulWidget {
  _NoteView({
    super.key,
    required this.note,
    required this.editing,
    required this.onChanged,
    required this.onDelete,
  });

  final _Note note;

  /// 새로 만든 회의록이면 편집 상태로 시작한다
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<_NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<_NoteView> {
  late final _title = TextEditingController(text: widget.note.title);
  final _titleFocus = FocusNode();

  late bool _editing = widget.editing;

  /// 마크다운 문법 도움말 펼침 상태
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_editing) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// 편집 중 입력은 바로 모델에 반영한다 (목록 미리보기도 같이 갱신)
  void _sync() {
    widget.note
      ..title = _title.text.trim()
      ..updated = DateTime.now();
    widget.onChanged();
  }

  void _toggleEdit() {
    if (_editing) _sync();
    setState(() => _editing = !_editing);
  }

  Future<void> _pickDate() async {
    final note = widget.note;
    final picked = await showDatePicker(
      context: context,
      initialDate: note.date,
      firstDate: DateTime(note.date.year - 2),
      lastDate: DateTime(note.date.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              (AppColors.isDark
                      ? ColorScheme.dark(surface: AppColors.surface)
                      : ColorScheme.light(surface: AppColors.surface))
                  .copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => note.date = picked);
    widget.onChanged();
  }

  /// 본문의 체크박스를 눌렀을 때 그 줄만 바꿔 쓴다
  void _toggleCheckbox(int line, bool checked) {
    final lines = widget.note.body.split('\n');
    if (line >= lines.length) return;
    lines[line] = checked
        ? lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[x]')
        : lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[ ]');
    widget.note.body = lines.join('\n');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return ListView(
      padding: EdgeInsets.fromLTRB(32, 64, 32, bottomBarInset(context)),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _editing
                  ? TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      style: AppTextStyles.title1,
                      cursorColor: AppColors.primary,
                      onChanged: (_) => _sync(),
                      decoration: InputDecoration(
                        hintText: '제목 없는 회의록',
                        hintStyle: AppTextStyles.title1.copyWith(
                          color: AppColors.gray300,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    )
                  : Text(note.displayTitle, style: AppTextStyles.title1),
            ),
            SizedBox(width: 16),
            if (_editing) ...[
              Pressable(
                onTap: widget.onDelete,
                scale: 0.95,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '삭제',
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 14,
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 6),
            ],
            Pressable(
              onTap: _toggleEdit,
              scale: 0.95,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
                decoration: BoxDecoration(
                  color: _editing ? AppColors.primary : AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _editing ? Icons.check_rounded : Icons.edit_rounded,
                      size: 15,
                      color: _editing ? Colors.white : AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _editing ? '완료' : '편집',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        color: _editing
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        // 날짜·참석자 — 편집 중에는 바로 고칠 수 있다
        if (_editing) ...[
          Row(
            children: [
              Pressable(
                onTap: _pickDate,
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _date(note.date),
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // 달력 옆 마크다운 문법 도움말 (펼침)
              Pressable(
                onTap: () => setState(() => _help = !_help),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '마크다운 문법',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      _help
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_help) ...[SizedBox(height: 10), _HelpPanel()],
          SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final staff in staffList)
                _PersonChip(
                  staff: staff,
                  joined: note.members.contains(staff.name),
                  onTap: () {
                    setState(() {
                      if (note.members.contains(staff.name)) {
                        note.members.remove(staff.name);
                      } else {
                        note.members.add(staff.name);
                      }
                    });
                    widget.onChanged();
                  },
                ),
            ],
          ),
        ] else
          Row(
            children: [
              Text(
                '${_date(note.date)} (${_weekday(note.date)}) · 참석 ${note.members.length}명',
                style: AppTextStyles.caption,
              ),
              SizedBox(width: 10),
              AvatarStack(names: note.members, size: 24),
            ],
          ),
        SizedBox(height: 14),
        Container(height: 1, color: AppColors.gray100),
        SizedBox(height: 14),
        if (_editing)
          _BlockEditor(
            source: widget.note.body,
            onChanged: (markdown) {
              widget.note
                ..body = markdown
                ..updated = DateTime.now();
              widget.onChanged();
            },
          )
        else if (note.body.trim().isEmpty)
          Text(
            '아직 내용이 없어요. 편집을 눌러 적어보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          )
        else
          MarkdownView(source: note.body, onCheckbox: _toggleCheckbox),
      ],
    );
  }
}

// ── 블록 편집기 ──

/// 노션식 블록 편집기
///
/// 줄 하나가 블록 하나다. `# `, `- `, `- [ ] ` 처럼 기호를 치고 스페이스를 누르면
/// 기호는 사라지고 그 줄이 바로 제목·목록·체크박스로 바뀐다.
/// 저장은 마크다운 원문으로 돌려준다.
class _BlockEditor extends StatefulWidget {
  _BlockEditor({required this.source, required this.onChanged});

  final String source;

  /// 마크다운 원문
  final ValueChanged<String> onChanged;

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  late final List<_Block> _blocks = _parse(widget.source);

  /// 명령어 메뉴가 열린 블록과 검색어
  _Block? _menuBlock;
  String _query = '';

  final _link = LayerLink();

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_serialize(_blocks));

  /// 위젯이 붙은 다음에 커서를 옮긴다 (새로 만든 블록은 아직 트리에 없다)
  void _focus(_Block block, {int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      block.focus.requestFocus();
      final at = offset ?? block.controller.text.length;
      block.controller.selection = TextSelection.collapsed(offset: at);
    });
  }

  // ── 입력 처리 ──

  void _onChanged(int index) {
    final block = _blocks[index];
    final text = block.controller.text;

    // 엔터는 줄바꿈 문자로 들어온다 — 그 자리에서 블록을 나눈다
    final br = text.indexOf('\n');
    if (br >= 0) {
      _enter(index, br);
      return;
    }

    // 기호 + 스페이스를 치면 바로 그 블록으로 바뀐다
    final shortcut = _shortcutOf(text);
    if (shortcut != null) {
      setState(() {
        block.type = shortcut.$1;
        block.controller.text = text.substring(shortcut.$2);
        block.controller.selection = TextSelection.collapsed(offset: 0);
        _menuBlock = null;
      });
      _emit();
      return;
    }

    setState(() => _updateMenu(block));
    _emit();
  }

  /// 줄바꿈이 들어온 지점에서 블록을 둘로 나눈다
  void _enter(int index, int br) {
    final block = _blocks[index];
    final text = block.controller.text;
    final before = text.substring(0, br);
    final after = text.substring(br + 1);

    // '---' 한 줄이면 구분선으로 바꾼다
    if (before.trim() == '---') {
      final next = _Block(text: after);
      setState(() {
        block.type = _BlockType.divider;
        block.controller.text = '';
        _blocks.insert(index + 1, next);
        _menuBlock = null;
      });
      _focus(next, offset: 0);
      _emit();
      return;
    }

    // 빈 목록·인용 블록에서 엔터를 치면 문단으로 되돌린다
    if (before.isEmpty && block.type != _BlockType.paragraph) {
      setState(() {
        block.type = _BlockType.paragraph;
        block.checked = false;
        block.controller.text = after;
        _menuBlock = null;
      });
      _focus(block, offset: 0);
      _emit();
      return;
    }

    final next = _Block(type: _inherit(block.type), text: after);
    setState(() {
      block.controller.text = before;
      _blocks.insert(index + 1, next);
      _menuBlock = null;
    });
    _focus(next, offset: 0);
    _emit();
  }

  /// 줄 맨 앞에서 백스페이스 — 블록 종류를 풀거나 앞 블록과 합친다
  void _backspace(int index) {
    final block = _blocks[index];

    if (block.type != _BlockType.paragraph) {
      setState(() {
        block.type = _BlockType.paragraph;
        block.checked = false;
      });
      _emit();
      return;
    }
    if (index == 0) return;

    final previous = _blocks[index - 1];
    if (previous.type == _BlockType.divider) {
      setState(() {
        _blocks.removeAt(index - 1);
        previous.dispose();
      });
      _emit();
      return;
    }

    final offset = previous.controller.text.length;
    setState(() {
      previous.controller.text =
          previous.controller.text + block.controller.text;
      _blocks.removeAt(index);
    });
    _focus(previous, offset: offset);
    block.dispose();
    _emit();
  }

  // ── 슬래시 명령어 ──

  void _updateMenu(_Block block) {
    final text = block.controller.text;
    final cursor = block.controller.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      _menuBlock = null;
      return;
    }

    var i = cursor - 1;
    while (i >= 0) {
      if (text[i] == '/') break;
      // 공백을 만나면 명령어가 아니다
      if (text[i] == ' ') {
        _menuBlock = null;
        return;
      }
      i--;
    }
    if (i < 0 || (i > 0 && text[i - 1] != ' ')) {
      _menuBlock = null;
      return;
    }

    _menuBlock = block;
    _query = text.substring(i + 1, cursor);
  }

  List<_Command> get _matches => _query.isEmpty
      ? _commands
      : _commands
            .where(
              (c) =>
                  c.label.contains(_query) ||
                  c.hint.startsWith(_query) ||
                  c.keyword.contains(_query.toLowerCase()),
            )
            .toList();

  /// 고른 명령어 적용 — '/검색어'는 지우고 블록 종류를 바꾼다
  void _run(_Block block, _Command command) {
    final text = block.controller.text;
    final cursor = block.controller.selection.baseOffset.clamp(0, text.length);
    final start = (cursor - _query.length - 1).clamp(0, text.length);
    final stripped = text.replaceRange(start, cursor, '');
    final index = _blocks.indexOf(block);

    setState(() {
      _menuBlock = null;
      block.controller.text = stripped;

      switch (command.type) {
        case _Type.block:
          block.type = command.block!;
          if (command.block == _BlockType.divider) {
            // 구분선 뒤에는 이어서 쓸 빈 줄을 하나 둔다
            final next = _Block(text: stripped);
            block.controller.text = '';
            _blocks.insert(index + 1, next);
            _focus(next, offset: 0);
          } else {
            _focus(block, offset: start);
          }
        case _Type.wrap:
          // 인라인 기호는 글자 사이에 커서를 둔다
          block.controller.text = stripped.replaceRange(
            start,
            start,
            '${command.token}${command.token}',
          );
          _focus(block, offset: start + command.token.length);
      }
    });
    _emit();
  }

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) _blocks.add(_Block());

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.gray20,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _blocks.length; i++)
            _BlockRow(
              block: _blocks[i],
              number: _numberOf(i),
              // 처음이자 비어 있는 블록에만 안내를 띄운다
              hint: _blocks.length == 1 && _blocks[i].controller.text.isEmpty
                  ? "'/'를 입력하면 명령어가 나와요"
                  : null,
              link: _blocks[i] == _menuBlock ? _link : null,
              onChanged: () => _onChanged(i),
              onBackspace: () => _backspace(i),
              onCheck: () {
                setState(() => _blocks[i].checked = !_blocks[i].checked);
                _emit();
              },
              onTap: () => setState(() => _menuBlock = null),
            ),
          // 아래 빈 곳을 눌러도 마지막 줄에 커서가 간다
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focus(_blocks.last),
            child: SizedBox(height: 120, width: double.infinity),
          ),
          if (_menuBlock != null && _matches.isNotEmpty)
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(0, 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: _SlashMenu(
                  commands: _matches,
                  onPick: (command) => _run(_menuBlock!, command),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 번호 목록은 위로 이어지는 번호 블록을 세어 번호를 매긴다
  int _numberOf(int index) {
    if (_blocks[index].type != _BlockType.numbered) return 0;
    var number = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (_blocks[i].type != _BlockType.numbered) break;
      number++;
    }
    return number;
  }
}

/// 블록 한 줄 — 종류에 맞는 글꼴과 앞머리(글머리표·번호·체크박스)를 붙인다
class _BlockRow extends StatelessWidget {
  _BlockRow({
    required this.block,
    required this.number,
    required this.hint,
    required this.link,
    required this.onChanged,
    required this.onBackspace,
    required this.onCheck,
    required this.onTap,
  });

  final _Block block;
  final int number;
  final String? hint;

  /// 명령어 메뉴가 이 블록에 붙어 있으면 위치 기준을 잡아준다
  final LayerLink? link;
  final VoidCallback onChanged;
  final VoidCallback onBackspace;
  final VoidCallback onCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (block.type == _BlockType.divider) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Container(height: 1, color: AppColors.gray200),
      );
    }

    final done = block.type == _BlockType.todo && block.checked;
    final style = switch (block.type) {
      _BlockType.h1 => AppTextStyles.title2,
      _BlockType.h2 => AppTextStyles.title3,
      _BlockType.h3 => AppTextStyles.body1.copyWith(
        fontWeight: FontWeight.w700,
      ),
      _BlockType.quote => AppTextStyles.body2.copyWith(
        height: 1.7,
        color: AppColors.textSecondary,
      ),
      _ => AppTextStyles.body2.copyWith(
        height: 1.7,
        color: done ? AppColors.textTertiary : AppColors.textPrimary,
        decoration: done ? TextDecoration.lineThrough : null,
        decorationColor: AppColors.gray400,
      ),
    };

    final field = Focus(
      // 줄 맨 앞에서 백스페이스를 누르면 종류를 풀거나 앞줄과 합친다
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        final selection = block.controller.selection;
        if (!selection.isCollapsed || selection.baseOffset != 0) {
          return KeyEventResult.ignored;
        }
        onBackspace();
        return KeyEventResult.handled;
      },
      child: TextField(
        controller: block.controller,
        focusNode: block.focus,
        style: style,
        cursorColor: AppColors.primary,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        onChanged: (_) => onChanged(),
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: block.type == _BlockType.h1 || block.type == _BlockType.h2
            ? 10
            : 3,
        bottom: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.type == _BlockType.quote)
            Container(
              width: 3,
              height: 22,
              margin: EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (block.type == _BlockType.bullet)
            SizedBox(
              width: 20,
              child: Text(
                '•',
                style: AppTextStyles.body2.copyWith(
                  height: 1.7,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          if (block.type == _BlockType.numbered)
            SizedBox(
              width: 22,
              child: Text(
                '$number.',
                style: AppTextStyles.body2.copyWith(
                  height: 1.7,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          if (block.type == _BlockType.todo)
            Padding(
              padding: EdgeInsets.only(right: 10, top: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCheck,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: block.checked
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: block.checked
                            ? AppColors.primary
                            : AppColors.gray300,
                        width: 1.5,
                      ),
                    ),
                    child: block.checked
                        ? Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          Expanded(
            child: link == null
                ? field
                : CompositedTransformTarget(link: link!, child: field),
          ),
        ],
      ),
    );
  }
}

/// 편집기의 블록 한 개
class _Block {
  _Block({
    this.type = _BlockType.paragraph,
    String text = '',
    this.checked = false,
  }) : controller = TextEditingController(text: text);

  _BlockType type;
  bool checked;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

enum _BlockType {
  paragraph,
  h1,
  h2,
  h3,
  bullet,
  numbered,
  todo,
  quote,
  divider,
}

/// 엔터를 쳤을 때 새 블록이 물려받을 종류 (목록은 이어지고 나머지는 문단)
_BlockType _inherit(_BlockType type) => switch (type) {
  _BlockType.bullet || _BlockType.numbered || _BlockType.todo => type,
  _ => _BlockType.paragraph,
};

/// 기호 + 스페이스 단축 입력 — (바뀔 종류, 지울 글자 수)
(_BlockType, int)? _shortcutOf(String text) {
  const shortcuts = {
    '# ': _BlockType.h1,
    '## ': _BlockType.h2,
    '### ': _BlockType.h3,
    '- ': _BlockType.bullet,
    '* ': _BlockType.bullet,
    '1. ': _BlockType.numbered,
    '[] ': _BlockType.todo,
    '[ ] ': _BlockType.todo,
    '> ': _BlockType.quote,
  };
  for (final entry in shortcuts.entries) {
    if (text.startsWith(entry.key)) return (entry.value, entry.key.length);
  }
  return null;
}

/// 마크다운 원문 → 블록
List<_Block> _parse(String source) {
  final blocks = <_Block>[];
  for (final line in source.split('\n')) {
    final trimmed = line.trimRight();
    if (trimmed.trim() == '---') {
      blocks.add(_Block(type: _BlockType.divider));
      continue;
    }
    final checkbox = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s*(.*)$').firstMatch(line);
    if (checkbox != null) {
      blocks.add(
        _Block(
          type: _BlockType.todo,
          text: checkbox[2]!,
          checked: checkbox[1]!.toLowerCase() == 'x',
        ),
      );
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      blocks.add(
        _Block(
          type: switch (heading[1]!.length) {
            1 => _BlockType.h1,
            2 => _BlockType.h2,
            _ => _BlockType.h3,
          },
          text: heading[2]!,
        ),
      );
      continue;
    }
    final ordered = RegExp(r'^\s*\d+\.\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      blocks.add(_Block(type: _BlockType.numbered, text: ordered[1]!));
      continue;
    }
    final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      blocks.add(_Block(type: _BlockType.bullet, text: bullet[1]!));
      continue;
    }
    if (line.trimLeft().startsWith('> ')) {
      blocks.add(
        _Block(type: _BlockType.quote, text: line.trimLeft().substring(2)),
      );
      continue;
    }
    blocks.add(_Block(text: trimmed));
  }
  if (blocks.isEmpty) blocks.add(_Block());
  return blocks;
}

/// 블록 → 마크다운 원문 (저장·읽기 모드에서 쓴다)
String _serialize(List<_Block> blocks) {
  var number = 0;
  final lines = <String>[];
  for (final block in blocks) {
    final text = block.controller.text;
    number = block.type == _BlockType.numbered ? number + 1 : 0;
    lines.add(switch (block.type) {
      _BlockType.h1 => '# $text',
      _BlockType.h2 => '## $text',
      _BlockType.h3 => '### $text',
      _BlockType.bullet => '- $text',
      _BlockType.numbered => '$number. $text',
      _BlockType.todo => '- [${block.checked ? 'x' : ' '}] $text',
      _BlockType.quote => '> $text',
      _BlockType.divider => '---',
      _BlockType.paragraph => text,
    });
  }
  return lines.join('\n');
}

/// 커서 아래에 뜨는 '/' 명령어 메뉴
class _SlashMenu extends StatelessWidget {
  _SlashMenu({required this.commands, required this.onPick});

  final List<_Command> commands;
  final ValueChanged<_Command> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 260,
        constraints: BoxConstraints(maxHeight: 300),
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final command in commands)
                _CommandRow(command: command, onTap: () => onPick(command)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatefulWidget {
  _CommandRow({required this.command, required this.onTap});

  final _Command command;
  final VoidCallback onTap;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final command = widget.command;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? AppColors.gray50 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  command.icon,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  command.label,
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                command.hint,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: ['monospace'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 마크다운 문법 도움말 (달력 옆 버튼으로 펼친다)
class _HelpPanel extends StatelessWidget {
  _HelpPanel();

  static const _rows = [
    ('/', '명령어 메뉴 열기'),
    ('# ', '제목'),
    ('## ', '소제목'),
    ('### ', '작은 제목'),
    ('- ', '글머리 목록'),
    ('1. ', '번호 목록'),
    ('- [ ] ', '체크박스'),
    ('> ', '인용'),
    ('---', '구분선'),
    ('**굵게**', '굵은 글씨'),
    ('*기울임*', '기울임'),
    ('`코드`', '인라인 코드'),
    ('~~취소~~', '취소선'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.gray20,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          for (final (token, label) in _rows)
            SizedBox(
              width: 190,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: Text(
                      token,
                      style: TextStyle(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: ['monospace'],
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 참석자 고르는 알약
class _PersonChip extends StatelessWidget {
  _PersonChip({required this.staff, required this.joined, required this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: staff.name, size: 22),
            SizedBox(width: 6),
            Text(
              staff.name == me ? '나' : staff.name,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: joined ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 슬래시 명령어 목록 ──

/// 명령어가 본문에 적용되는 방식
enum _Type {
  /// 블록 종류를 바꾼다
  block,

  /// 인라인 기호로 감싼다
  wrap,
}

class _Command {
  const _Command({
    required this.label,
    required this.hint,
    required this.keyword,
    required this.icon,
    required this.type,
    this.block,
    this.token = '',
  });

  final String label;

  /// 오른쪽에 보여줄 마크다운 기호
  final String hint;

  /// 영문으로 쳐도 걸리게 하는 검색어
  final String keyword;
  final IconData icon;
  final _Type type;

  /// block 방식일 때 바뀔 종류
  final _BlockType? block;

  /// wrap 방식일 때 감쌀 기호
  final String token;
}

const _commands = [
  _Command(
    label: '제목',
    hint: '#',
    keyword: 'h1 title',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h1,
  ),
  _Command(
    label: '소제목',
    hint: '##',
    keyword: 'h2',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h2,
  ),
  _Command(
    label: '작은 제목',
    hint: '###',
    keyword: 'h3',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h3,
  ),
  _Command(
    label: '글머리 목록',
    hint: '-',
    keyword: 'list bullet',
    icon: Icons.format_list_bulleted_rounded,
    type: _Type.block,
    block: _BlockType.bullet,
  ),
  _Command(
    label: '번호 목록',
    hint: '1.',
    keyword: 'number ol',
    icon: Icons.format_list_numbered_rounded,
    type: _Type.block,
    block: _BlockType.numbered,
  ),
  _Command(
    label: '체크박스',
    hint: '[]',
    keyword: 'todo check',
    icon: Icons.checklist_rounded,
    type: _Type.block,
    block: _BlockType.todo,
  ),
  _Command(
    label: '인용',
    hint: '>',
    keyword: 'quote',
    icon: Icons.format_quote_rounded,
    type: _Type.block,
    block: _BlockType.quote,
  ),
  _Command(
    label: '구분선',
    hint: '---',
    keyword: 'divider line hr',
    icon: Icons.horizontal_rule_rounded,
    type: _Type.block,
    block: _BlockType.divider,
  ),
  _Command(
    label: '문단',
    hint: 'p',
    keyword: 'text paragraph',
    icon: Icons.notes_rounded,
    type: _Type.block,
    block: _BlockType.paragraph,
  ),
  _Command(
    label: '굵게',
    hint: '**',
    keyword: 'bold',
    icon: Icons.format_bold_rounded,
    type: _Type.wrap,
    token: '**',
  ),
  _Command(
    label: '인라인 코드',
    hint: '`',
    keyword: 'code',
    icon: Icons.code_rounded,
    type: _Type.wrap,
    token: '`',
  ),
];

// ── 데이터 (목업) ──

/// 회의록 한 건 — 본문은 마크다운 원문 그대로 담는다
class _Note {
  _Note({
    required this.title,
    required this.date,
    required this.members,
    required this.body,
    required this.updated,
  });

  String title;
  DateTime date;
  List<String> members;
  String body;
  DateTime updated;

  String get displayTitle => title.isEmpty ? '제목 없는 회의록' : title;

  /// 목록에 보여줄 첫 줄 (마크다운 기호는 떼고)
  String get preview {
    for (final line in body.split('\n')) {
      final text = line
          .replaceAll(RegExp(r'^(#{1,3} |[-*] \[[ xX]\] |[-*] |> |\d+\. )'), '')
          .replaceAll(RegExp(r'[*`~]'), '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '내용 없음';
  }
}

/// 작성된 회의록 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _notes = <_Note>[..._seed()];

List<_Note> _seed() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  return [
    _Note(
      title: '주간 운영 회의',
      date: day(0),
      members: [me, '민중기', '이준승', '전상현'],
      updated: now,
      body: '''
## 안건
1. 지난주 매출 리뷰
2. 여름 이벤트 진행 상황
3. 기구 교체 일정

## 논의 내용
- 지난주 신규 등록 **18건**, 전주 대비 3건 증가
- 재등록률은 62%로 목표(65%)에 조금 못 미침
- 여름 이벤트 포스터 시안 확정, 인스타 예약 발행만 남음
> 경품은 단가를 낮추더라도 수량을 늘리는 쪽이 반응이 좋다는 의견

## 결정 사항
- 이벤트 경품은 **소형 3종 + 대형 1종**으로 확정
- 재등록 상담은 만료 2주 전부터 시작

## 할 일
- [x] 포스터 시안 확정
- [ ] 인스타 예약 발행
- [ ] 만료 예정 회원 명단 정리
- [ ] 기구 교체 견적 재확인
''',
    ),
    _Note(
      title: '여름 이벤트 킥오프',
      date: day(-3),
      members: [me, '민중기', '박준현'],
      updated: day(-3),
      body: '''
## 목표
7~8월 신규 회원 **50명** 유치

## 역할 분담
- 포스터·SNS: 전상현
- 경품 발주: 박준현
- 현장 안내: 김은후

## 일정
| 준비 기간은 2주로 잡고, 마감은 이벤트 시작 3일 전까지

- [x] 컨셉 확정
- [x] 예산 승인
- [ ] 현수막 설치
''',
    ),
    _Note(
      title: '신규 트레이너 교육 정리',
      date: day(-8),
      members: [me, '유찬빈'],
      updated: day(-8),
      body: '''
## 교육 과정
1. 센터 규정과 근무 수칙
2. 회원 응대 기본
3. 기구 사용법과 안전 수칙

## 참고
- 교육 자료는 문서함 `트레이너 온보딩` 폴더에 정리
- 첫 주는 선임 트레이너가 동행

## 피드백
- 실습 시간이 부족하다는 의견 → 다음 기수부터 실습 비중 확대
''',
    ),
  ];
}

// ── 표시용 계산 ──

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _weekday(DateTime time) => _weekdays[time.weekday % 7];

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';
