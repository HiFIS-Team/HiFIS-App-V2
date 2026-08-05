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
      text: '기한 연장 신청 ($before → ${_date(draft.due)})',
      time: DateTime.now(),
    ),
  );
  onChanged();
}

/// 연장 신청을 올릴 수 있는 상태 (끝났거나 이미 올린 신청이 있으면 못 올린다)
///
/// **대표·관리자는 못 올린다.** 일을 하는 사람이 올리고 대표가 결재하는 흐름이라,
/// 자기가 올려서 자기가 승인하는 자리가 되면 결재가 뜻을 잃는다.
bool _canExtendProject(_Project project) =>
    myRole.doesFieldWork &&
    project.phase != _Phase.done &&
    project.request == null;

/// 연장 신청을 결재할 수 있는 사람 — 서버가 MASTER 로만 열어 뒀다
bool get _canDecideRequest => myRole == Role.master;

/// 완료된 프로젝트는 손대지 못한다 — **MASTER 만** 되돌릴 수 있다
///
/// 완료가 곧 점수라, 됐다 안 됐다 하면 담당자 점수도 같이 흔들린다.
/// 서버도 같은 기준으로 막는다 (`_ensure_open` → 403 `PROJECT_DONE`).
/// 댓글은 잠기지 않는다.
bool _isLocked(_Project project) =>
    project.phase == _Phase.done && myRole != Role.master;

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

    if (approve) {
      _log(
        '기한 연장 승인 (${_date(project.due)} → ${_date(request.due)}) · $reason',
      );
      // 승인하면 서버가 프로젝트 마감일을 새 날짜로 바꿔 준다
      project.due = request.due;
    } else {
      _log('기한 연장 반려 (마감일 ${_date(project.due)} 유지) · $reason');
    }
    project.request = null;
    onChanged();
    if (context.mounted) {
      // 다른 결재 자리와 같은 문구 — 방금 누른 버튼 옆이라 뭘 처리했는지는 분명하다
      AppToast.show(context, approve ? '승인했어요' : '반려했어요');
    }
  }

  /// 연장 신청 버튼 (끝난 프로젝트나 이미 올린 신청이 있으면 감춘다)
  Widget _extendButton(BuildContext context) => Pressable(
    onTap: () => _requestExtension(context),
    scale: 0.94,
    pressedColor: AppColors.gray100,
    borderRadius: BorderRadius.circular(100),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Text(
      '기한 연장',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  bool get _canExtend => _canExtendProject(project);

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
        if (_canExtend) ...[SizedBox(width: 8), _extendButton(context)],
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
              '기한 연장 승인 대기',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_date(project.due)} → ${_date(request.due)}',
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
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
