import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../project/project_screen.dart';
import '../../core/api/client/api_exception.dart';
import '../../core/api/project/meeting_api.dart';
import '../../core/api/project/project_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/rich_blocks.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/scroll_box.dart';
import '../../core/widgets/editor/block_editor.dart';
import '../../core/widgets/editor/markdown_view.dart';
import '../../core/widgets/editor/post_actions.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_menu.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/failed_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/util/screen_refresh.dart';
import '../../core/util/skeleton_delay.dart';

part 'meeting_phone.dart';

/// 회의록 화면
///
/// 데스크톱은 좌측 목록 + 우측 본문 2단 구조.
/// 폰은 같은 내용을 목록 화면 + 본문 화면 두 장으로 나눠 보여준다.
/// 본문은 마크다운으로 적고, 평소에는 렌더링된 모습으로 읽는다.
///
/// 서버는 본문을 블록 트리로 들고 있어서 오갈 때 옮겨 담는다
/// ([blocksFromMarkdown] · [markdownFromBlocks]).
class MeetingScreen extends StatefulWidget {
  MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with ScreenRefresh<MeetingScreen>, SkeletonDelay<MeetingScreen> {
  _Note? _selected;

  /// 새로 만든 회의록은 바로 편집 모드로 연다
  bool _startEditing = false;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    // 받아 둔 목록이 있으면 뼈대 없이 시작한다 (다시 열 때 안 깜빡인다)
    if (_notesLoaded) skipFirstSkeleton();
    _load();
  }

  /// 못 받았다 — **목록이 비어 있을 때만** 실패 카드를 낸다.
  /// 받아 둔 목록이 있으면 그대로 보여준다 (공지와 같은 규칙).
  bool _failed = false;

  Future<void> _load() async {
    try {
      await _loadNotes();
      _failed = false;
    } catch (error) {
      _failed = true;
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  void _retry() {
    setState(beginLoad);
    _load();
  }

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

  /// 편집을 마쳤다 — 여기서 서버에 올리거나 고친다
  Future<void> _finishEditing(_Note note) async {
    setState(() => _startEditing = false);
    final isNew = note.id == null;
    try {
      await _saveNote(note);
      if (!mounted) return;
      // 아무것도 안 적고 끝낸 새 글은 목록에 남기지 않는다
      if (note.id == null) {
        setState(() {
          _notes.remove(note);
          _selected = null;
        });
        return;
      }
      setState(() {});
      AppToast.show(context, isNew ? '회의록을 올렸어요' : '회의록을 수정했어요');
    } catch (error) {
      if (!mounted) return;
      // 실패하면 적던 내용을 지키기 위해 편집 상태로 되돌린다
      setState(() => _startEditing = true);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete(_Note note) async {
    // 여럿이 같이 보는 기록이라 한 번 더 묻는다 (공지·문서함과 같은 기준)
    final ok = await showConfirmDialog(
      context,
      title: '이 회의록을 지울까요?',
      message: '지우면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _deleteNote(note);
      if (!mounted) return;
      setState(() => _selected = null);
      AppToast.show(context, '회의록을 삭제했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) {
      if (!isDesktop) return _MeetingSkeleton();
      return SkeletonTwoPane(rows: 6, filter: false);
    }

    final list = _sorted;

    if (!isDesktop) {
      return _MeetingPhone(
        notes: list,
        onChanged: () => setState(() {}),
        // 못 받았고 보여줄 것도 없을 때만 다시 받기를 낸다
        onRetry: _failed && list.isEmpty ? _retry : null,
      );
    }

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
                onRetry: _failed && list.isEmpty ? _retry : null,
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
                    onToggleEdit: () => _startEditing
                        ? _finishEditing(selected)
                        : setState(() => _startEditing = true),
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
    required this.onRetry,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Note> notes;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;
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
              // Expanded 안에서 카드가 세로로 늘어나지 않게 위에 붙인다
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: onRetry != null
                        ? FailedCard(onRetry: onRetry!)
                        : EmptyCard(
                            icon: Icons.description_outlined,
                            text: '작성된 회의록이 없어요',
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

// ── 회의록 → 프로젝트 ──

/// 본문에서 체크박스 줄만 뽑는다 — `- [ ] 현수막 교체` → `현수막 교체`
///
/// **회의에서 이미 체크한 것도 담는다.** 프로젝트에서는 다시 확인하고
/// 누르는 게 보통이라 체크 상태는 안 가져온다 (2026-08-14 결정).
List<String> _checkboxesOf(String body) => [
  for (final line in body.split('\n'))
    if (RegExp(r'^\s*[-*]\s+\[[ xX]\]\s*(.+)$').firstMatch(line) case final m?)
      m.group(1)!.trim(),
];

/// 첫 문단 — 프로젝트 설명 자리에 넣는다 (체크박스·제목 줄은 뺀다)
String _firstParagraphOf(String body) {
  for (final line in body.split('\n')) {
    final text = line.trim();
    if (text.isEmpty) continue;
    if (text.startsWith('#') || RegExp(r'^[-*>]').hasMatch(text)) continue;
    return text;
  }
  return '';
}

/// 회의록을 프로젝트로 옮긴다
///
/// **채워진 프로젝트 생성 폼이 그대로 열린다** — 제목·설명·참여 멤버·할 일이
/// 미리 들어가 있고, 마감일·색·담당만 손보면 된다. 아래 `옮기기` 를 누르면
/// 만들어지고 **이 회의록을 그 프로젝트에 건다** — 나중에 "이 프로젝트가
/// 어느 회의에서 나왔나" 가 남는다.
///
/// **폰 헤더 버튼과 PC 제목 옆 버튼이 이 함수 하나를 부른다.** 위젯 밖에
/// 둔 이유가 그것이다 — 폰은 헤더가 `_NoteScreen`, 본문이 `_NoteView` 라
/// 상태를 나눠 갖고 있어서 안에 두면 한쪽에서 못 부른다.
Future<void> _moveNoteToProject(BuildContext context, _Note note) async {
  final projectId = await createProjectFrom(
    context,
    ProjectSeed(
      title: note.title,
      purpose: _firstParagraphOf(note.body),
      members: note.members,
      todos: _checkboxesOf(note.body),
    ),
  );
  if (projectId == null || !context.mounted) return;
  try {
    await MeetingApi.update(note.id!, projectId: projectId);
    note.projectId = projectId;
    if (context.mounted) AppToast.show(context, '프로젝트를 만들고 이 회의록을 걸었어요');
  } catch (error) {
    // 프로젝트는 이미 만들어졌다 — 연결만 실패한 것이라 그렇게 알린다
    if (context.mounted) AppToast.show(context, '프로젝트는 만들었는데 회의록 연결에 실패했어요');
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
    required this.onToggleEdit,
    this.phone = false,
  });

  final _Note note;

  /// 편집 상태 — 편집/완료 버튼을 어디에 두든 화면 쪽이 들고 있다
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleEdit;

  /// 폰은 편집·삭제를 헤더 글래스 버튼으로 올려서 본문에는 그리지 않는다
  final bool phone;

  @override
  State<_NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<_NoteView> {
  late final _title = TextEditingController(text: widget.note.title);
  final _titleFocus = FocusNode();

  /// 프로젝트 고르개가 뜰 자리 — 그 칩 아래에 붙는다
  final _projectKey = GlobalKey();

  bool get _editing => widget.editing;

  /// 마크다운 문법 도움말 펼침 상태
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_editing) _titleFocus.requestFocus();
  }

  @override
  void didUpdateWidget(_NoteView old) {
    super.didUpdateWidget(old);
    // 헤더 버튼으로 편집을 켰을 때도 제목부터 입력할 수 있게 한다
    if (_editing && !old.editing) _titleFocus.requestFocus();
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
    // 마치기 전에 제목을 모델에 옮겨 담아야 그 값이 서버로 간다
    if (_editing) _sync();
    widget.onToggleEdit();
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

  /// 이 회의록을 프로젝트에 건다 — 빼려면 맨 위 '전사 회의'를 고른다
  ///
  /// **공개 범위가 같이 간다.** 서버에서 `scope=PROJECT` 는 `projectId` 와 한 쌍이라
  /// 걸면 그 프로젝트 담당자·참석자·작성자·MASTER·ADMIN 만 보게 된다
  /// (backend-gap.md 44번). 따로 고르는 자리를 두면 둘이 어긋난다.
  Future<void> _pickProject() async {
    final note = widget.note;
    final picked = await showGlassMenu<String>(
      context: context,
      anchorKey: _projectKey,
      alignRight: false,
      width: 240,
      items: [
        GlassMenuItem(
          value: '',
          label: '전사 회의',
          icon: Icons.groups_rounded,
          selected: note.projectId == null,
        ),
        if (_projects.isNotEmpty) GlassMenuDivider<String>(),
        for (final project in _projects)
          GlassMenuItem(
            value: project.id,
            label: project.title,
            icon: Icons.folder_rounded,
            selected: note.projectId == project.id,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      note.projectId = picked.isEmpty ? null : picked;
      note.scope = picked.isEmpty ? MeetingScope.company : MeetingScope.project;
    });
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

  /// 회의록 → 프로젝트 (PC 는 제목 옆 버튼, 폰은 헤더 글래스 버튼)
  Future<void> _toProject() async {
    await _moveNoteToProject(context, widget.note);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final phone = widget.phone;

    /// 걸린 프로젝트 — 안 걸었으면 null 이라 읽을 때 그 칩이 안 나온다
    final linked = _projectOf(note.projectId);

    final title = _editing
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
        : Text(note.displayTitle, style: AppTextStyles.title1);

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editing) ...[
          Pressable(
            onTap: widget.onDelete,
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
        // 남이 쓴 회의록은 읽기만 한다 (서버가 작성자·관리자만 통과시킨다)
        // 회의록을 프로젝트로 옮긴다 — **이미 걸린 회의록에는 안 뜬다**
        // (하나의 회의록은 하나의 프로젝트. 다시 만들면 앞 연결이 끊긴다)
        if (!_editing && note.id != null && note.projectId == null) ...[
          Pressable(
            onTap: _toProject,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.create_new_folder_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '프로젝트로',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
        if (note.canEdit)
          Pressable(
            onTap: _toggleEdit,
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
                      color: _editing ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Stack(
      children: [
        ListView(
          // 아래는 **떠 있는 하트·댓글 바가 앉을 자리**를 비운다
          // ([PostActions.inset]) — 안 비우면 마지막 줄이 바에 가린다
          padding: phone
              // 폰 본문은 헤더 뒤로 스크롤되고, 하단바가 없어 화면 아래 여백만 남긴다
              ? EdgeInsets.fromLTRB(
                  20,
                  PhoneDetailScaffold.topPadding,
                  20,
                  MediaQuery.paddingOf(context).bottom + PostActions.inset,
                )
              : EdgeInsets.fromLTRB(
                  32,
                  64,
                  32,
                  bottomBarInset(context) + PostActions.inset,
                ),
          children: [
            // 폰은 편집·삭제가 헤더 글래스 버튼으로 올라가 제목만 남는다
            if (phone)
              title
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  SizedBox(width: 16),
                  actions,
                ],
              ),
            SizedBox(height: 10),
            // 날짜·참석자 — 편집 중에는 바로 고칠 수 있다
            if (_editing) ...[
              // 폰에서는 칩 셋이 한 줄에 안 들어가 다음 줄로 흐른다
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pressable(
                    onTap: _pickDate,
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
                  // 달력 옆 마크다운 문법 도움말 (펼침)
                  Pressable(
                    onTap: () => setState(() => _help = !_help),
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
                  // 어느 프로젝트 회의인지 — 안 걸면 전사 회의다
                  Pressable(
                    key: _projectKey,
                    onTap: _pickProject,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          linked == null
                              ? Icons.groups_rounded
                              : Icons.folder_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          linked?.title ?? '전사 회의',
                          style: AppTextStyles.body2.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_help) ...[SizedBox(height: 10), MarkdownHelpPanel()],
              SizedBox(height: 10),
              ScrollBox(
                maxHeight: kChipBoxHeight,
                child: Wrap(
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
                  // 프로젝트에 건 회의만 나온다 — 전사 회의에는 이 자리가 없다
                  if (linked != null) ...[
                    SizedBox(width: 10),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              linked.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            SizedBox(height: 14),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 14),
            if (_editing)
              BlockEditor(
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
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else
              MarkdownView(source: note.body, onCheckbox: _toggleCheckbox),
          ],
        ),
        // 하트·댓글 — 공지와 같은 자리, 같은 위젯 (2026-08-19).
        // **적는 중에는 안 그린다** — 예전 이모지 줄도 그랬다.
        // `top`·`bottom` 0 + [Center] 로 세로 가운데에 선다
        if (!_editing)
          Positioned(
            left: 0,
            right: 0,
            bottom: (phone ? MediaQuery.paddingOf(context).bottom : 0) + 16,
            child: Center(
              child: PostActions(
                target: ReactionTarget.meeting,
                targetId: note.id,
                reactions: note.reactions,
                onToggled: (reactions) {
                  note.reactions = reactions;
                  widget.onChanged();
                },
                commentCount: note.commentCount,
                onCommentCount: (count) {
                  note.commentCount = count;
                  widget.onChanged();
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  _PersonChip({required this.staff, required this.joined, required this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
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

// ── 데이터 ──

/// 회의록 한 건 — 본문은 마크다운 원문 그대로 담는다
///
/// 서버는 본문을 **블록 트리**로 들고 있어서 오갈 때 `rich_blocks.dart` 가
/// 옮겨 담는다 (backend-gap.md 42번).
class _Note {
  _Note({
    required this.title,
    required this.date,
    required this.members,
    required this.body,
    required this.updated,
    this.id,
    this.authorId,
    this.memberIds = const [],
    this.scope = MeetingScope.company,
    this.projectId,
    this.reactions = const [],
    this.commentCount = 0,
  });

  /// 서버 uuid — null 이면 아직 안 올린 것
  String? id;

  /// 작성자 — 본인이나 관리자만 고칠 수 있다 ([canEdit])
  String? authorId;

  String title;
  DateTime date;

  /// 참석자 이름 — 화면에 쓴다. 서버에는 [memberIds] 로 보낸다
  List<String> members;

  /// 참석자 uuid
  List<String> memberIds;

  String body;
  DateTime updated;

  /// 공개 범위 — **프로젝트를 걸면 [MeetingScope.project] 로 간다.**
  /// 짝이라 따로 고르지 않는다 (서버 `scope=PROJECT` 는 `projectId` 와 한 쌍이다)
  MeetingScope scope;

  /// 묶인 프로젝트 — null 이면 전사 회의다
  String? projectId;

  List<ReactionAgg> reactions;

  /// 달린 댓글 수 — 오른쪽 세로 줄의 말풍선 옆 숫자
  int commentCount;

  String get displayTitle => title.isEmpty ? '제목 없는 회의록' : title;

  /// 고치거나 지울 수 있는지 — 서버 `_get_owned` 와 같은 기준이다.
  /// 아직 안 올린 새 글은 열어 둔다 (안 그러면 쓰다 말고 저장도 못 한다)
  bool get canEdit =>
      id == null ||
      authorId == null ||
      authorId == currentUser?.id ||
      myRole.strong;

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

/// 받아 둔 회의록. 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _notes = <_Note>[];

/// 한 번이라도 받아왔는지 — 탭을 다시 열 때 빈 목록을 깜빡이지 않게 한다
bool _notesLoaded = false;

/// 로그아웃 때 비운다 — **다음 사람에게 앞사람 것이 보이면 안 된다**
void resetMeetingCache() {
  _notes.clear();
  _notesLoaded = false;
}

/// 회의록을 걸 수 있는 프로젝트 — 고르개와 걸린 이름 표시에 같이 쓴다
final _projects = <Project>[];

Future<void> _loadNotes() async {
  // 회의록과 같이 받는다 — 걸린 프로젝트 **이름**을 읽을 때도 써서
  // 고르개를 열 때 받으면 안 고치는 사람에게는 이름이 안 뜬다.
  // 서로 상관없는 요청이라 한 번에 던진다 (하나씩 기다리면 왕복이 두 배다)
  final got = await Future.wait<Object?>([
    MeetingApi.list(),
    ProjectApi.list(),
  ]);
  final rows = got[0] as List<Meeting>;
  final projects = got[1] as List<Project>;
  _notes
    ..clear()
    ..addAll([for (final row in rows) _fromServer(row)]);
  _projects
    ..clear()
    ..addAll(projects);
  _notesLoaded = true;
}

/// 걸린 프로젝트 — 지워졌으면 null 이라 화면에서 그 칩이 빠진다
Project? _projectOf(String? id) {
  if (id == null) return null;
  for (final project in _projects) {
    if (project.id == id) return project;
  }
  return null;
}

/// 서버 회의록 → 화면 모델
_Note _fromServer(Meeting row) => _Note(
  id: row.id,
  authorId: row.authorId,
  title: row.title,
  date: row.meetingAt,
  members: [
    for (final id in row.attendeeIds) ?StaffDirectory.instance.byId(id)?.name,
  ],
  memberIds: row.attendeeIds,
  body: markdownFromBlocks(row.blocks),
  // 서버가 고친 시각을 안 줘서 만든 시각을 쓴다 (backend-gap.md 43번)
  updated: row.createdAt,
  scope: row.scope,
  projectId: row.projectId,
  reactions: row.reactions,
  commentCount: row.commentCount,
);

/// 편집을 마쳤을 때 — 새 글이면 올리고, 있던 글이면 고친다
///
/// 제목·본문이 모두 비었으면 아무것도 안 한다. 빈 글로 시작하는 구조라
/// 작성을 눌렀다가 그냥 나가는 일이 흔한데, 그때마다 서버에 빈 회의록이 쌓인다.
Future<void> _saveNote(_Note note) async {
  if (note.title.trim().isEmpty && note.body.trim().isEmpty) return;

  final blocks = blocksFromMarkdown(note.body);
  final attendeeIds = [
    for (final name in note.members) ?StaffDirectory.instance.byName(name)?.id,
  ];

  final id = note.id;
  if (id == null) {
    final created = await MeetingApi.create(
      title: note.title,
      blocks: blocks,
      meetingAt: note.date,
      scope: note.scope,
      attendeeIds: attendeeIds,
      projectId: note.projectId,
    );
    note.id = created.id;
    note.authorId = created.authorId;
    note.memberIds = created.attendeeIds;
    note.reactions = created.reactions;
    return;
  }

  final saved = await MeetingApi.update(
    id,
    title: note.title,
    blocks: blocks,
    meetingAt: note.date,
    attendeeIds: attendeeIds,
    scope: note.scope,
    // 뺐으면 빈 문자열로 보내야 서버가 푼다 (null 은 "안 건드림")
    projectId: note.projectId ?? '',
  );
  note.memberIds = saved.attendeeIds;
}

/// 지우기 — 아직 안 올린 새 글은 서버를 부르지 않는다
Future<void> _deleteNote(_Note note) async {
  final id = note.id;
  if (id != null) await MeetingApi.delete(id);
  _notes.remove(note);
}

// ── 표시용 계산 ──

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _weekday(DateTime time) => _weekdays[time.weekday % 7];

/// '7.30' 형태
String _date(DateTime time) => dateLabel(time);
