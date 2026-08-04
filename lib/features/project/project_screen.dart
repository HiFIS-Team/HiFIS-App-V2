import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/project_api.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/glass_input_bar.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scroll_box.dart';

part 'project_comments.dart';
part 'project_phone.dart';

/// 프로젝트 화면 (목업)
///
/// 데스크톱은 좌측 목록 + 우측 상세 2단 구조(사내톡 전체보기와 같은 결).
/// 폰은 같은 내용을 목록 화면 + 상세 화면 두 장으로 나눠 보여준다.
/// 진행률은 따로 입력받지 않고 할 일 체크 비율로 자동 계산한다.
class ProjectScreen extends StatefulWidget {
  ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  /// 보고 있는 단계 (진행 중 / 완료 / 누락)
  _Phase _phase = _Phase.running;

  /// 선택한 프로젝트 (목록이 바뀌면 첫 항목으로 되돌린다)
  _Project? _selected;

  /// 첫 진입에만 스피너를 돌린다 — 탭을 다시 열 때는 받아둔 목록을 바로 그린다
  bool _loading = !_projectsLoaded;

  @override
  void initState() {
    super.initState();
    // 홈에서 넘어오며 걸어둔 요청은 첫 빌드 전에 반영한다 (setState 필요 없음)
    _consumeRequest();
    requestedProject.addListener(_onRequest);
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadProjects();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 상세를 열 때 체크리스트와 타임라인을 받아 온다 (둘을 같이 띄운다)
  Future<void> _openDetail(_Project project) async {
    if (project.detailLoaded) return;
    try {
      await _loadDetail(project);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  void dispose() {
    requestedProject.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    if (_consumeRequest()) setState(() {});
  }

  /// 대기 중인 요청이 있으면 선택에 반영한다.
  /// 비우면서 리스너가 한 번 더 돌지만 값이 null이라 바로 빠져나온다.
  bool _consumeRequest() {
    final brief = requestedProject.value;
    if (brief == null) return false;
    requestedProject.value = null;
    _phase = brief._project.phase;
    _selected = brief._project;
    return true;
  }

  List<_Project> get _visible {
    final list = _projects.where((p) => p.phase == _phase).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return list;
  }

  /// 데이터가 바뀌어도 선택이 목록 밖으로 나가지 않게 맞춰준다
  _Project? _syncSelection(List<_Project> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  Future<void> _create() async {
    final draft = await _showProjectComposer(context);
    if (draft == null || !mounted) return;

    try {
      final created = await _saveNewProject(draft);
      if (!mounted) return;
      setState(() {
        _projects.insert(0, created);
        // 만든 건 바로 열어준다 (마감이 남아 있으니 진행 중)
        _phase = _Phase.running;
        _selected = created;
      });
      AppToast.show(context, '프로젝트를 만들었어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: isDesktop ? null : AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final list = _visible;

    if (!isDesktop) {
      return _ProjectPhone(
        projects: list,
        phase: _phase,
        onFilter: (v) => setState(() => _phase = v),
        onCreate: _create,
        onChanged: () => setState(() {}),
        onOpen: _openDetail,
      );
    }

    final selected = _syncSelection(list);
    // 데스크톱은 고른 프로젝트가 바로 상세로 열린다 — 그때 상세 내용을 받는다
    if (selected != null && !selected.detailLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openDetail(selected),
      );
    }

    // 배경은 다른 화면과 같은 회색 — 카드가 떠 보이게 한다.
    // 목록 쪽만 흰 패널로 둬서 좌우 영역이 구분된다.
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _ProjectList(
                projects: list,
                selected: selected,
                phase: _phase,
                onFilter: (v) => setState(() {
                  _phase = v;
                  _selected = null;
                }),
                onSelect: (p) => setState(() => _selected = p),
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyDetail(phase: _phase)
                : _ProjectDetail(
                    // 프로젝트를 바꾸면 상세를 새로 그린다 (스크롤·입력 초기화)
                    key: ValueKey(selected.name),
                    project: selected,
                    onChanged: () => setState(() {}),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 목록 ──

class _ProjectList extends StatelessWidget {
  _ProjectList({
    required this.projects,
    required this.selected,
    required this.phase,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Project> projects;
  final _Project? selected;
  final _Phase phase;
  final ValueChanged<_Phase> onFilter;
  final ValueChanged<_Project> onSelect;
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
              Text('프로젝트', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${projects.length}',
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
                      '새 프로젝트',
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
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _PhaseTabs(selected: phase, onSelect: onFilter),
        ),
        Expanded(
          child: projects.isEmpty
              // Expanded 안에서 카드가 세로로 늘어나지 않게 위에 붙인다
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: EmptyCard(
                      icon: Icons.folder_rounded,
                      text: '${phase.label} 프로젝트가 없어요',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _ProjectTile(
                    project: projects[i],
                    selected: projects[i] == selected,
                    onTap: () => onSelect(projects[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 진행 중 / 완료 / 누락 세그먼트 (ModeSwitch와 같은 결의 3단 버전)
class _PhaseTabs extends StatelessWidget {
  _PhaseTabs({required this.selected, required this.onSelect});

  final _Phase selected;
  final ValueChanged<_Phase> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          for (final phase in _Phase.values)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(phase),
                scale: 0.97,
                // 배경은 애니메이션 없이 즉시 바꾼다 (페이드가 있으면 두 칸이
                // 같이 눌린 것처럼 보인다)
                child: Container(
                  decoration: segmentFill(selected: phase == selected),
                  child: Center(
                    child: Text(
                      phase.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: phase == selected
                            ? AppColors.textPrimary
                            : AppColors.gray600,
                        fontWeight: phase == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 목록 카드 한 장 — 이름·진행률 막대·D-day·참여자
class _ProjectTile extends StatefulWidget {
  _ProjectTile({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final _Project project;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final dday = _dday(project.due);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: project.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  _DdayBadge(dday: dday, phase: project.phase),
                ],
              ),
              SizedBox(height: 10),
              _ProgressBar(value: project.progress, color: project.color),
              SizedBox(height: 8),
              Row(
                children: [
                  AvatarStack(names: project.members, size: 20),
                  Spacer(),
                  Text(
                    '할 일 ${project.doneCount}/${project.todos.length}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고른 프로젝트가 없을 때의 우측 안내
class _EmptyDetail extends StatelessWidget {
  _EmptyDetail({required this.phase});

  final _Phase phase;

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
                Icons.folder_rounded,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('프로젝트', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            phase == _Phase.running
                ? '왼쪽에서 프로젝트를 골라주세요'
                : '${phase.label} 프로젝트가 아직 없어요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

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
bool _canExtendProject(_Project project) =>
    project.phase != _Phase.done && project.request == null;

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
      AppToast.show(context, approve ? '기한 연장을 승인했어요' : '기한 연장을 반려했어요');
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
        if (project.request != null) ...[
          SizedBox(height: 14),
          _ExtensionCard(
            project: project,
            onApprove: () => _decide(context, approve: true),
            onReject: () => _decide(context, approve: false),
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
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// 반려·승인 버튼 (폰은 [fill]로 가로를 꽉 채운다)
  Widget _buttons({required bool fill}) {
    final reject = Pressable(
      onTap: onReject,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text(
          '반려',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final approve = Pressable(
      onTap: onApprove,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '승인',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: fill
          ? [
              Expanded(child: reject),
              SizedBox(width: 8),
              Expanded(child: approve),
            ]
          : [reject, SizedBox(width: 6), approve],
    );
  }

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
          '${request.requester} · ${_relative(request.time)} 신청',
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
                SizedBox(width: 12),
                _buttons(fill: false),
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
                SizedBox(height: 12),
                _buttons(fill: true),
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

/// 할 일 체크리스트 — 체크 비율이 그대로 진행률이 된다.
/// 할 일은 프로젝트를 만들 때 받으므로 여기서는 체크·담당자 변경·삭제만 한다.
class _TodoCard extends StatelessWidget {
  _TodoCard({
    required this.project,
    required this.onToggle,
    required this.onRemove,
    required this.onAssign,
  });

  final _Project project;
  final ValueChanged<_Todo> onToggle;
  final ValueChanged<_Todo> onRemove;
  final ValueChanged<_Todo> onAssign;

  @override
  Widget build(BuildContext context) {
    final todos = project.todos;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('할 일', style: AppTextStyles.label),
          SizedBox(height: 6),
          if (todos.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '등록된 할 일이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (final todo in todos)
              _TodoRow(
                todo: todo,
                onToggle: () => onToggle(todo),
                onRemove: () => onRemove(todo),
                onAssign: () => onAssign(todo),
              ),
        ],
      ),
    );
  }
}

/// 할 일 한 줄 — 체크·내용·담당자, 커서를 올리면 삭제가 나온다
class _TodoRow extends StatefulWidget {
  _TodoRow({
    required this.todo,
    required this.onToggle,
    required this.onRemove,
    required this.onAssign,
  });

  final _Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onAssign;

  @override
  State<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<_TodoRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    // 폰은 커서가 없으니 삭제 버튼을 항상 띄워둔다
    final showRemove = _hover || !isDesktop;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Pressable(
              onTap: widget.onToggle,
              scale: 0.9,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: todo.done ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.done ? AppColors.primary : AppColors.gray300,
                    width: 1.5,
                  ),
                ),
                child: todo.done
                    ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                todo.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: todo.done
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.gray400,
                ),
              ),
            ),
            SizedBox(width: 8),
            _AssigneeChip(name: todo.assignee, onTap: widget.onAssign),
            SizedBox(width: 4),
            SizedBox(
              width: 28,
              child: showRemove
                  ? Pressable(
                      onTap: widget.onRemove,
                      scale: 0.9,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.gray400,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 담당자 알약 — 누르면 참여자 중에서 고른다
class _AssigneeChip extends StatelessWidget {
  _AssigneeChip({required this.name, required this.onTap});

  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assigned = name != null;

    return Pressable(
      onTap: onTap,
      scale: 0.96,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(100),
      padding: EdgeInsets.fromLTRB(assigned ? 3 : 8, 3, 8, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assigned) ...[Avatar(name: name!, size: 20), SizedBox(width: 5)],
          Text(
            assigned ? name! : '담당자',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: assigned ? AppColors.textSecondary : AppColors.gray400,
              fontWeight: assigned ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 할 일 입력 줄 (생성 폼 전용) — 적고 엔터를 치면 바로 아래 목록에 쌓인다
class _TodoComposer extends StatefulWidget {
  _TodoComposer({required this.members, required this.onAdd});

  final List<String> members;
  final void Function(String text, String? assignee) onAdd;

  @override
  State<_TodoComposer> createState() => _TodoComposerState();
}

class _TodoComposerState extends State<_TodoComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _assignee;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text, _assignee);
    _controller.clear();
    // 연달아 적을 수 있게 담당자와 포커스는 유지한다
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: AppTextStyles.body2,
              cursorColor: AppColors.primary,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '할 일을 적고 엔터',
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ),
        SizedBox(width: 6),
        _AssigneeChip(
          name: _assignee,
          onTap: () async {
            final picked = await _pickMember(
              context,
              names: widget.members,
              current: _assignee,
            );
            if (picked == null) return;
            setState(() => _assignee = picked.isEmpty ? null : picked);
            _focus.requestFocus();
          },
        ),
        SizedBox(width: 4),
        Pressable(
          onTap: _submit,
          scale: 0.94,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_rounded, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// 댓글·활동 타임라인
class _ActivityCard extends StatefulWidget {
  _ActivityCard({required this.project, required this.onComment});

  final _Project project;

  /// 서버에 올리고 오는 동안 기다려야 해서 `ValueChanged` 가 아니다
  final Future<void> Function(String) onComment;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 활동은 계속 쌓이므로 처음에는 최근 것만 보여준다
  static const _fold = 5;
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // 입력칸은 먼저 비운다 — 서버를 기다리는 동안 두 번 눌리지 않게
    _controller.clear();
    // 보낸 뒤에도 계속 쓸 수 있게 포커스를 되돌린다
    _focus.requestFocus();
    await widget.onComment(text);
  }

  @override
  Widget build(BuildContext context) {
    // 폰은 댓글이 시트로 빠져서 여기엔 시스템 기록만 남는다
    final all = isDesktop
        ? widget.project.events
        : widget.project.events.where((e) => !e.comment).toList();
    final events = _expanded ? all : all.take(_fold).toList();
    final hidden = all.length - events.length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('활동', style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '${all.length}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          // 댓글 입력 — 폰은 시트로 빠져서 데스크톱에서만 둔다
          if (isDesktop) ...[
            SizedBox(height: 12),
            // 댓글 입력
            Row(
              children: [
                Avatar(name: me, size: 34),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      style: AppTextStyles.body2,
                      cursorColor: AppColors.primary,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '댓글을 남겨보세요',
                        hintStyle: AppTextStyles.body2.copyWith(
                          color: AppColors.gray400,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Pressable(
                  onTap: _send,
                  scale: 0.94,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '아직 활동이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (final event in events)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.comment)
                      Avatar(name: event.author, size: 28)
                    else
                      // 시스템 기록은 아바타 대신 점으로 구분한다
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                event.author,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _relative(event.time),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1),
                          Text(
                            event.text,
                            style: AppTextStyles.body2.copyWith(
                              color: event.comment
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (hidden > 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Pressable(
                onTap: () => setState(() => _expanded = true),
                scale: 0.99,
                pressedColor: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  '이전 활동 $hidden개 더 보기',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 공통 조각 ──

/// D-day 배지 — 임박할수록 빨개지고, 끝난 프로젝트는 단계를 그대로 보여준다
class _DdayBadge extends StatelessWidget {
  _DdayBadge({required this.dday, required this.phase});

  final int dday;
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      _Phase.done => AppColors.success,
      _Phase.missed => AppColors.error,
      _Phase.running when dday <= 2 => AppColors.error,
      _Phase.running when dday <= 7 => AppColors.warning,
      _Phase.running => AppColors.primary,
    };
    final label = switch (phase) {
      _Phase.done => '완료',
      _Phase.missed => '누락 ${-dday}일',
      _Phase.running when dday == 0 => 'D-DAY',
      _Phase.running => 'D-$dday',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 진행률 막대
class _ProgressBar extends StatelessWidget {
  _ProgressBar({required this.value, required this.color, this.height = 5});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: AppColors.gray100,
        valueColor: AlwaysStoppedAnimation(
          value >= 1 ? AppColors.success : color,
        ),
      ),
    );
  }
}

// ── 팝업 ──

/// 담당자 고르기 — 고르면 이름, '담당자 없음'이면 빈 문자열, 취소면 null
Future<String?> _pickMember(
  BuildContext context, {
  required List<String> names,
  String? current,
}) {
  return showAppDialog<String>(
    context,
    (context) => Container(
      width: dialogWidth(context, 280),
      padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
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
            child: Text('담당자 선택', style: AppTextStyles.title3),
          ),
          SizedBox(height: 8),
          for (final name in names)
            _PickRow(
              name: name,
              role: staffOf(name).role,
              selected: name == current,
              onTap: () => Navigator.pop(context, name),
            ),
          Divider(height: 12, color: AppColors.divider),
          Pressable(
            onTap: () => Navigator.pop(context, ''),
            scale: 0.98,
            pressedColor: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Text(
              '담당자 없음',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 담당자 목록 한 줄
class _PickRow extends StatelessWidget {
  _PickRow({
    required this.name,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Avatar(name: name, size: 30),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(role, style: AppTextStyles.caption),
          if (selected) ...[
            SizedBox(width: 8),
            Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

/// 기한 연장 결재 — 승인이든 반려든 사유를 받아 돌려준다 (취소면 null)
Future<String?> _showDecisionDialog(
  BuildContext context, {
  required _Project project,
  required bool approve,
}) {
  return showAppDialog<String>(
    context,
    (context) => _DecisionDialog(project: project, approve: approve),
  );
}

class _DecisionDialog extends StatefulWidget {
  _DecisionDialog({required this.project, required this.approve});

  final _Project project;
  final bool approve;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(
        context,
        widget.approve ? '승인 사유를 입력해주세요' : '반려 사유를 입력해주세요',
      );
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final project = widget.project;
    final request = project.request!;
    final accent = approve ? AppColors.primary : AppColors.error;
    final empty = _reason.text.trim().isEmpty;

    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(approve ? '기한 연장 승인' : '기한 연장 반려', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            approve ? '승인하면 마감일이 바로 바뀝니다' : '반려하면 지금 마감일 그대로 갑니다',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          // 무엇을 결재하는지 다시 보여준다
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_date(project.due)} → ${_date(request.due)}',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${request.requester} 신청',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  request.reason,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: approve ? '승인 사유를 적어주세요' : '반려 사유를 적어주세요',
            lines: 3,
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Pressable(
                onTap: () => Navigator.pop(context),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
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
              Pressable(
                onTap: _submit,
                scale: 0.97,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    // 사유를 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                    color: empty ? AppColors.gray200 : accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    approve ? '승인' : '반려',
                    style: AppTextStyles.body2.copyWith(
                      color: empty ? AppColors.gray500 : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 기한 연장 신청 폼 — 새 마감일과 사유를 받아 신청을 돌려준다
Future<_Extension?> _showExtensionDialog(
  BuildContext context,
  _Project project,
) {
  return showAppDialog<_Extension>(
    context,
    (context) => _ExtensionDialog(project: project),
  );
}

class _ExtensionDialog extends StatefulWidget {
  _ExtensionDialog({required this.project});

  final _Project project;

  @override
  State<_ExtensionDialog> createState() => _ExtensionDialogState();
}

class _ExtensionDialogState extends State<_ExtensionDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  /// 기본은 기존 마감에서 일주일 뒤 (이미 지났으면 오늘부터 일주일)
  late DateTime _due = _later(widget.project.due).add(Duration(days: 7));

  static DateTime _later(DateTime due) {
    final now = DateTime.now();
    return due.isAfter(now) ? due : now;
  }

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    // 연장이므로 기존 마감(또는 오늘) 다음 날부터 고를 수 있다
    final first = _later(widget.project.due).add(Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: first,
      lastDate: DateTime(first.year + 3),
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

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, '연장 사유를 입력해주세요');
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(
      context,
      _Extension(
        requester: me,
        due: _due,
        reason: reason,
        time: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final overdue = _dday(project.due) < 0;

    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기한 연장 신청', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '승인되면 마감일이 바뀌고, 반려되면 지금 마감일 그대로 갑니다',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('현재 마감', style: AppTextStyles.label),
              ),
              Text(
                _date(project.due),
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: overdue ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              if (overdue) ...[
                SizedBox(width: 6),
                Text(
                  '${-_dday(project.due)}일 지남',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('연장 마감', style: AppTextStyles.label),
              ),
              Pressable(
                onTap: _pickDue,
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
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
              _DdayBadge(dday: _dday(_due), phase: _Phase.running),
            ],
          ),
          SizedBox(height: 14),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: '왜 연장이 필요한가요?',
            lines: 3,
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Pressable(
                onTap: () => Navigator.pop(context),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
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
              Pressable(
                onTap: _submit,
                scale: 0.97,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    // 사유를 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                    color: _reason.text.trim().isEmpty
                        ? AppColors.gray200
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '신청',
                    style: AppTextStyles.body2.copyWith(
                      color: _reason.text.trim().isEmpty
                          ? AppColors.gray500
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 새 프로젝트 만들기 — 만들면 그 프로젝트를 돌려준다
Future<_Project?> _showProjectComposer(BuildContext context) {
  // 폰은 팝업이 답답해서 오른쪽에서 밀려 들어오는 페이지로 연다
  if (!isDesktop) {
    return Navigator.push<_Project>(
      context,
      CupertinoPageRoute(builder: (_) => _ProjectComposer(phone: true)),
    );
  }
  return showAppDialog<_Project>(context, (context) => _ProjectComposer());
}

class _ProjectComposer extends StatefulWidget {
  _ProjectComposer({this.phone = false});

  /// 폰은 팝업이 아니라 밀려 들어오는 페이지로 뜬다
  final bool phone;

  @override
  State<_ProjectComposer> createState() => _ProjectComposerState();
}

class _ProjectComposerState extends State<_ProjectComposer> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _nameFocus = FocusNode();

  /// 기본 마감은 2주 뒤
  late DateTime _due = DateTime.now().add(Duration(days: 14));

  /// 나는 항상 참여한다 (담당자 기본값이라 뺄 수 없게 둔다)
  final _members = <String>[me];

  /// 만들면서 같이 등록할 할 일
  final _todos = <_Todo>[];

  String _owner = me;
  Color _color = AppColors.primary;

  /// 프로젝트를 구분하는 색 — 빨강은 D-day 배지와 헷갈려서 뺐다
  static const _palette = [
    AppColors.primary,
    Color(0xFF7C5CFC),
    Color(0xFF00A8B5),
    AppColors.success,
    AppColors.warning,
    Color(0xFF8B95A1),
  ];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    // 페이지가 밀려 들어오는 중에 키보드가 같이 올라오면 어수선해서
    // 폰에서는 자동 포커스를 두지 않는다
    if (!widget.phone) _nameFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
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
        // 빠진 사람이 맡기로 한 자리는 비워둔다
        if (_owner == name) _owner = me;
        for (final todo in _todos) {
          if (todo.assignee == name) todo.assignee = null;
        }
      } else {
        _members.add(name);
      }
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, '프로젝트 이름을 입력해주세요');
      _nameFocus.requestFocus();
      return;
    }
    final now = DateTime.now();
    Navigator.pop(
      context,
      _Project(
        name: name,
        desc: _desc.text.trim(),
        colorHex: _hexOf(_color),
        owner: _owner,
        start: now,
        due: _due,
        // 명단 순서대로 정렬해 두면 아바타 줄이 화면마다 같은 순서로 보인다
        members: [
          for (final staff in staffList)
            if (_members.contains(staff.name)) staff.name,
        ],
        todos: _todos,
        // 타임라인은 서버가 만들면서 '프로젝트를 만들었어요' 를 쌓아 준다
        events: [],
      ),
    );
  }

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
              onTap: _pickDue,
              scale: 0.97,
              pressedColor: AppColors.gray100,
              borderRadius: BorderRadius.circular(10),
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
              name: _owner,
              onTap: () async {
                final picked = await _pickMember(
                  context,
                  names: _members,
                  current: _owner,
                );
                // 담당은 비울 수 없다 (빈 문자열 = 담당자 없음)
                if (picked == null || picked.isEmpty) return;
                setState(() => _owner = picked);
              },
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('색상', style: AppTextStyles.label)),
            for (final color in _palette)
              Pressable(
                onTap: () => setState(() => _color = color),
                scale: 0.9,
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
                  // 나는 담당 기본값이라 빼지 않는다
                  onTap: staff.name == me
                      ? null
                      : () => _toggleMember(staff.name),
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
        _TodoComposer(
          members: _members,
          onAdd: (text, assignee) =>
              setState(() => _todos.add(_Todo(text: text, assignee: assignee))),
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
                Pressable(
                  onTap: () => setState(() => _todos.remove(todo)),
                  scale: 0.9,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 만들기 버튼 (데스크톱 팝업 전용 — 폰은 하단 글래스 버튼을 쓴다)
  Widget _submitButton() {
    final empty = _name.text.trim().isEmpty;

    return Pressable(
      onTap: _submit,
      scale: 0.97,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          // 이름을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
          color: empty ? AppColors.gray200 : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '만들기',
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
        title: '새 프로젝트',
        // 만들기는 하단 탭바 자리에 글래스 버튼으로 띄운다
        bottomBar: GlassBottomButton(
          label: '만들기',
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
            Text('새 프로젝트', style: AppTextStyles.title2),
            SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _form(context, dday))),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
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
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
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
      scale: onTap == null ? 1 : 0.96,
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

/// 참여 멤버 관리 — 직원을 눌러 넣고 뺀다
void _showMemberManager(
  BuildContext context,
  _Project project,
  VoidCallback onChanged,
) {
  // 고를 때마다 뒤 화면까지 다시 그리면 한 번 누른 게 두 번 반응한 것처럼 보인다.
  // 팝업 안에서만 갱신하고, 닫을 때 한 번만 위로 알린다.
  showAppDialog<void>(
    context,
    (context) => StatefulBuilder(
      builder: (context, setLocal) => Container(
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
              child: Text('참여 멤버', style: AppTextStyles.title3),
            ),
            SizedBox(height: 8),
            // 직원이 늘면 팝업이 화면 밖으로 나간다 — 높이만 막고 안에서 스크롤
            ScrollBox(
              maxHeight: kListBoxHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final staff in staffList)
                    _MemberToggleRow(
                      staff: staff,
                      joined: project.members.contains(staff.name),
                      onTap: () {
                        setLocal(() {
                          if (project.members.contains(staff.name)) {
                            project.members.remove(staff.name);
                            // 빠진 사람이 맡고 있던 할 일은 담당자를 비운다
                            for (final todo in project.todos) {
                              if (todo.assignee == staff.name) {
                                todo.assignee = null;
                              }
                            }
                          } else {
                            project.members.add(staff.name);
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ).then((_) => onChanged());
}

/// 멤버 관리 한 줄 — 오른쪽 동그라미로 참여 여부를 보여준다
class _MemberToggleRow extends StatelessWidget {
  _MemberToggleRow({
    required this.staff,
    required this.joined,
    required this.onTap,
  });

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Avatar(name: staff.name, size: 32),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              staff.name == me ? '${staff.name} (나)' : staff.name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(staff.role, style: AppTextStyles.caption),
          SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: joined ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: joined ? AppColors.primary : AppColors.gray300,
                width: 1.5,
              ),
            ),
            child: joined
                ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}

// ── 데이터 ──

/// 할 일 한 건 (서버 `ProjectTodo`)
class _Todo {
  _Todo({required this.text, this.id, this.assignee, this.done = false});

  /// 서버 uuid — null 이면 아직 안 올린 것 (새 프로젝트 만들 때 미리 적은 항목)
  String? id;

  String text;
  String? assignee;
  bool done;
}

/// 타임라인 한 줄 (서버 `ProjectActivity`) — 댓글이면 comment = true
class _Event {
  _Event({
    required this.author,
    required this.text,
    required this.time,
    this.id,
    this.comment = false,
  });

  /// 서버 uuid — **댓글만 갖는다**. 시스템 기록은 고치거나 지울 수 없다
  final String? id;

  final String author;
  final String text;
  final DateTime time;
  final bool comment;
}

/// 프로젝트가 놓인 단계 — 목록 탭 순서와 같다
enum _Phase {
  running('진행 중'),
  done('완료'),
  missed('누락');

  const _Phase(this.label);

  final String label;
}

/// 기한 연장 신청 한 건 (승인 전까지 마감일은 그대로다)
class _Extension {
  _Extension({
    required this.requester,
    required this.due,
    required this.reason,
    required this.time,
    this.id,
  });

  /// 서버 요청 uuid — 승인·반려할 때 쓴다
  final String? id;

  final String requester;

  /// 신청한 새 마감일
  final DateTime due;
  final String reason;
  final DateTime time;
}

/// 프로젝트 한 건 — 진행률은 할 일에서 계산한다
class _Project {
  _Project({
    required this.name,
    required this.desc,
    required this.owner,
    required this.start,
    required this.due,
    required this.members,
    required this.todos,
    required this.events,
    this.id,
    this.colorHex,
    this.createdById,
    this.memberIds = const [],
    this.serverProgress = 0,
    this.serverTodoCount = 0,
    this.serverDoneCount = 0,
    this.request,
  });

  /// 서버 uuid — null 이면 아직 안 올린 것
  String? id;

  String name;
  String desc;

  /// 만들 때 고른 색 (`#RRGGBB`) — 서버가 들고 있다.
  /// 색 필드가 생기기 전에 올린 프로젝트는 null 이라 [color] 가 대신 만들어 낸다
  String? colorHex;

  String owner;
  final String? createdById;
  DateTime start;

  /// 마감일 — 기한 연장이 승인되면 늘어난다
  DateTime due;

  final List<String> members;

  /// 참여자 uuid — 서버에 보낼 때 쓴다. [members] 와 같은 사람들이다
  List<String> memberIds;

  final List<_Todo> todos;

  /// 활동 기록·댓글 — 서버 타임라인(`GET /projects/{id}/activities`).
  /// 댓글과 시스템 활동이 한 줄기로 섞여 최신순으로 온다
  final List<_Event> events;

  /// 체크리스트를 받아왔는지 — 상세를 열 때 한 번만 받는다.
  /// 새로 만든 프로젝트는 만들면서 바로 채우므로 [_saveNewProject] 가 켠다.
  bool todosLoaded = false;

  /// 타임라인을 받아왔는지 — 체크리스트와 같이 상세를 열 때 받는다
  bool eventsLoaded = false;

  /// 상세를 받는 중인 요청 — [_loadDetail] 이 붙잡아 둔다
  Future<void>? loading;

  /// 상세에 필요한 걸 다 받았는지
  bool get detailLoaded => todosLoaded && eventsLoaded;

  /// 목록 띠·진행률 막대에 쓰는 색.
  /// 서버 값이 없거나 못 읽으면 id 에서 만들어 쓴다 — 어느 기기에서나 같은 색이 나온다
  Color get color => _hexColor(colorHex) ?? _projectColor(id ?? name);

  /// 목록에서 쓰는 서버 값. 체크리스트를 받기 전에는 이걸로 그린다
  int serverProgress;
  int serverTodoCount;
  int serverDoneCount;

  /// 결재를 기다리는 기한 연장 신청 (없으면 null)
  _Extension? request;

  int get todoCount => todosLoaded ? todos.length : serverTodoCount;

  int get doneCount =>
      todosLoaded ? todos.where((t) => t.done).length : serverDoneCount;

  /// 0~1. 체크리스트가 있으면 완료 비율, 없으면 서버가 들고 있는 수동값.
  /// **서버 `_recompute_progress` 와 같은 규칙이다.**
  double get progress =>
      todoCount == 0 ? serverProgress / 100 : doneCount / todoCount;

  /// 단계는 따로 관리하지 않고 진행률과 마감일에서 끌어낸다.
  /// 서버 `_status` 와 같은 순서로 판정하되, **서버의 `WAITING`(진행률 0)은
  /// 진행 중에 합친다** — 앱 탭이 진행 중·완료·누락 셋뿐이다.
  _Phase get phase {
    if (progress >= 1) return _Phase.done;
    if (_dday(due) < 0) return _Phase.missed;
    return _Phase.running;
  }
}

/// 올라온 프로젝트 — 서버에서 받아 온다.
/// 탭을 오가도 다시 받지 않도록 모듈 전역으로 둔다.
final _projects = <_Project>[];

/// 한 번이라도 받아왔는지 — 탭을 다시 열 때 빈 목록을 깜빡이지 않게 한다
bool _projectsLoaded = false;

Future<void> _loadProjects() async {
  // 결재 대기 중인 기한 변경 요청을 같이 받아 프로젝트에 붙인다
  final listing = ProjectApi.list();
  final pending = ProjectApi.requests(status: ProjectRequestStatus.pending);
  final rows = await listing;
  final requests = <String, ProjectRequest>{
    for (final request in await pending) request.projectId: request,
  };

  _projects
    ..clear()
    ..addAll([for (final row in rows) _fromServer(row, requests[row.id])]);
  _projectsLoaded = true;
}

/// 서버 프로젝트 → 화면 모델
///
/// 체크리스트와 타임라인은 여기서 안 받는다. 목록에는 개수(`todoCount`·
/// `doneCount`)만 있으면 되고, 나머지는 상세를 열 때 [_loadTodos]·
/// [_loadActivities] 로 받는다.
_Project _fromServer(Project row, ProjectRequest? request) {
  return _Project(
    id: row.id,
    name: row.title,
    desc: row.purpose,
    colorHex: row.color,
    owner: _nameOf(row.createdById),
    createdById: row.createdById,
    start: row.startAt,
    due: row.due,
    members: [for (final id in row.assigneeIds) _nameOf(id)]
      ..removeWhere((name) => name.isEmpty),
    memberIds: row.assigneeIds,
    todos: [],
    events: [],
    serverProgress: row.progress,
    serverTodoCount: row.todoCount,
    serverDoneCount: row.doneCount,
    request: request == null
        ? null
        : _Extension(
            id: request.id,
            requester: _nameOf(request.requestedById),
            due: request.newDue,
            reason: request.reason,
            time: request.createdAt,
          ),
  );
}

/// uuid → 이름. 명단에 없으면(퇴사자 등) 빈 문자열
String _nameOf(String id) => StaffDirectory.instance.byId(id)?.name ?? '';

/// 색 필드가 생기기 전에 올린 프로젝트에 쓰는 대체 색
///
/// 카드 띠·진행률 막대가 색으로 프로젝트를 가르므로 비워 둘 수 없다.
/// id 에서 만들어서 어느 기기에서나 같은 색이 나오게 한다.
const _projectColors = [
  AppColors.primary,
  AppColors.error,
  AppColors.warning,
  AppColors.success,
  Color(0xFF7C5CFC),
  Color(0xFF00A8B5),
  Color(0xFFE0447C),
];

Color _projectColor(String key) =>
    _projectColors[key.hashCode.abs() % _projectColors.length];

/// `#RRGGBB` → 색. 못 읽으면 null (아바타 색과 같은 규칙이다)
Color? _hexColor(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final rgb = int.tryParse(hex, radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

/// 색 → `#RRGGBB`. 서버는 이 형식으로만 받는다
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 상세를 열 때 체크리스트를 받는다 — 한 번 받으면 다시 받지 않는다
Future<void> _loadTodos(_Project project) async {
  final id = project.id;
  if (id == null || project.todosLoaded) return;
  final rows = await ProjectApi.todos(id);
  project.todos
    ..clear()
    ..addAll([
      for (final row in rows)
        _Todo(
          id: row.id,
          text: row.content,
          assignee: row.assigneeId == null ? null : _nameOf(row.assigneeId!),
          done: row.done,
        ),
    ]);
  project.todosLoaded = true;
}

/// 상세를 열 때 타임라인을 받는다 — 한 번 받으면 다시 받지 않는다.
///
/// 화면에서 미리 끼워 넣은 줄(체크 완료·연장 신청 등)은 여기서 **서버 것으로
/// 통째로 갈린다.** 서버가 안 남기는 활동은 그때 사라진다 (backend-gap.md 3번).
Future<void> _loadActivities(_Project project) async {
  final id = project.id;
  if (id == null || project.eventsLoaded) return;
  final rows = await ProjectApi.activities(id);
  project.events
    ..clear()
    ..addAll([for (final row in rows) _eventFrom(row)]);
  project.eventsLoaded = true;
}

/// 상세에 필요한 것(체크리스트·타임라인)을 한 번에 받는다.
///
/// 이미 받았으면 바로 끝나고, **받는 중이면 그 요청에 얹힌다.**
/// 데스크톱은 빌드마다 여는 콜백이 걸려서 플래그만으로는 첫 응답이 오기 전에
/// 한 번 더 나간다 (실제 발생 — `activities` 가 두 번 찍혔다).
Future<void> _loadDetail(_Project project) {
  if (project.detailLoaded) return Future.value();
  return project.loading ??= Future.wait([
    _loadTodos(project),
    _loadActivities(project),
    // 실패한 요청은 남기지 않는다 — 붙잡아 두면 다시 열어도 영영 못 받는다
  ]).whenComplete(() => project.loading = null);
}

/// 서버 타임라인 한 줄 → 화면 모델
_Event _eventFrom(ProjectActivity row) => _Event(
  // 시스템 기록은 고치거나 지울 수 없어서 id 를 들고 있을 필요가 없다
  id: row.isComment ? row.id : null,
  author: _actorName(row.actorId),
  text: row.body ?? '',
  time: row.createdAt,
  comment: row.isComment,
);

/// 활동을 남긴 사람 — null 이면 서버가 남긴 것이다
String _actorName(String? id) {
  if (id == null) return '시스템';
  final name = _nameOf(id);
  return name.isEmpty ? '알 수 없음' : name;
}

/// 새 프로젝트를 서버에 올린다
///
/// 폼에서 미리 적어 둔 체크리스트도 같이 올린다 — 프로젝트를 먼저 만들어야
/// 붙일 자리(uuid)가 생기므로 순서가 갈린다.
/// 체크리스트가 하나라도 붙으면 서버가 진행률을 다시 계산해 주므로,
/// 만들어진 프로젝트를 마지막에 한 번 더 받아 온다.
Future<_Project> _saveNewProject(_Project draft) async {
  final created = await ProjectApi.create(
    title: draft.name,
    purpose: draft.desc,
    startAt: draft.start,
    due: draft.due,
    assigneeIds: [
      for (final name in draft.members)
        ?StaffDirectory.instance.byName(name)?.id,
    ],
    color: draft.colorHex,
  );

  for (var i = 0; i < draft.todos.length; i++) {
    final todo = draft.todos[i];
    await ProjectApi.addTodo(
      created.id,
      content: todo.text,
      assigneeId: StaffDirectory.instance.byName(todo.assignee ?? '')?.id,
      sort: i,
    );
  }

  final rows = await ProjectApi.list();
  final fresh = rows.where((p) => p.id == created.id).firstOrNull ?? created;
  final project = _fromServer(fresh, null);
  // 방금 적은 것이라 다시 받을 필요가 없다
  await _loadTodos(project);
  // 타임라인은 서버가 '프로젝트를 만들었어요' 한 줄을 이미 쌓아 뒀다
  await _loadActivities(project);
  return project;
}

/// 담당자 이름 → uuid. 서버는 사람을 uuid 로만 받는다
String? _idOfMember(_Project project, String? name) {
  if (name == null || name.isEmpty) return null;
  for (final id in project.memberIds) {
    if (_nameOf(id) == name) return id;
  }
  return StaffDirectory.instance.byName(name)?.id;
}

// ── 표시용 계산 ──

/// 마감까지 남은 일수 (오늘 기준, 지났으면 음수)
int _dday(DateTime due) {
  final now = DateTime.now();
  return DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';

/// '방금 · 12분 전 · 3시간 전 · 7.28' 형태
String _relative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return _date(time);
}

// ── 홈 카드 연결 ──

/// 홈 카드에서 열어달라고 요청한 프로젝트
///
/// 폰은 홈에서 바로 상세를 밀어 올리지만, 데스크톱은 2단 구조라
/// 프로젝트 화면으로 옮긴 뒤 이걸 보고 선택을 맞춘다.
final requestedProject = ValueNotifier<ProjectBrief?>(null);

/// 홈 카드에 내보내는 프로젝트 요약
///
/// 내부 모델(`_Project`)은 이 라이브러리 밖으로 나가지 않는다.
class ProjectBrief {
  ProjectBrief._(this._project);

  final _Project _project;

  String get name => _project.name;

  /// 목록 앞의 세로 막대에 쓰는 프로젝트 색
  Color get color => _project.color;

  /// '나' / '나 외 3명'
  String get members => _project.members.length <= 1
      ? '나'
      : '나 외 ${_project.members.length - 1}명';

  /// 'D-3' · 'D-DAY' · '누락 2일' · '완료'
  String get dday {
    final days = _dday(_project.due);
    return switch (_project.phase) {
      _Phase.done => '완료',
      _Phase.missed => '누락 ${-days}일',
      _Phase.running when days == 0 => 'D-DAY',
      _Phase.running => 'D-$days',
    };
  }

  /// 임박할수록 빨개진다 (목록의 D-day 배지와 같은 기준)
  Color get ddayColor {
    final days = _dday(_project.due);
    return switch (_project.phase) {
      _Phase.done => AppColors.success,
      _Phase.missed => AppColors.error,
      _Phase.running when days <= 2 => AppColors.error,
      _Phase.running when days <= 7 => AppColors.warning,
      _Phase.running => AppColors.primary,
    };
  }

  /// 폰: 상세 화면을 옆에서 밀어 연다
  Future<void> open(BuildContext context) => Navigator.push(
    context,
    CupertinoPageRoute(builder: (_) => _ProjectDetailScreen(project: _project)),
  );
}

/// 홈에서 프로젝트 목록을 채운다
///
/// 홈 카드가 [projectBriefs]·[projectCount] 로 같은 목록을 읽는데, 그건
/// 프로젝트 탭을 한 번 열어야 채워진다. 홈부터 보면 카드가 비어 보인다.
/// 실패해도 홈은 떠야 하므로 조용히 넘긴다 (프로젝트 탭에서 다시 시도한다).
Future<void> loadProjectsIfNeeded() async {
  if (_projectsLoaded) return;
  try {
    await _loadProjects();
  } catch (_) {
    // 서버가 꺼져 있다 — 카드는 비어 있는 채로 남는다
  }
}

/// 홈 카드용 — 진행 중인 프로젝트를 마감 임박순으로 [count]개까지
List<ProjectBrief> projectBriefs(int count) {
  final list = _projects.where((p) => p.phase == _Phase.running).toList()
    ..sort((a, b) => a.due.compareTo(b.due));
  return list.take(count).map(ProjectBrief._).toList();
}
