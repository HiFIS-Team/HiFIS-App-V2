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

/// 수정·삭제·인원 추가를 **결재 없이 바로** 할 수 있는가 (2026-08-19 대표 결정)
///
/// | 누구 | 언제 |
/// |---|---|
/// | MASTER | **늘** — 남의 것도, 완료된 것도 |
/// | ADMIN | **참여 중일 때** (담당자거나 참여 멤버) |
/// | MANAGER · MEMBER | 참여 중 + **할 일이 하나도 체크 안 됐을 때** |
///
/// 아직 아무도 손을 안 댄 프로젝트는 잘못 만든 것일 수 있어서 그냥 고치고
/// 지운다 — 오타 하나에 대표를 부르지 않는다. 한 칸이라도 체크된 뒤부터는
/// 남이 한 일이 걸려 있어서 [_canRequestEdit] 쪽(결재)으로 간다.
///
/// 서버 `_ensure_can_edit` 과 같은 기준이다.
bool _canEditNow(_Project project) {
  if (myRole == Role.master) return true;
  if (!_isMember(project) || project.isDone) return false;
  if (myRole == Role.admin) return true;
  return !project.anyTodoDone;
}

/// 수정·삭제·인원 추가를 **결재로 올릴 수 있는가** (서버 `NOT_PROJECT_MEMBER`)
///
/// **담당자와 참여 멤버 둘 다** 올린다 (2026-08-19 — 예전에는 담당자만).
/// 완료된 프로젝트는 아무도 못 올리고, 대기 중인 결재가 있으면 못 올린다
/// (프로젝트당 하나뿐이다).
///
/// [_canEditNow] 인 사람은 여기로 안 온다 — 바로 고치면 되는데 결재를 태우면
/// 결재함만 지저분해진다.
bool _canRequestEdit(_Project project) =>
    _isMember(project) &&
    !project.isDone &&
    project.request == null &&
    !_canEditNow(project);

/// 완료 버튼을 누를 수 있는가 — **담당자만** (2026-08-19 대표 결정)
///
/// 체크는 다 같이 하지만 '이제 끝났다'고 선언하는 것은 맡은 사람 몫이다.
/// 할 일이 하나 이상 있고 **전부 체크돼야** 뜬다 (서버 `TODOS_LEFT`).
bool _canCompleteProject(_Project project) =>
    !project.isDone &&
    project.ownerId != null &&
    project.ownerId == currentUser?.id &&
    project.allTodosDone;

/// 수정·삭제·인원 추가 버튼을 보여줄까 — **바로 하든 결재로 올리든** 되면 뜬다
///
/// PC 머리말의 글자 버튼과 폰 상단 글래스 버튼이 같이 쓴다.
bool _canTouchProject(_Project project) =>
    _canEditNow(project) || _canRequestEdit(project);

/// 폰 상단 글래스 버튼이 상세 본문과 **같은 동작**을 타게 하는 통로
///
/// 수정·인원 추가는 [_ProjectDetail] 안에 있다 (프로젝트와 갱신 콜백을 다 들고
/// 있어야 해서다). 폰 헤더는 그 위젯 **밖**이라 직접 못 부른다 — 같은 값으로
/// 하나 더 만들어 그 메서드를 부른다. **그리지 않고 동작만 빌려 쓰는 것**이라
/// 화면에는 아무 영향이 없다.
_ProjectDetail _projectActions(_Project project, VoidCallback onChanged) =>
    _ProjectDetail(project: project, onChanged: onChanged);

/// 이 할 일에 체크할 수 있는가 — **그 할 일의 담당자와 PM 뿐이다** (2026-08-20)
///
/// 체크가 곧 진행률이고 그게 곧 완료·점수라, **남이 한 일을 대신 찍어 주면
/// 그 점수가 뜻을 잃는다.** 그래서 자기 칸만 체크한다.
///
/// **권한을 안 가린다 — MASTER·ADMIN 도 같다.** 예전에는 그 둘만 본인 것으로
/// 묶고 직원·점장은 참여자면 어느 칸이든 눌렀는데, 같은 프로젝트에 있다는
/// 이유로 남의 칸을 찍는 것은 대표가 찍는 것과 다를 게 없다.
///
/// PM 은 폼 위쪽 `담당` 에 든 한 사람([_Project.ownerId])뿐이다 — 프로젝트를
/// 끌고 가는 자리라 전체를 마감할 수 있어야 한다. 담당자가 나가거나 못 하게
/// 됐을 때 이 길이 없으면 프로젝트가 영영 안 끝난다.
/// **할 일마다 붙는 담당자는 PM 이 아니라 참여 멤버다.**
///
/// 서버 `_ensure_can_check` 과 같은 기준이다 (`NOT_TODO_ASSIGNEE`).
bool _canCheckTodo(_Project project, _Todo todo) {
  final me = currentUser?.id;
  if (me == null) return false;
  // 담당자가 없는 칸은 PM 만 체크한다
  final name = todo.assignee;
  if (name != null && StaffDirectory.instance.byName(name)?.id == me) {
    return true;
  }
  return project.ownerId == me;
}

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
    !_isMember(project) || (project.isDone && myRole != Role.master);

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

  /// 기한 연장 신청 — 승인 전까지 마감일은 그대로다
  Future<void> _requestExtension(BuildContext context) =>
      _extendProject(context, project, onChanged);

  /// 프로젝트 수정 — **자유든 결재든 같은 화면**이다 (2026-08-19)
  ///
  /// 만들기와 같은 폼이 지금 값으로 채워진 채 열린다. 갈리는 것은 안쪽뿐이다.
  ///
  /// | | 고칠 수 있는 칸 | 저장하면 |
  /// |---|---|---|
  /// | 자유 ([_canEditNow]) | 전부 (할 일까지) | 바로 반영 |
  /// | 결재 | 이름·설명·색 + 사유 | 수정 신청 |
  ///
  /// 결재일 때 마감·담당자·참여 멤버·할 일이 잠기는 이유 — 그 셋은 각각
  /// **다른 결재**(기한 연장·인원 추가)를 타고, 프로젝트당 대기 중인 결재는
  /// 하나뿐이라 한 폼에서 같이 올릴 수 없다. 할 일은 결재를 아예 안 타서
  /// 상세 화면의 할 일 카드에서 그대로 고친다.
  Future<void> _requestEdit(BuildContext context) async {
    final free = _canEditNow(project);
    var removed = false;

    final draft = await _showProjectComposer(
      context,
      edit: project,
      // 삭제는 폼 오른쪽 위 휴지통이 맡는다 — 자유면 바로, 아니면 삭제 신청
      onDelete: () async {
        if (free) {
          removed = await _applyDelete(context, pop: false);
          return removed;
        }
        return _requestDelete(context);
      },
      // 결재로 올릴 때만 불린다 (폼이 사유까지 받아서 넘긴다)
      onRequest: (draft, reason) => _sendRequest(
        context,
        type: ProjectRequestType.edit,
        payload: {
          'title': draft.name,
          'purpose': draft.desc,
          'color': ?draft.colorHex,
        },
        reason: reason,
      ),
    );

    if (removed) {
      // 폼은 스스로 닫혔다 — 폰이면 상세도 같이 닫는다
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      onChanged();
      return;
    }
    // 결재로 올린 경우는 폼이 `onRequest` 로 이미 끝냈다 (draft 가 안 온다)
    if (draft == null || !context.mounted) return;
    await _applyEdit(context, draft);
  }

  /// 결재를 안 거치고 바로 고친다 ([_canEditNow] 인 사람)
  ///
  /// 프로젝트 값은 한 번의 `PATCH` 로, 할 일은 [_syncTodos] 가 견줘서 넣고 뺀다.
  Future<void> _applyEdit(BuildContext context, _Project draft) async {
    final projectId = project.id;
    if (projectId == null) return;
    try {
      final saved = await ProjectApi.update(
        projectId,
        title: draft.name,
        purpose: draft.desc,
        color: draft.colorHex,
        due: draft.due,
        ownerId: StaffDirectory.instance.byName(draft.owner)?.id,
        assigneeIds: [
          for (final name in draft.members)
            ?StaffDirectory.instance.byName(name)?.id,
        ],
      );
      await _syncTodos(projectId, draft.todos);
      project
        ..name = saved.title
        ..desc = saved.purpose
        ..colorHex = saved.color
        ..due = saved.due
        ..owner = draft.owner
        ..ownerId = saved.ownerId
        ..memberIds = saved.assigneeIds;
      project.members
        ..clear()
        ..addAll(draft.members);
      _log('프로젝트를 수정했어요');
      onChanged();
      if (context.mounted) AppToast.show(context, '수정했어요');
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 폼에서 돌아온 할 일을 지금 것과 견줘 서버에 반영한다
  ///
  /// **결재를 안 타는 자리다** — 서버가 할 일 편집을 참여자에게 열어 뒀다
  /// (`_ensure_member` 만 본다). 체크 상태는 안 건드린다.
  Future<void> _syncTodos(String projectId, List<_Todo> next) async {
    final keep = {for (final todo in next) ?todo.id};
    for (final old in [...project.todos]) {
      if (old.id case final id? when !keep.contains(id)) {
        await ProjectApi.deleteTodo(projectId, id);
      }
    }
    for (var i = 0; i < next.length; i++) {
      final todo = next[i];
      final assigneeId = StaffDirectory.instance
          .byName(todo.assignee ?? '')
          ?.id;
      if (todo.id case final id?) {
        final before = project.todos.where((t) => t.id == id).firstOrNull;
        // 안 바뀐 줄은 건드리지 않는다 — 줄 수만큼 요청이 나가면 느리다
        if (before != null &&
            before.text == todo.text &&
            before.assignee == todo.assignee) {
          continue;
        }
        await ProjectApi.updateTodo(
          projectId,
          id,
          content: todo.text,
          assigneeId: assigneeId,
        );
      } else {
        final saved = await ProjectApi.addTodo(
          projectId,
          content: todo.text,
          assigneeId: assigneeId,
          sort: i,
        );
        todo.id = saved.id;
      }
    }
    project.todos
      ..clear()
      ..addAll(next);
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
    if (_canEditNow(project)) {
      await _applyMembers(context, ids);
      return;
    }
    await _sendRequest(
      context,
      type: ProjectRequestType.members,
      addIds: ids,
      reason: draft.reason,
    );
  }

  /// 결재를 안 거치고 바로 넣는다 — **더하기만** 한다 (승인 경로와 같은 규칙)
  Future<void> _applyMembers(BuildContext context, List<String> ids) async {
    final projectId = project.id;
    if (projectId == null) return;
    final merged = {...project.memberIds, ...ids}.toList();
    try {
      final saved = await ProjectApi.update(projectId, assigneeIds: merged);
      project
        ..memberIds = saved.assigneeIds
        ..members.clear();
      project.members.addAll([
        for (final id in saved.assigneeIds)
          ?StaffDirectory.instance.byId(id)?.name,
      ]);
      _log('인원을 추가했어요');
      onChanged();
      if (context.mounted) AppToast.show(context, '인원을 추가했어요');
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 프로젝트 완료 — **한 번 되묻는다** (2026-08-19 대표 요청)
  ///
  /// 예전에는 마지막 할 일에 체크하는 순간 저절로 완료됐다. 그 한 번에 점수까지
  /// 붙어서 잘못 눌러도 되돌릴 사람이 대표뿐이었다. 이제 버튼을 따로 두고
  /// 누르면 확인 창을 띄운다.
  Future<void> _complete(BuildContext context) async {
    final yes = await showConfirmDialog(
      context,
      title: '프로젝트를 완료할까요?',
      message: '완료 후 되돌릴 수 없습니다.',
      confirmLabel: '완료',
    );
    if (!yes || !context.mounted) return;

    final projectId = project.id;
    if (projectId == null) return;
    try {
      final saved = await ProjectApi.complete(projectId);
      project.completedAt = saved.completedAt;
      _log('프로젝트를 완료했어요');
      onChanged();
      if (context.mounted) AppToast.show(context, '프로젝트를 완료했어요');
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 삭제 신청 — 승인 전까지 프로젝트는 그대로 있고 '삭제 대기'만 붙는다
  /// **올렸으면 true** — 수정 폼이 이 값을 보고 닫을지 정한다
  Future<bool> _requestDelete(BuildContext context) async {
    final reason = await _showDeleteDialog(context, project);
    if (reason == null || !context.mounted) return false;
    return _sendRequest(
      context,
      type: ProjectRequestType.delete,
      reason: reason,
    );
  }

  /// 결재를 안 거치고 바로 지운다 — **한 번 되묻는다** (2026-08-19)
  ///
  /// [pop] 은 지운 뒤 이 화면을 닫을지다. 수정 폼에서 부를 때는 폼이 스스로
  /// 닫으므로 false 로 넘긴다 (안 그러면 폼과 상세가 한꺼번에 닫힌다).
  /// **지웠으면 true** 를 준다.
  Future<bool> _applyDelete(BuildContext context, {bool pop = true}) async {
    final projectId = project.id;
    if (projectId == null) return false;
    final yes = await showConfirmDialog(
      context,
      title: '프로젝트를 삭제할까요?',
      message: '삭제 후 되돌릴 수 없습니다.',
      confirmLabel: '삭제하기',
      destructive: true,
    );
    if (!yes || !context.mounted) return false;
    try {
      await ProjectApi.delete(projectId);
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
      return false;
    }
    _projects.remove(project);
    if (context.mounted) {
      AppToast.show(context, '삭제했어요');
      if (pop && Navigator.canPop(context)) Navigator.pop(context);
    }
    if (pop) onChanged();
    return true;
  }

  /// 수정·삭제 신청을 올린다 — 둘이 같은 통로라 한 곳에서 보낸다
  Future<bool> _sendRequest(
    BuildContext context, {
    required ProjectRequestType type,
    required String reason,
    Map<String, String>? payload,
    List<String>? addIds,
  }) async {
    final projectId = project.id;
    if (projectId == null) return false;
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
      return true;
    } catch (error) {
      if (context.mounted) AppToast.show(context, messageOf(error));
      return false;
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
  /// **`인원 추가`·`삭제` 는 여기 없다 (2026-08-19).**
  ///
  /// - 인원 추가 → 참여자 아바타 옆 `+` (폰은 상단 글래스 `사람+`)
  /// - 삭제 → **수정 폼 오른쪽 위 휴지통**
  ///
  /// 같은 일을 하는 버튼이 두 군데 있으면 안 된다.
  List<Widget> _headActions(BuildContext context) => [
    if (_canExtend) ...[SizedBox(width: 8), _extendButton(context)],
    if (_canTouchProject(project)) ...[
      SizedBox(width: 4),
      _headButton('수정', () => _requestEdit(context)),
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
        _MemberBar(project: project, onAdd: () => _requestMembers(context)),
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
    // 연장·수정·인원 추가는 상단 글래스 버튼으로 올라가 여기엔 참여자만 남는다.
    // 아바타를 누르면 참여 인원이 뜨는 것은 그대로다
    Row(
      children: [
        _MemberBar(
          project: project,
          onAdd: () => _requestMembers(context),
          showAdd: false,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dday = _dday(project.due);

    return Stack(
      children: [
        ListView(
          // 아래는 **떠 있는 하트·댓글 바가 앉을 자리**를 비운다
          // ([PostActions.inset]) — 안 비우면 마지막 카드가 바에 가린다
          padding: phone
              // 폰 상세는 헤더 뒤로 스크롤되고, 하단바가 없어 화면 아래 여백만 남긴다
              ? EdgeInsets.fromLTRB(
                  20,
                  PhoneDetailScaffold.topPadding,
                  20,
                  MediaQuery.paddingOf(context).bottom + PostActions.inset,
                )
              : EdgeInsets.fromLTRB(
                  28,
                  64,
                  28,
                  bottomBarInset(context) + PostActions.inset,
                ),
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
                  '할 일 ${project.doneCount}/${project.todoCount}',
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
            // 할 일을 다 체크하면 담당자에게만 뜬다 — 이걸 눌러야 완료다 (2026-08-19)
            if (_canCompleteProject(project)) ...[
              SizedBox(height: 16),
              AppButton(
                label: '프로젝트 완료',
                filled: true,
                onTap: () => _complete(context),
              ),
            ],
            SizedBox(height: 16),
            // 댓글은 오른쪽 세로 줄의 말풍선으로 빠졌다 (2026-08-19) —
            // 여기 남은 것은 시스템 활동 기록뿐이다
            _ActivityCard(project: project),
          ],
        ),
        // 하트·댓글 — 공지·회의록과 같은 위젯, 같은 자리 (2026-08-19).
        // 예전 댓글 카드·티저는 걷어냈다
        Positioned(
          left: 0,
          right: 0,
          bottom: (phone ? MediaQuery.paddingOf(context).bottom : 0) + 16,
          child: Center(
            child: PostActions(
              target: ReactionTarget.project,
              targetId: project.id,
              reactions: project.reactions,
              onToggled: (reactions) {
                project.reactions = reactions;
                onChanged();
              },
              commentCount: project.commentCount,
              onCommentCount: (count) {
                project.commentCount = count;
                onChanged();
              },
            ),
          ),
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

/// 헤더 오른쪽 참여자 — **아바타와 `+` 가 서로 다른 일을 한다** (2026-08-19)
///
/// | 누른 곳 | 열리는 것 |
/// |---|---|
/// | 아바타 | 지금 참여 중인 사람 — 담당자부터, **읽기만 한다** |
/// | `+` | 인원 추가 신청 — **참여 안 한 사람만** 고른다 (승인을 받는다) |
///
/// 예전에는 둘이 한 버튼이라 어디를 눌러도 전 직원 목록이 떴고, 거기서
/// 켜고 끈 것이 **서버에 안 갔다** (화면에서만 바뀌었다가 다시 받으면 되돌아왔다).
class _MemberBar extends StatelessWidget {
  _MemberBar({required this.project, required this.onAdd, this.showAdd = true});

  final _Project project;

  /// `+` 를 눌렀을 때 — 상세가 들고 있는 인원 추가 신청으로 이어진다
  final VoidCallback onAdd;

  /// `+` 를 그릴까 — **폰은 안 그린다** (2026-08-19).
  /// 상단 글래스 `사람+` 가 같은 일을 해서 한 화면에 둘로 보였다.
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: () => _showMemberList(context, project),
          // 둘로 나누면서도 **자리는 그대로 둔다** — 예전에는 한 버튼이
          // 좌우 6 을 두고 가운데 틈이 6 이었다. 안쪽을 3+3 으로 나눠 맞춘다
          padding: showAdd
              ? EdgeInsets.fromLTRB(6, 4, 3, 4)
              : EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: AvatarStack(names: project.members, size: 28),
        ),
        if (showAdd)
          Pressable(
            onTap: onAdd,
            padding: EdgeInsets.fromLTRB(3, 4, 6, 4),
            child: Container(
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
          ),
      ],
    );
  }
}
