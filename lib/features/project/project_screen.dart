import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/project/project_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/scroll_box.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/empty_state.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_input_bar.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/feedback/failed_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/input/app_button.dart';
import '../notifications/notification_screen.dart'
    show NotificationTarget, requestedScreen;
import 'package:shared_preferences/shared_preferences.dart';

part 'project_comments.dart';
part 'project_phone.dart';
part 'project_detail.dart';
part 'project_todo.dart';
part 'project_award.dart';
part 'project_activity.dart';
part 'project_dialogs.dart';
part 'project_composer.dart';
part 'project_data.dart';
part 'project_due_modal.dart';

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
    requestedProjectId.addListener(_onRequestId);
    _pendingId = requestedProjectId.value;
    requestedProjectId.value = null;
    _load();
  }

  /// 못 받았다 — **목록이 비어 있을 때만** 실패 카드를 낸다.
  /// 받아 둔 목록이 있으면 그대로 보여준다 (공지와 같은 규칙).
  bool _failed = false;

  Future<void> _load() async {
    try {
      await _loadProjects();
      _failed = false;
    } catch (error) {
      _failed = true;
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
    _openPending();
  }

  /// 알림에서 넘어온 프로젝트 id — 목록을 받은 뒤에 연다
  String? _pendingId;

  void _onRequestId() {
    final id = requestedProjectId.value;
    if (id == null) return;
    requestedProjectId.value = null;
    _pendingId = id;
    _openPending();
  }

  /// 대기 중인 id 를 실제 프로젝트로 바꿔 연다
  ///
  /// **목록을 받기 전에는 아무것도 안 한다** — 알림을 누른 직후에는 아직
  /// 목록이 비어 있어서 못 찾는다. 다 받고 나서 [_load] 가 다시 부른다.
  void _openPending() {
    final id = _pendingId;
    if (id == null || _loading || !mounted) return;
    _pendingId = null;
    final found = _projects.where((p) => p.id == id).firstOrNull;
    // 못 찾으면 목록만 보여준다 — 지워졌거나 내가 못 보는 프로젝트다
    if (found == null) return;
    setState(() {
      _phase = found.phase;
      _selected = found;
    });
    // 폰은 2단이 아니라서 선택만으로는 안 보인다 — 상세를 밀어 올린다
    if (!isDesktop) ProjectBrief._(found).open(context);
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
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
    requestedProjectId.removeListener(_onRequestId);
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
      if (!isDesktop) return _ProjectSkeleton();
      return Scaffold(
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
        // 못 받았고 보여줄 것도 없을 때만 다시 받기를 낸다
        onRetry: _failed && list.isEmpty ? _retry : null,
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
                onRetry: _failed && list.isEmpty ? _retry : null,
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
    required this.onRetry,
    required this.selected,
    required this.phase,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Project> projects;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;
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
                    child: onRetry != null
                        ? FailedCard(onRetry: onRetry!)
                        : EmptyCard(
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
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.folder_rounded,
    title: '프로젝트',
    text: phase == _Phase.running
        ? '왼쪽에서 프로젝트를 골라주세요'
        : '${phase.label} 프로젝트가 아직 없어요',
  );
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

// ── 홈 카드 연결 ──

/// 홈 카드에서 열어달라고 요청한 프로젝트
///
/// 폰은 홈에서 바로 상세를 밀어 올리지만, 데스크톱은 2단 구조라
/// 프로젝트 화면으로 옮긴 뒤 이걸 보고 선택을 맞춘다.
final requestedProject = ValueNotifier<ProjectBrief?>(null);

/// 알림에서 열어달라고 요청한 프로젝트 **id**
///
/// [requestedProject] 와 갈라 둔 이유는 **들고 있는 것이 다르기** 때문이다 —
/// 홈 카드는 이미 프로젝트를 쥐고 있지만, 알림에는 서버 링크의 id 뿐이라
/// 목록을 받아 봐야 어느 것인지 안다. 목록이 늦게 오면 기다렸다 연다.
final requestedProjectId = ValueNotifier<String?>(null);

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
