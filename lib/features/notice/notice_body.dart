part of 'notice_screen.dart';

// ── 우측 본문 ──

class _NoticeView extends StatefulWidget {
  _NoticeView({
    super.key,
    required this.notice,
    required this.editing,
    required this.onChanged,
    required this.onDelete,
    required this.onToggleEdit,
    this.phone = false,
  });

  final _Notice notice;

  /// 편집 상태 — 편집/완료 버튼을 어디에 두든 화면 쪽이 들고 있다
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleEdit;

  /// 폰은 편집·삭제를 헤더 글래스 버튼으로 올려서 본문에는 그리지 않는다
  final bool phone;

  @override
  State<_NoticeView> createState() => _NoticeViewState();
}

class _NoticeViewState extends State<_NoticeView> {
  late final _title = TextEditingController(text: widget.notice.title);
  final _titleFocus = FocusNode();

  bool get _editing => widget.editing;
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_editing) _titleFocus.requestFocus();
  }

  @override
  void didUpdateWidget(_NoticeView old) {
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

  void _sync() {
    widget.notice.title = _title.text.trim();
    widget.onChanged();
  }

  void _toggleEdit() {
    if (_editing) _sync();
    widget.onToggleEdit();
  }

  /// 본문의 체크박스를 눌렀을 때 그 줄만 바꿔 쓴다
  void _toggleCheckbox(int line, bool checked) {
    final lines = widget.notice.body.split('\n');
    if (line >= lines.length) return;
    lines[line] = checked
        ? lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[x]')
        : lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[ ]');
    widget.notice.body = lines.join('\n');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final phone = widget.phone;

    final title = _editing
        ? TextField(
            controller: _title,
            focusNode: _titleFocus,
            style: AppTextStyles.title1,
            cursorColor: AppColors.primary,
            onChanged: (_) => _sync(),
            decoration: InputDecoration(
              hintText: '제목 없는 공지',
              hintStyle: AppTextStyles.title1.copyWith(
                color: AppColors.gray300,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          )
        : Text(notice.displayTitle, style: AppTextStyles.title1);

    final pin = notice.pinned && !_editing
        ? Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(
              Icons.push_pin_rounded,
              size: 20,
              color: AppColors.error,
            ),
          )
        : null;

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_canEdit(notice))
          // 권한이 없으면 버튼을 감추되, 왜 없는지는 알려 준다
          Text(
            '관리자·점장만 고칠 수 있어요',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
          ),
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
        if (_canEdit(notice))
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?pin,
                  Expanded(child: title),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?pin,
                  Expanded(child: title),
                  SizedBox(width: 16),
                  actions,
                ],
              ),
            SizedBox(height: 10),
            if (_editing) ...[
              Row(
                children: [
                  // 중요 공지는 목록 맨 위에 고정된다
                  Pressable(
                    onTap: () {
                      setState(() => notice.pinned = !notice.pinned);
                      widget.onChanged();
                    },
                    child: Container(
                      padding: EdgeInsets.fromLTRB(10, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: notice.pinned
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.gray50,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: notice.pinned
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '상단 고정',
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 14,
                              color: notice.pinned
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  // 마크다운 문법 도움말 (펼침)
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
                ],
              ),
              if (_help) ...[SizedBox(height: 10), MarkdownHelpPanel()],
            ] else
              Row(
                children: [
                  Avatar(name: notice.author, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '${notice.author} ${staffOf(notice.author).role} · ${_date(notice.date)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            SizedBox(height: 14),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 14),
            if (_editing)
              BlockEditor(
                source: notice.body,
                onChanged: (markdown) {
                  notice.body = markdown;
                  widget.onChanged();
                },
              )
            else ...[
              if (notice.body.trim().isEmpty)
                Text(
                  '아직 내용이 없어요. 편집을 눌러 적어보세요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              else
                MarkdownView(source: notice.body, onCheckbox: _toggleCheckbox),
              SizedBox(height: 24),
              _ReadCard(notice: notice),
            ],
          ],
        ),
        // 하트·댓글 — **화면 아래에 떠 있는 글래스 바**다 (2026-08-19).
        // 본문 안에 넣으면 글과 같이 스크롤돼서 내려야만 보인다
        Positioned(
          left: 0,
          right: 0,
          bottom: (phone ? MediaQuery.paddingOf(context).bottom : 0) + 16,
          child: Center(
            child: PostActions(
              target: ReactionTarget.notice,
              targetId: notice.id,
              reactions: notice.reactions,
              onToggled: (reactions) {
                notice.reactions = reactions;
                widget.onChanged();
              },
              commentCount: notice.commentCount,
              onCommentCount: (count) {
                notice.commentCount = count;
                widget.onChanged();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 읽음 현황 — 누가 확인했고 누가 안 봤는지
class _ReadCard extends StatelessWidget {
  _ReadCard({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: FutureBuilder<NoticeReaders>(
        // 본문을 볼 때만 따로 받는다 — 목록에는 인원수(readCount)만 있으면 된다
        future: _readersOf(notice),
        // 한 번 받아 둔 공지는 첫 프레임부터 그대로 그린다 (깜빡임 방지)
        initialData: notice.id == null ? null : _readersData[notice.id],
        builder: (context, snapshot) {
          final data = snapshot.data;
          final people = data?.people ?? const <NoticeReader>[];
          final total = data?.total ?? 0;
          final readCount = data?.readCount ?? notice.readCount;
          final allRead = data != null && readCount >= total && total > 0;

          // 서버가 읽은 사람을 앞에 놓아 주지만, 여기서 두 덩이로 가른다
          final read = [
            for (final person in people)
              if (person.read) person,
          ];
          final unread = [
            for (final person in people)
              if (!person.read) person,
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('확인 현황', style: AppTextStyles.label),
                  SizedBox(width: 6),
                  Text(
                    data == null ? '$readCount' : '$readCount/$total',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Spacer(),
                  if (allRead)
                    Text(
                      '모두 확인했어요',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              ProgressBar(
                ratio: total == 0 ? 0 : readCount / total,
                color: allRead ? AppColors.success : null,
              ),
              // 확인한 사람은 **이름까지** 보여준다 — 누가 봤는지가 알고 싶은 값이다
              if (read.isNotEmpty) ...[
                SizedBox(height: 18),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final person in read) _ReaderChip(name: person.name),
                  ],
                ),
              ],
              // 안 본 사람은 **아바타만** 촘촘히 — 스물이 넘어도 카드가 안 길어진다
              if (unread.isNotEmpty) ...[
                SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '아직 안 봤어요',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${unread.length}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final person in unread)
                      // 이름이 없으면 누구인지 모르니 길게 눌러 확인한다
                      Tooltip(
                        message: person.name,
                        child: Opacity(
                          opacity: 0.45,
                          child: Avatar(name: person.name, size: 30),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 확인 현황 — 같은 공지를 다시 열 때 또 받지 않도록 들고 있는다
final _readersCache = <String, Future<NoticeReaders>>{};

/// 이미 받아 둔 값 — `FutureBuilder` 의 **첫 프레임**을 채우는 데 쓴다
///
/// 캐시(위)만으로는 깜빡임이 안 없어진다. `FutureBuilder` 는 이미 끝난
/// Future 를 줘도 **첫 프레임은 `data == null`** 로 그린다 (마이크로태스크가
/// 한 번 돌아야 값이 붙는다). 그래서 공지를 옮길 때마다 확인 현황 카드가
/// 사람 알약 없이 한 번 그려졌다가 커지면서 아래가 밀렸다.
final _readersData = <String, NoticeReaders>{};

Future<NoticeReaders> _readersOf(_Notice notice) {
  final id = notice.id;
  if (id == null) {
    return Future.value(
      NoticeReaders(total: 0, readCount: 0, people: const []),
    );
  }
  // 실패한 요청은 남기지 않는다 — 캐시에 박히면 다시 열어도 영영 못 받는다
  return _readersCache[id] ??= NoticeApi.readers(id)
      .then((readers) {
        _readersData[id] = readers;
        return readers;
      })
      .catchError((Object error) {
        _readersCache.remove(id);
        throw error;
      });
}

/// 확인한 사람 알약 — 안 본 사람은 아바타만 그리므로 여기 안 온다
class _ReaderChip extends StatelessWidget {
  _ReaderChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(name: name, size: 22),
          SizedBox(width: 6),
          Text(
            name == me ? '나' : name,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
