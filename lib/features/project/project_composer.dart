part of 'project_screen.dart';

/// 새 프로젝트 만들기 — 만들면 그 프로젝트를 돌려준다
///
/// [seed] 를 주면 칸이 미리 채워진 채로 열린다 (회의록에서 옮길 때).
///
/// [edit] 을 주면 **고치는 화면**이 된다 (2026-08-19). 만들기와 **같은 폼**에
/// 지금 값이 채워진 채로 열린다 — 예전에는 이름·설명·색만 받는 작은 모달이라
/// 만들 때와 고칠 때가 다른 화면이었다.
Future<_Project?> _showProjectComposer(
  BuildContext context, {
  ProjectSeed? seed,
  _Project? edit,
  Future<bool> Function()? onDelete,
  Future<bool> Function(_Project draft, String reason)? onRequest,
}) {
  // 폰은 팝업이 답답해서 오른쪽에서 밀려 들어오는 페이지로 연다
  if (!isDesktop) {
    return Navigator.push<_Project>(
      context,
      CupertinoPageRoute(
        builder: (_) => _ProjectComposer(
          phone: true,
          seed: seed,
          edit: edit,
          onDelete: onDelete,
          onRequest: onRequest,
        ),
      ),
    );
  }
  return showAppDialog<_Project>(
    context,
    (context) => _ProjectComposer(
      seed: seed,
      edit: edit,
      onDelete: onDelete,
      onRequest: onRequest,
    ),
  );
}

/// 밖에서 프로젝트를 만들 때 미리 채워 보내는 값 (지금은 회의록이 쓴다)
class ProjectSeed {
  const ProjectSeed({
    this.title = '',
    this.purpose = '',
    this.members = const [],
    this.todos = const [],
  });

  final String title;
  final String purpose;

  /// 참여 멤버 — **이름**이다 (폼이 아직 이름을 사람 키로 쓴다, backend-gap 10)
  final List<String> members;

  /// 할 일 — 회의록 체크박스의 글이 그대로 들어온다
  final List<String> todos;
}

/// **회의록에서 프로젝트 만들기** — 만들어진 프로젝트 id 를 돌려준다
///
/// **미리 채워진 생성 폼을 그대로 연다.** 옮기기 전에 마감일·색·담당을
/// 손볼 수 있어야 해서 확인 창 한 장으로 끝내지 않는다.
///
/// 프로젝트 화면 밖에서 부르는 유일한 창구다. `_showProjectComposer` 와
/// `_saveNewProject` 가 이 라이브러리 안에 있어서 여기 둔다.
Future<String?> createProjectFrom(
  BuildContext context,
  ProjectSeed seed,
) async {
  final draft = await _showProjectComposer(context, seed: seed);
  if (draft == null || !context.mounted) return null;
  try {
    final created = await _saveNewProject(draft);
    return created.id;
  } catch (error) {
    if (context.mounted) AppToast.show(context, messageOf(error));
    return null;
  }
}

class _ProjectComposer extends StatefulWidget {
  _ProjectComposer({
    this.phone = false,
    this.seed,
    this.edit,
    this.onDelete,
    this.onRequest,
  });

  /// 폰은 팝업이 아니라 밀려 들어오는 페이지로 뜬다
  final bool phone;

  /// 미리 채워 넣을 값 — null 이면 빈 폼이다 (평소 '새 프로젝트')
  final ProjectSeed? seed;

  /// 고칠 프로젝트 — null 이면 새로 만드는 것이다
  final _Project? edit;

  /// 삭제 아이콘을 눌렀을 때 — **처리했으면 true** 면 폼을 닫는다 (2026-08-19).
  ///
  /// 지우는 일 자체는 부르는 쪽([_ProjectDetail])이 한다 — 확인 창을 띄우고
  /// 목록에서 빼는 뒷정리가 거기 있다. 폼은 자리만 내준다.
  final Future<bool> Function()? onDelete;

  /// **결재로 올릴 때** — 값과 사유를 넘긴다. 올렸으면 true 면 폼을 닫는다.
  ///
  /// 할 일이 하나라도 체크된 뒤에는 바로 못 고치고 대표 승인을 받는다
  /// (2026-08-19). 그때도 **화면은 만들 때와 같다** — 고칠 수 있는 칸만
  /// 이름·설명·색으로 좁아지고 사유 칸이 하나 붙는다.
  final Future<bool> Function(_Project draft, String reason)? onRequest;

  @override
  State<_ProjectComposer> createState() => _ProjectComposerState();
}

class _ProjectComposerState extends State<_ProjectComposer> {
  /// 고치는 중인가 — 채워 넣는 값과 버튼 글자가 여기서 갈린다
  _Project? get _edit => widget.edit;

  late final _name = TextEditingController(
    text: _edit?.name ?? widget.seed?.title ?? '',
  );
  late final _desc = TextEditingController(
    text: _edit?.desc ?? widget.seed?.purpose ?? '',
  );
  final _nameFocus = FocusNode();

  /// 수정 신청 사유 — 결재를 받아야 할 때만 쓴다
  final _reason = TextEditingController();

  /// 기본 마감은 2주 뒤 — 고칠 때는 지금 마감이 든다
  late DateTime _due = _edit?.due ?? DateTime.now().add(Duration(days: 14));

  /// 참여 멤버 — **만든 사람이 기본으로 든다. 권한을 안 가린다.**
  ///
  /// 예전에는 대표·관리자만 빠졌다. 만들어 남에게 맡기는 자리로 봤는데,
  /// 본인이 주도하는 프로젝트도 있어서 그때마다 **담당 고르개로 자기를 골라야**
  /// 참여자가 됐다 (참여 멤버 칩에서는 자기가 안 눌린다). 넷 다 같게 뒀다
  /// (2026-08-20 대표 결정).
  ///
  /// **참여자가 되는 것과 쪼이는 것은 별개다** — 마감 리마인더·마감 임박 모달·
  /// 점수 셋 다 MASTER·ADMIN 을 따로 뺀다 (서버 `_reminder_targets`·
  /// `accrue_score`, 앱 [_dueTargets]). 여기를 바꿔도 불이익은 안 온다.
  ///
  /// 회의록에서 왔으면 **참석자가 그대로 든다.** 본인 칩은 뺄 수 없게
  /// 해 뒀으므로(`onTap: null`) 겹치지 않게 한 번만 넣는다.
  late final _members = <String>[
    if (_edit case final project?) ...[
      ...project.members,
    ] else ...[
      me,
      for (final name in widget.seed?.members ?? const <String>[])
        if (name != me) name,
    ],
  ];

  /// 만들면서 같이 등록할 할 일 — **고칠 때는 지금 것을 그대로 든다**
  ///
  /// 원본을 안 건드리려고 복사한다. 저장할 때 [_edit] 의 것과 견줘
  /// 새로 넣을 것·뺄 것·담당자가 바뀐 것을 가른다.
  late final _todos = <_Todo>[
    if (_edit case final project?)
      for (final todo in project.todos)
        _Todo(
          id: todo.id,
          text: todo.text,
          assignee: todo.assignee,
          done: todo.done,
        )
    else
      for (final text in widget.seed?.todos ?? const <String>[])
        _Todo(text: text),
  ];

  /// 맡을 사람 — **만든 사람이 기본이다** (참여 멤버와 같은 기준)
  ///
  /// 남에게 맡기려면 담당 고르개에서 바꾼다. 거기는 참여 멤버가 아니라
  /// **명단 전체**에서 고르고, 고른 사람을 참여 멤버에 같이 넣어 준다.
  ///
  /// 비어 있으면 아직 안 골랐다는 뜻이라 저장에서 막힌다 — 담당을 맡던
  /// 사람을 참여 멤버에서 빼면 [_toggleMember] 가 이 값을 비운다.
  late String _owner = _edit?.owner ?? me;

  late Color _color = _hexColor(_edit?.colorHex) ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _reason.addListener(() => setState(() {}));
    // 페이지가 밀려 들어오는 중에 키보드가 같이 올라오면 어수선해서
    // 폰에서는 자동 포커스를 두지 않는다
    if (!widget.phone) _nameFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _reason.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
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
    if (picked != null) setState(() => _due = picked);
  }

  void _toggleMember(String name) {
    setState(() {
      if (_members.contains(name)) {
        _members.remove(name);
        // 빠진 사람이 맡기로 한 자리는 정말로 비워둔다 — 만든 사람으로
        // 되돌리면 남에게 맡기려던 프로젝트가 조용히 자기 것이 된다
        if (_owner == name) _owner = '';
        for (final todo in _todos) {
          if (todo.assignee == name) todo.assignee = null;
        }
      } else {
        _members.add(name);
      }
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, '프로젝트 이름을 입력해주세요');
      _nameFocus.requestFocus();
      return;
    }
    // 결재로 올리는 자리 — 고친 칸은 이름·설명·색뿐이고 사유가 필요하다
    if (_needsApproval) {
      final reason = _reason.text.trim();
      if (reason.isEmpty) {
        AppToast.show(context, '왜 고치는지 적어주세요');
        return;
      }
      final sent = await widget.onRequest!.call(_draft(name), reason);
      if (sent && mounted) Navigator.pop(context);
      return;
    }
    if (_owner.isEmpty) {
      AppToast.show(context, '담당자를 정해주세요');
      return;
    }
    // **할 일을 두 개 이상 받는다 (2026-08-19 대표 결정).** 완료가 곧 점수인데
    // 할 일이 없으면 무엇을 했는지가 아무 데도 안 남는다. 하나만 받으면
    // 그 한 칸이 사실상 프로젝트 자체라 나눠 적는 뜻이 없다.
    if (_todos.length < 2) {
      AppToast.show(context, '할 일을 두 개 이상 추가해주세요');
      return;
    }
    // 담당자도 필수다 — 비어 있으면 누가 할 일인지 아무도 모른 채로 시작한다
    if (_todos.any((todo) => todo.assignee == null)) {
      AppToast.show(context, '할 일마다 담당자를 정해주세요');
      return;
    }
    Navigator.pop(context, _draft(name));
  }

  /// 폼에 적힌 것을 그대로 담은 값
  _Project _draft(String name) => _Project(
    name: name,
    desc: _desc.text.trim(),
    colorHex: _hexOf(_color),
    owner: _owner,
    start: _edit?.start ?? DateTime.now(),
    due: _due,
    // 명단 순서대로 정렬해 두면 아바타 줄이 화면마다 같은 순서로 보인다
    members: [
      for (final staff in staffList)
        if (_members.contains(staff.name)) staff.name,
    ],
    todos: _todos,
    // 타임라인은 서버가 만들면서 '프로젝트를 만들었어요' 를 쌓아 준다
    events: [],
  );

  /// 폼 본문 — 팝업(데스크톱)과 페이지(폰)가 같이 쓴다
  Widget _form(BuildContext context, int dday) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          controller: _name,
          focusNode: _nameFocus,
          hint: '프로젝트 이름',
          bold: true,
          onSubmitted: _submit,
        ),
        SizedBox(height: 8),
        _Field(controller: _desc, hint: '어떤 프로젝트인가요? (선택)', lines: 2),
        SizedBox(height: 16),
        Row(
          children: [
            SizedBox(width: 62, child: Text('마감일', style: AppTextStyles.label)),
            Pressable(
              // 결재 모드에서는 마감을 여기서 못 바꾼다 — 기한 연장 결재가
              // 따로 있고, 프로젝트당 대기 중인 결재는 하나뿐이다
              onTap: _needsApproval ? _lockedNote : _pickDue,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${_due.year}.${_due.month}.${_due.day}',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6),
            _DdayBadge(dday: dday, phase: _Phase.running),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('담당', style: AppTextStyles.label)),
            _AssigneeChip(
              name: _owner.isEmpty ? null : _owner,
              onTap: _needsApproval
                  ? _lockedNote
                  : () async {
                      final picked = await _pickMember(
                        context,
                        // **명단 전체에서 고른다.** 참여 멤버 중에서만 고르게 하면
                        // 대표가 프로젝트를 만들 때 멤버부터 넣어야 담당을 고를 수 있다
                        names: [for (final staff in staffList) staff.name],
                        current: _owner.isEmpty ? null : _owner,
                      );
                      // 담당은 비울 수 없다 (빈 문자열 = 안 고르고 닫음)
                      if (picked == null || picked.isEmpty) return;
                      setState(() {
                        _owner = picked;
                        // 맡은 사람은 당연히 참여한다
                        if (!_members.contains(picked)) _members.add(picked);
                      });
                    },
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('색상', style: AppTextStyles.label)),
            for (final color in _projectPalette)
              Pressable(
                onTap: () => setState(() => _color = color),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: _color == color
                      ? Icon(Icons.check_rounded, size: 15, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        Text('참여 멤버', style: AppTextStyles.label),
        SizedBox(height: 8),
        ScrollBox(
          maxHeight: kChipBoxHeight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final staff in staffList)
                _MemberChip(
                  staff: staff,
                  joined: _members.contains(staff.name),
                  // 직원·점장은 자기를 못 뺀다 — 자기 일을 자기가 올리는 자리다.
                  //
                  // **대표·관리자는 뺄 수 있다** (2026-08-20). 만들면서 기본으로
                  // 들어가는 것은 같지만(`_members`), 남에게 통째로 맡기는
                  // 프로젝트가 원래 주력 흐름이라 여기까지 막으면 그걸 못 만든다.
                  // 자기를 빼면 담당 자리도 같이 비어서(`_toggleMember`)
                  // 저장 전에 누구에게 맡길지 반드시 고르게 된다.
                  //
                  // 결재 모드에서는 인원 추가 결재가 따로 있어서 잠근다
                  onTap: (staff.name == me && myRole.doesFieldWork)
                      ? null
                      : (_needsApproval
                            ? _lockedNote
                            : () => _toggleMember(staff.name)),
                ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Text('할 일', style: AppTextStyles.label),
            SizedBox(width: 6),
            Text(
              '${_todos.length}',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // 결재 모드에서는 여기서 할 일을 못 고친다 — 상세 화면의 할 일 카드가
        // 그대로 열려 있고, 거기서 한 변경은 결재를 안 탄다
        if (!_needsApproval)
          _TodoComposer(
            members: _members,
            onAdd: (text, assignee) => setState(
              () => _todos.add(_Todo(text: text, assignee: assignee)),
            ),
          ),
        for (final todo in _todos)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    todo.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2,
                  ),
                ),
                if (todo.assignee != null) ...[
                  Avatar(name: todo.assignee!, size: 20),
                  SizedBox(width: 6),
                  Text(
                    todo.assignee!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(width: 6),
                if (!_needsApproval)
                  Pressable(
                    onTap: () => setState(() => _todos.remove(todo)),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.gray400,
                    ),
                  ),
              ],
            ),
          ),
        if (_needsApproval) ...[
          SizedBox(height: 18),
          Text('수정 사유', style: AppTextStyles.label),
          SizedBox(height: 8),
          _Field(controller: _reason, hint: '왜 고치는지 적어주세요', lines: 2),
        ],
      ],
    );
  }

  /// 확인 버튼 글자 — 하는 일이 셋이라 각각 다르다
  String get _submitLabel {
    if (_edit != null) return _needsApproval ? '수정 신청' : '저장';
    return widget.seed == null ? '만들기' : '옮기기';
  }

  /// 머리말 — 폰 페이지와 PC 팝업이 같이 쓴다
  String get _pageTitle => _edit == null ? '새 프로젝트' : '프로젝트 수정';

  /// 삭제 아이콘을 그릴까 — 고치는 중일 때만
  bool get _canDelete => _edit != null && widget.onDelete != null;

  Future<void> _delete() async {
    final done = await widget.onDelete!.call();
    if (done && mounted) Navigator.pop(context);
  }

  /// 결재 모드에서 못 고치는 칸을 눌렀을 때 — **왜 안 되는지 알려준다**
  ///
  /// 마감은 기한 연장 결재, 인원은 인원 추가 결재로 길이 따로 있고,
  /// **프로젝트당 대기 중인 결재는 하나뿐**이라 한 폼에서 같이 못 올린다.
  void _lockedNote() {
    AppToast.show(context, '할 일이 시작돼서 이름·설명·색만 고칠 수 있어요');
  }

  /// 이 수정이 대표 결재를 거쳐야 하나 — 할 일이 하나라도 체크됐으면 그렇다
  bool get _needsApproval {
    final project = _edit;
    return project != null && !_canEditNow(project);
  }

  /// 만들기 버튼 (데스크톱 팝업 전용 — 폰은 하단 글래스 버튼을 쓴다)
  Widget _submitButton() {
    final empty = _name.text.trim().isEmpty;

    return Pressable(
      onTap: _submit,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          // 이름을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
          color: empty ? AppColors.gray200 : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _submitLabel,
          style: AppTextStyles.body2.copyWith(
            color: empty ? AppColors.gray500 : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dday = _dday(_due);

    // 폰은 팝업 대신 오른쪽에서 밀려 들어오는 페이지로 연다
    if (widget.phone) {
      return PhoneDetailScaffold(
        title: _pageTitle,
        // 삭제는 여기 하나뿐이다 — 상세 화면에는 안 둔다 (2026-08-19)
        actions: [
          if (_canDelete) GlassIconButton(symbol: 'trash', onPressed: _delete),
        ],
        // 만들기는 하단 탭바 자리에 글래스 버튼으로 띄운다
        bottomBar: GlassBottomButton(
          label: _submitLabel,
          active: _name.text.trim().isNotEmpty,
          onPressed: _submit,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            GlassBottomButton.inset(context),
          ),
          children: [
            // 입력칸(gray50)이 회색 배경에 묻히지 않게 흰 카드 위에 올린다
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: AppDecorations.card(),
              child: _form(context, dday),
            ),
          ],
        ),
      );
    }

    return Container(
      width: dialogWidth(context, 460),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      // 할 일을 여러 개 적으면 길어져서 본문만 스크롤되게 높이를 묶는다
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_pageTitle, style: AppTextStyles.title2),
                Spacer(),
                // PC 는 팝업이라 글래스(네이티브 뷰)를 안 쓴다 — 같은 자리에
                // 같은 아이콘만 둔다
                if (_canDelete)
                  Pressable(
                    onTap: _delete,
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.trash,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _form(context, dday))),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Pressable(
                  onTap: () => Navigator.pop(context),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Text(
                    '취소',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _submitButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 생성 폼 입력칸
class _Field extends StatelessWidget {
  _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.lines = 1,
    this.bold = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final bool bold;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDecorations.fieldPadding,
      decoration: AppDecorations.field(),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: bold
            ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
            : AppTextStyles.body2,
        cursorColor: AppColors.primary,
        minLines: lines,
        maxLines: lines,
        keyboardType: lines > 1 ? TextInputType.multiline : null,
        textInputAction: lines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: (_) => onSubmitted?.call(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: (bold ? AppTextStyles.body1 : AppTextStyles.body2)
              .copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 참여 멤버 고르는 알약 (생성 폼)
class _MemberChip extends StatelessWidget {
  _MemberChip({required this.staff, required this.joined, this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? () {},
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

/// 참여 인원 보기 — **읽기만 한다** (2026-08-19)
///
/// 담당자가 맨 위, 그다음이 참여 멤버다. 사람을 넣는 건 `+` 쪽
/// (`_requestMembers`)이고 그건 대표 결재를 받는다.
///
/// 예전에는 여기가 '참여 멤버 관리' 라 **전 직원이 뜨고 눌러서 넣고 뺐는데,
/// 그 결과가 서버로 안 갔다** — 화면에서만 바뀌었다가 목록을 다시 받으면
/// 되돌아왔다. 지금은 인원 변경이 결재를 거치므로 여기서 고칠 것이 없다.
void _showMemberList(BuildContext context, _Project project) {
  // 담당자를 맨 위로 올린다 — 나머지는 받은 차례 그대로
  final owner = project.owner;
  final names = [
    if (project.members.contains(owner)) owner,
    for (final name in project.members)
      if (name != owner) name,
  ];

  showAppDialog<void>(
    context,
    (context) => Container(
      width: dialogWidth(context, 300),
      padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('참여 인원', style: AppTextStyles.title3),
          ),
          SizedBox(height: 8),
          // 인원이 늘면 팝업이 화면 밖으로 나간다 — 높이만 막고 안에서 스크롤
          ScrollBox(
            maxHeight: kListBoxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in names)
                  _MemberRow(name: name, owner: name == owner),
              ],
            ),
          ),
          SizedBox(height: 14),
          AppButton(label: '닫기', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

/// 참여 인원 한 줄 — 담당자에게만 오른쪽에 표가 붙는다
class _MemberRow extends StatelessWidget {
  _MemberRow({required this.name, required this.owner});

  final String name;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Avatar(name: name, size: 32),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              name == me ? '$name (나)' : name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (owner)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('담당자', style: AppTextStyles.caption),
            )
          else
            Text(staffOf(name).role, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
