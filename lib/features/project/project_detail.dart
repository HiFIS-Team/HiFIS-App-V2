part of 'project_screen.dart';

// ── 우측 상세 ──

/// 기한 연장 신청 — 승인 전까지 마감일은 그대로다
///
/// PC 머리말의 글자 버튼과 폰 상단 글래스 버튼이 같이 쓴다.
Future<void> _extendProject(
  BuildContext context,
  _Project project,
  VoidCallback onChanged,
) async {
  final draft = await _showExtensionDialog(context, project);
  if (draft == null) return;
  final before = _date(project.due);

  final projectId = project.id;
  if (projectId != null) {
    try {
      final saved = await ProjectApi.requestChange(
        projectId,
        // 마감이 지난 뒤 올리는 건 '연장'이 아니라 '누락 사유'다
        type: _dday(project.due) < 0
            ? ProjectRequestType.overdue
            : ProjectRequestType.extension,
        newDue: draft.due,
        reason: draft.reason,
      );
      project.request = _Extension(
        id: saved.id,
        requester: me,
        type: saved.type,
        due: saved.newDue,
        reason: saved.reason,
        time: saved.createdAt,
      );
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
      return;
    }
  } else {
    project.request = draft;
  }

  project.events.insert(
    0,
    _Event(
      author: me,
      text: '기한 연장 신청 ($before → ${_date(draft.due!)})',
      time: DateTime.now(),
    ),
  );
  onChanged();
}

/// 이 프로젝트 사람인가 — **담당자와 참여 멤버뿐이다.**
///
/// 2026-08-14 정해졌다: "프로젝트 안에서 손댈 수 있는 건 그 프로젝트의
/// 담당자와 참여 멤버만." 역할 예외도, **만든 사람 예외도 없다.**
///
/// **만든 사람을 안 본다**는 것이 핵심이다. 대표·관리자는 자기가 담당자도
/// 참여자도 아니고 **남을 지정해서** 만든다 — 만든 사람을 통과시키면 그 둘이
/// 자기가 만든 프로젝트를 계속 손대게 된다.
/// 직원·점장은 폼이 본인을 담당자로 넣어 주므로 자기 것에서 잠기지 않는다.
///
/// 서버도 같은 기준으로 막는다 (`_is_member` → 403 `NOT_PROJECT_MEMBER`).
/// **여기서 잠그는 것은 눌러도 403 날 버튼뿐이다** — 댓글·연장 결재·점수
/// 부여는 서버가 열어 둔 자리라 그대로 둔다 ("댓글은 예외").
bool _isMember(_Project project) {
  final id = currentUser?.id;
  if (id == null) return false;
  return project.ownerId == id || project.memberIds.contains(id);
}

/// 연장 신청을 올릴 수 있는 상태 (끝났거나 이미 올린 신청이 있으면 못 올린다)
///
/// **대표·관리자는 못 올린다.** 일을 하는 사람이 올리고 대표가 결재하는 흐름이라,
/// 자기가 올려서 자기가 승인하는 자리가 되면 결재가 뜻을 잃는다.
///
/// 남의 프로젝트에도 못 올린다 — 예전에는 **서버에 가드가 아예 없어서**
/// 아무나 남의 프로젝트 기한을 늘려 달라고 대표에게 올릴 수 있었다.
bool _canExtendProject(_Project project) =>
    myRole.doesFieldWork &&
    _isMember(project) &&
    project.phase != _Phase.done &&
    project.request == null;

/// 연장 신청을 결재할 수 있는 사람 — 서버가 MASTER 로만 열어 뒀다
bool get _canDecideRequest => myRole == Role.master;

/// 결재 종류의 이름 — 카드·타임라인·확인 창이 같은 말을 쓴다
String _requestLabel(ProjectRequestType type) => switch (type) {
  ProjectRequestType.extension => '기한 연장',
  ProjectRequestType.overdue => '누락 사유',
  ProjectRequestType.edit => '프로젝트 수정',
  ProjectRequestType.delete => '프로젝트 삭제',
  ProjectRequestType.members => '인원 추가',
};

/// 수정·삭제를 올릴 수 있는 사람 — **담당자만** (서버 `NOT_PROJECT_OWNER`)
///
/// 참여 멤버는 예전에도 못 했다. 완료된 프로젝트는 아무도 못 올린다.
/// 대기 중인 결재가 있으면 못 올린다 — 프로젝트당 하나뿐이다.
bool _canRequestEdit(_Project project) =>
    project.ownerId != null &&
    project.ownerId == currentUser?.id &&
    project.phase != _Phase.done &&
    project.request == null;

/// 결재 카드에서 '무엇이 바뀌나' 한 줄 — 삭제는 견줄 값이 없어 null
String? _requestChange(_Project project, _Extension request) =>
    switch (request.type) {
      ProjectRequestType.extension || ProjectRequestType.overdue =>
        '${_date(project.due)} → ${_date(request.due!)}',
      // 바꾸겠다는 칸만 적는다 — 설명·색은 한 줄에 견주기 어려워 이름만 보인다
      ProjectRequestType.edit => [
        if (request.newTitle case final t?) '이름 → $t',
        if (request.newPurpose != null) '설명 바꿈',
        if (request.newColor != null) '색 바꿈',
      ].join(' · '),
      // 결재자가 **누구를 넣는지** 알아야 판단이 된다 — 인원수만으로는 못 정한다
      ProjectRequestType.members => _addedNames(request),
      ProjectRequestType.delete => null,
    };

/// 인원 추가 신청이 넣겠다는 사람 이름들 — 명단에 없으면 인원수로 떨어진다
String _addedNames(_Extension request) {
  final ids = (request.payload?['addIds'] as List?)?.cast<String>() ?? const [];
  final names = [for (final id in ids) ?StaffDirectory.instance.byId(id)?.name];
  return names.isEmpty ? '${ids.length}명 추가' : names.join(' · ');
}

/// 손댈 수 없는 프로젝트 — **자리는 그대로 두고 안 눌리게만 한다**
///
/// 두 가지가 잠근다.
///
/// - **내가 이 프로젝트 사람이 아니다** ([_isMember]) — 남의 일이다
/// - **완료됐다** — 완료가 곧 점수라, 됐다 안 됐다 하면 담당자 점수도 같이
///   흔들린다. 이건 **MASTER 만** 되돌릴 수 있다
///
/// 서버도 같은 기준으로 막는다 (403 `NOT_PROJECT_MEMBER` · `PROJECT_DONE`).
/// 댓글은 둘 다에 안 잠긴다.
///
/// **완료 되돌리기는 MASTER 도 자기 프로젝트에서만 된다.** 멤버 잠금이 먼저라
/// 남의 완료 프로젝트는 대표도 못 푼다 (2026-08-14 결정의 결과다).
bool _isLocked(_Project project) =>
    !_isMember(project) ||
    (project.phase == _Phase.done && myRole != Role.master);

class _ProjectDetail extends StatelessWidget {
  _ProjectDetail({
    super.key,
    required this.project,
    required this.onChanged,
    this.phone = false,
  });

  final _Project project;

  /// 목록의 진행률·정렬도 같이 갱신되도록 위로 알린다
  final VoidCallback onChanged;

  /// 폰은 폭이 좁아 머리말을 여러 줄로 쌓는다
  final bool phone;

  /// 타임라인에 한 줄 미리 끼워 넣는다.
  ///
  /// 서버가 자동으로 쌓는 건 **완료·기한 변경·담당 변경**뿐이라, 나머지는
  /// 다시 받아오면 사라진다 (backend-gap.md 3번). 그래도 누른 자리에서
  /// 바로 보이는 게 있어야 해서 남긴다.
  _Event _log(String text) {
    final event = _Event(author: me, text: text, time: DateTime.now());
    project.events.insert(0, event);
    return event;
  }

  /// 화면을 먼저 바꾸고 서버에 보낸다 — 실패하면 되돌린다.
  /// 체크 하나 누를 때마다 기다리게 하면 목록이 뻑뻑해진다.
  Future<void> _toggle(BuildContext context, _Todo todo) async {
    final before = todo.done;
    todo.done = !before;
    // 완료 문구는 서버가 쌓는 것과 같은 모양으로 맞춰 둔다 — 다시 받아와도 안 바뀐다
    final event = _log(todo.done ? '완료: ${todo.text}' : "'${todo.text}' 완료 취소");
    onChanged();

    final projectId = project.id;
    final todoId = todo.id;
    if (projectId == null || todoId == null) return;
    try {
      await ProjectApi.updateTodo(projectId, todoId, done: todo.done);
    } catch (error) {
      todo.done = before;
      project.events.remove(event);
      onChanged();
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _remove(BuildContext context, _Todo todo) async {
    final projectId = project.id;
    final todoId = todo.id;
    if (projectId != null && todoId != null) {
      try {
        await ProjectApi.deleteTodo(projectId, todoId);
      } catch (error) {
        if (context.mounted) AppToast.show(context, messageOf(error));
        return;
      }
    }
    project.todos.remove(todo);
    _log("'${todo.text}' 할 일 삭제");
    onChanged();
  }

  Future<void> _assign(BuildContext context, _Todo todo) async {
    final picked = await _pickMember(
      context,
      names: project.members,
      current: todo.assignee,
    );
    if (picked == null) return;

    final before = todo.assignee;
    todo.assignee = picked.isEmpty ? null : picked;
    onChanged();

    final projectId = project.id;
    final todoId = todo.id;
    if (projectId == null || todoId == null) return;
    try {
      await ProjectApi.updateTodo(
        projectId,
        todoId,
        // 담당자를 비우는 건 서버가 null 로 받는다
        assigneeId: _idOfMember(project, todo.assignee),
      );
    } catch (error) {
      todo.assignee = before;
      onChanged();
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 댓글 — 서버에 올린 뒤 돌아온 줄을 그대로 얹는다.
  /// 실패하면 아무것도 안 남는다 (빈 줄이 남아 있다가 사라지는 것보다 낫다)
  Future<void> _comment(BuildContext context, String text) async {
    final projectId = project.id;
    if (projectId == null) return;
    try {
      final saved = await ProjectApi.addComment(projectId, body: text);
      project.events.insert(0, _eventFrom(saved));
      onChanged();
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 기한 연장 신청 — 승인 전까지 마감일은 그대로다
  Future<void> _requestExtension(BuildContext context) =>
      _extendProject(context, project, onChanged);

  /// 수정 신청 — **승인 전까지는 아무것도 안 바뀐다**
  ///
  /// 신청할 때 프로젝트에 바로 쓰고 '되돌리기'를 두면, 승인 전인데 이미 바뀐
  /// 이름이 목록에 뜬다. 바꾸겠다는 값은 신청서(`payload`)가 들고 있다가
  /// 승인되는 순간 옮겨 담긴다.
  Future<void> _requestEdit(BuildContext context) async {
    final draft = await _showEditDialog(context, project);
    if (draft == null || !context.mounted) return;
    await _sendRequest(
      context,
      type: ProjectRequestType.edit,
      payload: draft.payload,
      reason: draft.reason,
    );
  }

  /// 인원 추가 신청 — 승인되면 그때 참여 멤버가 늘어난다
  ///
  /// 폼은 이름을 다루고 서버는 uuid 를 받는다 — 일정 참석자와 같은 사정이라
  /// 여기서 옮겨 담는다 (backend-gap 10). 명단에 없는 이름은 보낼 id 가 없어 빠진다.
  Future<void> _requestMembers(BuildContext context) async {
    final draft = await _showMembersDialog(context, project);
    if (draft == null || !context.mounted) return;
    final ids = [
      for (final name in draft.names) ?StaffDirectory.instance.byName(name)?.id,
    ];
    if (ids.isEmpty) {
      AppToast.show(context, '명단에서 그 사람을 못 찾았어요');
      return;
    }
    await _sendRequest(
      context,
      type: ProjectRequestType.members,
      addIds: ids,
      reason: draft.reason,
    );
  }

  /// 삭제 신청 — 승인 전까지 프로젝트는 그대로 있고 '삭제 대기'만 붙는다
  Future<void> _requestDelete(BuildContext context) async {
    final reason = await _showDeleteDialog(context, project);
    if (reason == null || !context.mounted) return;
    await _sendRequest(
      context,
      type: ProjectRequestType.delete,
      reason: reason,
    );
  }

  /// 수정·삭제 신청을 올린다 — 둘이 같은 통로라 한 곳에서 보낸다
  Future<void> _sendRequest(
    BuildContext context, {
    required ProjectRequestType type,
    required String reason,
    Map<String, String>? payload,
    List<String>? addIds,
  }) async {
    final projectId = project.id;
    if (projectId == null) return;
    final label = _requestLabel(type);
    try {
      final saved = await ProjectApi.requestChange(
        projectId,
        type: type,
        payload: payload,
        addIds: addIds,
        reason: reason,
      );
      project.request = _Extension(
        id: saved.id,
        requester: me,
        type: saved.type,
        payload: saved.payload,
        reason: saved.reason,
        time: saved.createdAt,
      );
      _log('$label 신청');
      onChanged();
      if (context.mounted) AppToast.show(context, '$label을 신청했어요');
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 승인·반려 모두 사유를 남겨야 처리된다
  Future<void> _decide(BuildContext context, {required bool approve}) async {
    final request = project.request!;
    final reason = await _showDecisionDialog(
      context,
      project: project,
      approve: approve,
    );
    if (reason == null) return;

    final requestId = request.id;
    if (requestId != null) {
      try {
        if (approve) {
          await ProjectApi.approve(requestId);
        } else {
          await ProjectApi.reject(requestId, reason: reason);
        }
      } catch (error) {
        if (context.mounted) AppToast.show(context, messageOf(error));
        return;
      }
    }

    final label = _requestLabel(request.type);
    if (!approve) {
      _log('$label 반려 · $reason');
      project.request = null;
      onChanged();
      if (context.mounted) AppToast.show(context, '반려했어요');
      return;
    }

    // 승인 — 종류마다 서버가 해 준 것을 화면에도 그대로 반영한다
    switch (request.type) {
      case ProjectRequestType.extension:
      case ProjectRequestType.overdue:
        _log(
          '$label 승인 (${_date(project.due)} → ${_date(request.due!)}) · $reason',
        );
        project.due = request.due!;
      case ProjectRequestType.edit:
        _log('$label 승인 · $reason');
        if (request.newTitle case final title?) project.name = title;
        if (request.newPurpose case final purpose?) project.desc = purpose;
        if (request.newColor case final color?) project.colorHex = color;
      case ProjectRequestType.members:
        _log('$label 승인 (${_addedNames(request)}) · $reason');
        // 서버가 **더하기만** 한다 — 화면도 같게 맞춘다 (갈아끼우면 어긋난다)
        final ids =
            (request.payload?['addIds'] as List?)?.cast<String>() ?? const [];
        project.memberIds = {...project.memberIds, ...ids}.toList();
      case ProjectRequestType.delete:
        // 서버가 지웠다 — 목록에서도 빼고, 폰이면 상세를 닫는다.
        // 여기서 `onChanged` 를 부르면 없는 프로젝트를 다시 그린다
        _projects.remove(project);
        if (context.mounted) {
          AppToast.show(context, '삭제했어요');
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
        onChanged();
        return;
    }
    project.request = null;
    onChanged();
    if (context.mounted) {
      // 다른 결재 자리와 같은 문구 — 방금 누른 버튼 옆이라 뭘 처리했는지는 분명하다
      AppToast.show(context, '승인했어요');
    }
  }

  /// 연장 신청 버튼 (끝난 프로젝트나 이미 올린 신청이 있으면 감춘다)
  Widget _extendButton(BuildContext context) =>
      _headButton('기한 연장', () => _requestExtension(context));

  /// 머리말 오른쪽 글자 버튼 — 기한 연장 · 수정 · 삭제가 같은 모양으로 선다
  Widget _headButton(String label, VoidCallback onTap, {bool danger = false}) =>
      Pressable(
        onTap: onTap,
        scale: 0.94,
        pressedColor: AppColors.gray100,
        borderRadius: BorderRadius.circular(100),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: danger ? AppColors.error : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  bool get _canExtend => _canExtendProject(project);

  /// 머리말 오른쪽 결재 버튼들 — 담당자에게만 수정·인원 추가·삭제가 붙는다
  ///
  /// 넷 다 **대표 결재를 받는 것**이라 한자리에 모은다. 대기 중인 결재가
  /// 있으면 넷 다 사라진다 (프로젝트당 하나뿐이라 올려도 400 이 난다).
  ///
  /// `인원 추가` 를 **`수정` 옆에** 둔 이유 — 서버 가드가 수정·삭제와 같고
  /// (`NOT_PROJECT_OWNER`), 올리는 조건도 `_canRequestEdit` 하나로 같다.
  /// 따로 떼면 같은 규칙인데 자리만 다른 버튼이 하나 더 생긴다.
  List<Widget> _headActions(BuildContext context) => [
    if (_canExtend) ...[SizedBox(width: 8), _extendButton(context)],
    if (_canRequestEdit(project)) ...[
      SizedBox(width: 4),
      _headButton('수정', () => _requestEdit(context)),
      SizedBox(width: 4),
      _headButton('인원 추가', () => _requestMembers(context)),
      SizedBox(width: 4),
      _headButton('삭제', () => _requestDelete(context), danger: true),
    ],
  ];

  /// 데스크톱 머리말 — 한 줄에 이름·D-day, 오른쪽 끝에 참여자
  List<Widget> _desktopHead(BuildContext context, int dday) => [
    Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: project.color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title1,
                ),
              ),
              SizedBox(width: 10),
              _DdayBadge(dday: dday, phase: project.phase),
            ],
          ),
        ),
        SizedBox(width: 16),
        _MemberBar(project: project, onChanged: onChanged),
      ],
    ),
    SizedBox(height: 6),
    Row(
      children: [
        Text(
          '${_date(project.start)} ~ ${_date(project.due)} · 담당 ${project.owner}',
          style: AppTextStyles.caption,
        ),
        ..._headActions(context),
      ],
    ),
    if (project.desc.isNotEmpty) ...[
      SizedBox(height: 10),
      Text(
        project.desc,
        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
      ),
    ],
  ];

  /// 폰 머리말 — 이름 / 기간·담당 / 참여자·연장 순으로 쌓는다
  List<Widget> _phoneHead(BuildContext context, int dday) => [
    Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: project.color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(project.name, style: AppTextStyles.title2)),
      ],
    ),
    SizedBox(height: 10),
    Row(
      children: [
        _DdayBadge(dday: dday, phase: project.phase),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_date(project.start)} ~ ${_date(project.due)} · 담당 ${project.owner}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ),
      ],
    ),
    if (project.desc.isNotEmpty) ...[
      SizedBox(height: 10),
      Text(
        project.desc,
        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
      ),
    ],
    SizedBox(height: 12),
    // 연장 신청은 상단 글래스 버튼으로 올라가 여기엔 참여자만 남는다
    Row(
      children: [_MemberBar(project: project, onChanged: onChanged)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dday = _dday(project.due);

    return ListView(
      padding: phone
          // 폰 상세는 헤더 뒤로 스크롤되고, 하단바가 없어 화면 아래 여백만 남긴다
          ? EdgeInsets.fromLTRB(
              20,
              PhoneDetailScaffold.topPadding,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            )
          : EdgeInsets.fromLTRB(28, 64, 28, bottomBarInset(context)),
      children: [
        if (phone)
          ..._phoneHead(context, dday)
        else
          ..._desktopHead(context, dday),
        // 완료하면 그 자리가 점수 카드가 된다 — 결재할 기한 연장은 이미 끝났다
        if (project.phase == _Phase.done && myRole == Role.master) ...[
          SizedBox(height: 14),
          _AwardCard(project: project),
        ] else if (project.request != null) ...[
          SizedBox(height: 14),
          _ExtensionCard(
            project: project,
            // 대표가 아니면 버튼 없이 '대기 중'만 보인다 (눌러도 403 이다)
            onApprove: _canDecideRequest
                ? () => _decide(context, approve: true)
                : null,
            onReject: _canDecideRequest
                ? () => _decide(context, approve: false)
                : null,
          ),
        ],
        SizedBox(height: 18),
        // 진행률 — 할 일 진척도를 여기서 한 번만 보여준다
        Row(
          children: [
            Expanded(
              child: _ProgressBar(
                value: project.progress,
                color: project.color,
                height: 8,
              ),
            ),
            SizedBox(width: 12),
            Text(
              '${(project.progress * 100).round()}%',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: project.phase == _Phase.done
                    ? AppColors.success
                    : project.color,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '할 일 ${project.doneCount}/${project.todos.length}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        SizedBox(height: 22),
        // 좌우로 나누면 짧은 쪽 아래가 비어 보여서 전폭으로 쌓는다.
        // 칸 안에 스크롤을 넣지 않고 페이지가 늘어나는 쪽을 택했다.
        _TodoCard(
          project: project,
          onToggle: (todo) => _toggle(context, todo),
          onRemove: (todo) => _remove(context, todo),
          onAssign: (todo) => _assign(context, todo),
        ),
        SizedBox(height: 16),
        // 폰은 댓글을 시트로 빼고, 여기엔 눌러서 여는 줄만 둔다
        if (!isDesktop) ...[
          _CommentTeaser(
            project: project,
            onTap: () => _showComments(
              context,
              project,
              onComment: (text) => _comment(context, text),
            ),
          ),
          SizedBox(height: 16),
        ],
        _ActivityCard(
          project: project,
          onComment: (text) => _comment(context, text),
        ),
      ],
    );
  }
}

/// 기한 연장 결재 카드 — 승인하면 마감일이 늘어나고, 반려하면 그대로 간다
class _ExtensionCard extends StatelessWidget {
  _ExtensionCard({
    required this.project,
    required this.onApprove,
    required this.onReject,
  });

  final _Project project;

  /// null 이면 결재 권한이 없다 — 버튼 대신 기다린다는 안내만 둔다
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  bool get _canDecide => onApprove != null && onReject != null;

  @override
  Widget build(BuildContext context) {
    final request = project.request!;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좁은 화면에서는 제목과 날짜가 아래로 접힌다
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              '${_requestLabel(request.type)} 승인 대기',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 무엇을 승인하는지 — 종류마다 볼 것이 다르다.
            // 삭제는 견줄 값이 없어서 이 줄이 아예 없다
            if (_requestChange(project, request) case final change?)
              Text(
                change,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          request.reason,
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 4),
        Text(
          _canDecide
              ? '${request.requester} · ${_relative(request.time)} 신청'
              : '${request.requester} · ${_relative(request.time)} 신청'
                    ' · 대표 결재를 기다리고 있어요',
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    );

    final icon = Icon(
      Icons.hourglass_empty_rounded,
      size: 18,
      color: AppColors.warning,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      // 폰은 버튼을 옆에 두면 내용이 눌려서 아래로 내린다
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                SizedBox(width: 10),
                Expanded(child: info),
                if (_canDecide) ...[
                  SizedBox(width: 12),
                  DecideButtons(onApprove: onApprove!, onReject: onReject!),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    SizedBox(width: 10),
                    Expanded(child: info),
                  ],
                ),
                if (_canDecide) ...[
                  SizedBox(height: 12),
                  DecideButtons(
                    onApprove: onApprove!,
                    onReject: onReject!,
                    fill: true,
                  ),
                ],
              ],
            ),
    );
  }
}

/// 헤더 오른쪽 참여자 — 누르면 멤버 관리가 열린다
class _MemberBar extends StatelessWidget {
  _MemberBar({required this.project, required this.onChanged});

  final _Project project;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => _showMemberManager(context, project, onChanged),
      scale: 0.97,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(100),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarStack(names: project.members, size: 28),
          SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_rounded,
              size: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
