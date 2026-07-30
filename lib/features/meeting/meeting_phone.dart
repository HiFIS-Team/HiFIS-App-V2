part of 'meeting_screen.dart';

// ── 폰 화면 ──

/// 폰 목록이 비었을 때 — 알림 화면과 같은 빈 카드를 목록 자리에 올린다
Widget _emptyCard({required IconData icon, required String text}) => Align(
  alignment: Alignment.topCenter,
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: EmptyCard(icon: icon, text: text),
  ),
);

/// 폰: 회의록 카드 목록. 카드를 누르면 본문이 옆에서 밀려 들어온다.
class _MeetingPhone extends StatelessWidget {
  _MeetingPhone({required this.notes, required this.onChanged});

  final List<_Note> notes;

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
      _notes.remove(note);
      AppToast.show(context, '회의록을 삭제했어요');
    } else if (note.title.isEmpty && note.body.trim().isEmpty) {
      // 아무것도 안 적고 나온 새 회의록은 목록에 남기지 않는다
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 글래스 헤더 버튼 영역만큼 비워둔다
            SizedBox(height: 64),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Text('회의록', style: AppTextStyles.title1),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${notes.length}',
                      style: AppTextStyles.title2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  ActionPill(
                    icon: Icons.add_rounded,
                    label: '새 회의록',
                    onTap: () => _create(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notes.isEmpty
                  ? _emptyCard(
                      icon: Icons.description_outlined,
                      text: '작성된 회의록이 없어요',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        bottomBarInset(context),
                      ),
                      itemCount: notes.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12),
                      itemBuilder: (context, i) => _NoteCard(
                        note: notes[i],
                        onTap: () => _open(context, notes[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
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
  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '회의록',
      child: _NoteView(
        note: widget.note,
        editing: widget.editing,
        onChanged: () => setState(() {}),
        onDelete: () => Navigator.pop(context, 'delete'),
        phone: true,
      ),
    );
  }
}
