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

  /// 확인 현황을 폈나 — **접힌 것이 기본**이다
  bool _readOpen = false;

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
            ] else ...[
              Row(
                children: [
                  Avatar(name: notice.author, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${notice.author} ${staffOf(notice.author).role} · ${_date(notice.date)}',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 확인 현황은 **여기 접어 둔다** — 눌러야 아래로 편다
                  _ReadPeek(
                    notice: notice,
                    open: _readOpen,
                    onTap: () => setState(() => _readOpen = !_readOpen),
                  ),
                ],
              ),
              if (_readOpen) ...[
                SizedBox(height: 12),
                _ReadCard(notice: notice),
              ],
            ],
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

/// 확인 현황을 **머리말 오른쪽에 접어 둔 것** — 누르면 아래로 편다
///
/// 예전에는 본문 아래에 카드로 늘 서 있었다. 스물세 명이면 이름 알약과
/// 아바타가 화면 한 판을 먹어서 **본문보다 눈에 먼저 들어왔다.**
/// 누가 봤는지는 궁금할 때만 여는 값이라 얼굴 셋과 `12/23` 만 남긴다.
class _ReadPeek extends StatelessWidget {
  _ReadPeek({required this.notice, required this.open, required this.onTap});

  final _Notice notice;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NoticeReaders>(
      future: _readersOf(notice),
      initialData: notice.id == null ? null : _readersData[notice.id],
      builder: (context, snapshot) {
        final data = snapshot.data;
        final read = [
          for (final person in data?.people ?? const <NoticeReader>[])
            if (person.read) person,
        ];
        // 아직 안 받았으면 목록에 있던 인원수로 버틴다 (칸이 비지 않게)
        final count = data?.readCount ?? notice.readCount;

        return Pressable(
          onTap: onTap,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (read.isNotEmpty) ...[
                _AvatarStack(people: read, size: 20, stride: 13, max: 3),
                SizedBox(width: 7),
              ],
              Text(
                data == null ? '$count' : '$count/${data.total}',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 펴 놓은 확인 현황 — 누가 확인했고 누가 안 봤는지
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
              // 아바타를 **겹쳐 한 줄**로 — 스물이 넘어도 카드 높이가 그대로다
              if (read.isNotEmpty) ...[
                SizedBox(height: 16),
                _StackRow(label: '확인', people: read),
              ],
              if (unread.isNotEmpty) ...[
                SizedBox(height: 10),
                _StackRow(label: '미확인', people: unread, faded: true),
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
/// 라벨 한 마디 + 겹친 아바타 한 줄
class _StackRow extends StatelessWidget {
  _StackRow({required this.label, required this.people, this.faded = false});

  final String label;
  final List<NoticeReader> people;

  /// 안 본 사람은 흐리게 — 라벨을 안 읽어도 색으로 갈린다
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: _AvatarStack(people: people, faded: faded),
        ),
      ],
    );
  }
}

/// 아바타를 **겹쳐 한 줄에** 세운다 — 넘치는 만큼은 `+N` 으로 접는다
///
/// 예전에는 확인한 사람을 이름 알약으로, 안 본 사람을 아바타로 `Wrap` 했다.
/// 스물세 명이면 그 두 덩이가 화면 한 판을 먹어서 **카드가 본문보다 길었다.**
/// 이름은 길게 눌러 확인한다.
class _AvatarStack extends StatelessWidget {
  _AvatarStack({
    required this.people,
    this.faded = false,
    this.size = 30,
    this.stride = 20,
    this.max,
  });

  final List<NoticeReader> people;
  final bool faded;
  final double size;

  /// 다음 아바타가 서는 자리 — 지름보다 작아야 겹친다
  final double stride;

  /// 폭에 맞추지 않고 **이만큼만** 세운다 (머리말 미리보기).
  /// 이때는 `+N` 을 안 붙인다 — 옆에 `12/23` 이 이미 서 있다
  final int? max;

  @override
  Widget build(BuildContext context) {
    if (max case final cap?) return _row(cap, more: false);
    // 들어가는 만큼만 세운다. 접을 것이 있으면 마지막 자리를 `+N` 에 내준다
    return LayoutBuilder(
      builder: (context, box) =>
          _row(((box.maxWidth - size) / stride).floor() + 1),
    );
  }

  Widget _row(int fit, {bool more = true}) {
    final cap = fit.clamp(1, people.length);
    final shown = people
        .take(more && cap < people.length ? cap - 1 : cap)
        .toList();
    final rest = people.length - shown.length;

    return SizedBox(
      height: size,
      // 미리보기는 겹친 만큼만 차지한다 (Row 안이라 폭을 알려 줘야 한다)
      width: max == null ? null : (shown.length - 1) * stride + size,
      child: Stack(
        children: [
          // 거꾸로 돌려서 **왼쪽 것이 위에** 오게 한다
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: i * stride,
              child: Tooltip(
                message: shown[i].name == me ? '나' : shown[i].name,
                child: Opacity(
                  opacity: faded ? 0.4 : 1,
                  child: Container(
                    // 흰 테를 둘러야 겹친 아바타끼리 갈린다
                    padding: EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Avatar(name: shown[i].name, size: size - 3),
                  ),
                ),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * stride + 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  '+$rest',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
