part of 'meeting_screen.dart';

// ── 폰 화면 ──

/// 폰: 회의록 카드 목록. 카드를 누르면 본문이 옆에서 밀려 들어온다.
class _MeetingPhone extends StatelessWidget {
  _MeetingPhone({
    required this.notes,
    required this.onChanged,
    required this.onRetry,
  });

  final List<_Note> notes;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;

  /// 본문에서 바꾼 내용이 목록에도 반영되도록 알린다
  final VoidCallback onChanged;

  Future<void> _open(
    BuildContext context,
    _Note note, {
    bool editing = false,
  }) async {
    final result = await Navigator.push<String>(
      context,
      CupertinoPageRoute(
        builder: (_) => _NoteScreen(note: note, editing: editing),
      ),
    );
    if (!context.mounted) return;
    if (result == 'delete') {
      try {
        await _deleteNote(note);
        if (context.mounted) AppToast.show(context, '회의록을 삭제했어요');
      } catch (error) {
        if (context.mounted) AppToast.show(context, messageOf(error));
      }
    } else if (note.id == null) {
      // 아무것도 안 적어서 안 올라간 새 회의록은 목록에 남기지 않는다
      _notes.remove(note);
    }
    onChanged();
  }

  Future<void> _create(BuildContext context) async {
    final now = DateTime.now();
    final note = _Note(
      title: '',
      date: DateTime(now.year, now.month, now.day),
      members: [me],
      body: '',
      updated: now,
    );
    _notes.add(note);
    onChanged();
    await _open(context, note, editing: true);
  }

  @override
  Widget build(BuildContext context) {
    return PhoneListScaffold(
      title: '회의록',
      count: notes.length,
      onCreate: () => _create(context),
      children: [
        if (notes.isEmpty)
          if (onRetry case final retry?)
            FailedCard(onRetry: retry)
          else
            EmptyCard(icon: Icons.description_outlined, text: '작성된 회의록이 없어요')
        else
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0) SizedBox(height: 12),
            _NoteCard(note: notes[i], onTap: () => _open(context, notes[i])),
          ],
      ],
    );
  }
}

/// 폰 목록 카드 — 제목·첫 줄 미리보기·날짜·참석자
class _NoteCard extends StatelessWidget {
  _NoteCard({required this.note, required this.onTap});

  final _Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              note.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${_date(note.date)} (${_weekday(note.date)}) · 참석 ${note.members.length}명',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                Spacer(),
                AvatarStack(names: note.members, size: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 폰 본문 화면 — 삭제를 누르면 'delete'를 돌려주고 목록이 지운다
class _NoteScreen extends StatefulWidget {
  _NoteScreen({required this.note, required this.editing});

  final _Note note;
  final bool editing;

  @override
  State<_NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<_NoteScreen> {
  late bool _editing = widget.editing;

  /// 편집을 마쳤다 — 여기서 서버에 올리거나 고친다
  Future<void> _toggleEdit() async {
    if (!_editing) {
      setState(() => _editing = true);
      return;
    }
    final isNew = widget.note.id == null;
    setState(() => _editing = false);
    try {
      await _saveNote(widget.note);
      if (!mounted) return;
      setState(() {});
      // 아무것도 안 적어서 안 올라간 새 글은 알릴 것이 없다
      if (widget.note.id != null) {
        AppToast.show(context, isNew ? '회의록을 올렸어요' : '회의록을 수정했어요');
      }
    } catch (error) {
      if (!mounted) return;
      // 실패하면 적던 내용을 지키기 위해 편집 상태로 되돌린다
      setState(() => _editing = true);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 남이 쓴 회의록은 읽기만 한다 (서버가 작성자·관리자만 통과시킨다)
    final canEdit = widget.note.canEdit;

    return PhoneDetailScaffold(
      title: '회의록',
      // 편집·삭제는 헤더 글래스 버튼으로 올린다
      actions: [
        if (_editing)
          GlassIconButton(
            symbol: 'trash',
            symbolColor: AppColors.error,
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
        if (canEdit)
          GlassIconButton(
            // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
            stableId: 'edit',
            symbol: _editing ? 'checkmark' : 'square.and.pencil',
            symbolColor: _editing ? AppColors.primary : null,
            onPressed: _toggleEdit,
          ),
      ],
      child: _NoteView(
        note: widget.note,
        editing: _editing,
        onChanged: () => setState(() {}),
        onDelete: () => Navigator.pop(context, 'delete'),
        onToggleEdit: _toggleEdit,
        phone: true,
      ),
    );
  }
}
