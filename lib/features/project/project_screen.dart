import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/action_pill.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/pressable.dart';

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
    final created = await _showProjectComposer(context);
    if (created == null || !mounted) return;
    setState(() {
      _projects.add(created);
      // 만든 건 바로 열어준다 (마감이 남아 있으니 진행 중)
      _phase = _Phase.running;
      _selected = created;
    });
    AppToast.show(context, '프로젝트를 만들었어요');
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    if (!isDesktop) {
      return _ProjectPhone(
        projects: list,
        phase: _phase,
        onFilter: (v) => setState(() => _phase = v),
        onCreate: _create,
        onChanged: () => setState(() {}),
      );
    }

    final selected = _syncSelection(list);

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
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: EmptyCard(
                    icon: Icons.folder_rounded,
                    text: '${phase.label} 프로젝트가 없어요',
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
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
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
                  decoration: BoxDecoration(
                    color: phase == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: phase == selected
                          ? AppColors.gray100
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      phase.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: phase == selected
                            ? AppColors.textPrimary
                            : AppColors.gray500,
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

  /// 할 일을 건드릴 때마다 활동 기록을 남긴다
  void _log(String text) {
    project.events.insert(
      0,
      _Event(author: me, text: text, time: DateTime.now()),
    );
  }

  void _toggle(_Todo todo) {
    todo.done = !todo.done;
    _log(todo.done ? "'${todo.text}' 완료" : "'${todo.text}' 완료 취소");
    onChanged();
  }

  void _remove(_Todo todo) {
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
    todo.assignee = picked.isEmpty ? null : picked;
    onChanged();
  }

  void _comment(String text) {
    project.events.insert(
      0,
      _Event(author: me, text: text, time: DateTime.now(), comment: true),
    );
    onChanged();
  }

  /// 기한 연장 신청 — 승인 전까지 마감일은 그대로다
  Future<void> _requestExtension(BuildContext context) async {
    final request = await _showExtensionDialog(context, project);
    if (request == null) return;
    project.request = request;
    _log('기한 연장 신청 (${_date(project.due)} → ${_date(request.due)})');
    onChanged();
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

    if (approve) {
      _log(
        '기한 연장 승인 (${_date(project.due)} → ${_date(request.due)}) · $reason',
      );
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

  bool get _canExtend =>
      project.phase != _Phase.done && project.request == null;

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
    Row(
      children: [
        _MemberBar(project: project, onChanged: onChanged),
        Spacer(),
        if (_canExtend) _extendButton(context),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dday = _dday(project.due);

    return ListView(
      padding: phone
          // 폰 상세는 하단바 위로 올라오는 화면이라 화면 아래 여백만 남긴다
          ? EdgeInsets.fromLTRB(
              20,
              8,
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
          onToggle: _toggle,
          onRemove: _remove,
          onAssign: (todo) => _assign(context, todo),
        ),
        SizedBox(height: 16),
        _ActivityCard(project: project, onComment: _comment),
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
  final ValueChanged<String> onComment;

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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onComment(text);
    _controller.clear();
    // 보낸 뒤에도 계속 쓸 수 있게 포커스를 되돌린다
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.project.events;
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
  return showAppDialog<_Project>(context, (context) => _ProjectComposer());
}

class _ProjectComposer extends StatefulWidget {
  _ProjectComposer();

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
    _nameFocus.requestFocus();
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
        color: _color,
        owner: _owner,
        start: now,
        due: _due,
        // 명단 순서대로 정렬해 두면 아바타 줄이 화면마다 같은 순서로 보인다
        members: [
          for (final staff in staffList)
            if (_members.contains(staff.name)) staff.name,
        ],
        todos: _todos,
        events: [_Event(author: me, text: '프로젝트 생성', time: now)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dday = _dday(_due);

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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
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
                    _Field(
                      controller: _desc,
                      hint: '어떤 프로젝트인가요? (선택)',
                      lines: 2,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 62,
                          child: Text('마감일', style: AppTextStyles.label),
                        ),
                        Pressable(
                          onTap: _pickDue,
                          scale: 0.97,
                          pressedColor: AppColors.gray100,
                          borderRadius: BorderRadius.circular(10),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
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
                        SizedBox(
                          width: 62,
                          child: Text('담당', style: AppTextStyles.label),
                        ),
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
                        SizedBox(
                          width: 62,
                          child: Text('색상', style: AppTextStyles.label),
                        ),
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
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('참여 멤버', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    Wrap(
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
                ),
              ),
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
                      // 이름을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                      color: _name.text.trim().isEmpty
                          ? AppColors.gray200
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '만들기',
                      style: AppTextStyles.body2.copyWith(
                        color: _name.text.trim().isEmpty
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
                  onChanged();
                },
              ),
          ],
        ),
      ),
    ),
  );
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

// ── 데이터 (목업) ──

/// 할 일 한 건
class _Todo {
  _Todo({required this.text, this.assignee, this.done = false});

  String text;
  String? assignee;
  bool done;
}

/// 활동 기록 한 줄 (댓글이면 comment = true)
class _Event {
  _Event({
    required this.author,
    required this.text,
    required this.time,
    this.comment = false,
  });

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
  });

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
    required this.color,
    required this.owner,
    required this.start,
    required this.due,
    required this.members,
    required this.todos,
    required this.events,
    this.request,
  });

  final String name;
  final String desc;
  final Color color;
  final String owner;
  final DateTime start;

  /// 마감일 — 기한 연장이 승인되면 늘어난다
  DateTime due;

  final List<String> members;
  final List<_Todo> todos;
  final List<_Event> events;

  /// 결재를 기다리는 기한 연장 신청 (없으면 null)
  _Extension? request;

  int get doneCount => todos.where((t) => t.done).length;

  double get progress => todos.isEmpty ? 0 : doneCount / todos.length;

  /// 단계는 따로 관리하지 않고 할 일과 마감일에서 끌어낸다.
  /// 할 일을 다 끝내면 완료, 못 끝낸 채 마감이 지나면 누락.
  _Phase get phase {
    if (todos.isNotEmpty && doneCount == todos.length) return _Phase.done;
    if (_dday(due) < 0) return _Phase.missed;
    return _Phase.running;
  }
}

/// 목업 프로젝트. 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _projects = <_Project>[..._seedProjects()];

List<_Project> _seedProjects() {
  final now = DateTime.now();
  DateTime day(int offset) =>
      DateTime(now.year, now.month, now.day + offset, 18);
  DateTime ago(int hours) => now.subtract(Duration(hours: hours));

  return [
    _Project(
      name: '여름 회원 이벤트 프로모션',
      desc: '7~8월 신규 회원 유치를 위한 여름 프로모션. 포스터·SNS·경품까지 한 번에 진행합니다.',
      color: AppColors.error,
      owner: '민중기',
      start: day(-12),
      due: day(2),
      members: [me, '민중기', '이준승', '전상현', '박준현'],
      todos: [
        _Todo(text: '포스터 시안 확정', assignee: '이준승', done: true),
        _Todo(text: '경품 업체 선정', assignee: '박준현', done: true),
        _Todo(text: '인스타 예약 발행', assignee: '전상현'),
        _Todo(text: '현수막 설치', assignee: me),
        _Todo(text: '이벤트 안내 문자 발송', assignee: '민중기'),
      ],
      events: [
        _Event(
          author: '민중기',
          text: '현수막은 정문 쪽으로 걸어주세요',
          time: ago(3),
          comment: true,
        ),
        _Event(author: '박준현', text: "'경품 업체 선정' 완료", time: ago(20)),
        _Event(author: '이준승', text: "'포스터 시안 확정' 완료", time: ago(46)),
      ],
    ),
    _Project(
      name: 'PT룸 장비 교체',
      desc: '노후된 PT룸 소도구와 벤치를 교체합니다. 예산 승인 후 순차 반입.',
      color: AppColors.warning,
      owner: '박준현',
      start: day(-6),
      due: day(5),
      members: [me, '박준현', '유찬빈'],
      todos: [
        _Todo(text: '교체 대상 목록 정리', assignee: '박준현', done: true),
        _Todo(text: '견적 3곳 비교', assignee: '유찬빈', done: true),
        _Todo(text: '예산 결재 올리기', assignee: '박준현'),
        _Todo(text: '기존 장비 처분', assignee: me),
        _Todo(text: '반입 일정 공지', assignee: '유찬빈'),
      ],
      events: [
        _Event(author: '유찬빈', text: "'견적 3곳 비교' 완료", time: ago(30)),
        _Event(
          author: '박준현',
          text: '벤치는 두 대만 먼저 들이는 게 좋겠어요',
          time: ago(52),
          comment: true,
        ),
      ],
    ),
    _Project(
      name: '신규 트레이너 온보딩',
      desc: '신규 입사 트레이너 2명의 교육 과정과 첫 달 스케줄을 준비합니다.',
      color: AppColors.primary,
      owner: '민중기',
      start: day(-3),
      due: day(12),
      members: [me, '민중기', '유찬빈', '전상현'],
      todos: [
        _Todo(text: '교육 자료 최신화', assignee: '민중기', done: true),
        _Todo(text: '멘토 배정', assignee: me),
        _Todo(text: '첫 주 스케줄 편성', assignee: '유찬빈'),
        _Todo(text: '사내 계정 발급 요청', assignee: '전상현'),
      ],
      events: [_Event(author: '민중기', text: "'교육 자료 최신화' 완료", time: ago(8))],
    ),
    _Project(
      name: '가을 시즌 클래스 개편',
      desc: '가을 시즌 GX 클래스 시간표를 개편하고 신규 프로그램을 도입합니다.',
      color: AppColors.primary,
      owner: '유찬빈',
      start: day(-1),
      due: day(16),
      members: [me, '유찬빈'],
      todos: [
        _Todo(text: '회원 선호 시간대 조사', assignee: '유찬빈'),
        _Todo(text: '신규 프로그램 후보 정리', assignee: me),
        _Todo(text: '강사 일정 조율'),
      ],
      events: [],
    ),
    _Project(
      name: '락커룸 리모델링',
      desc: '락커룸 샤워부스와 락커 교체 공사. 공사 기간 중 이용 안내가 필요합니다.',
      color: AppColors.gray500,
      owner: '이준승',
      start: day(2),
      due: day(23),
      members: [me, '이준승', '민중기', '김피스', '박준현', '전상현'],
      todos: [
        _Todo(text: '공사 업체 선정', assignee: '이준승'),
        _Todo(text: '공사 기간 회원 안내문', assignee: '민중기'),
        _Todo(text: '임시 락커 배치도', assignee: me),
      ],
      events: [
        _Event(
          author: '이준승',
          text: '공사는 휴관일 끼고 진행하려 합니다',
          time: ago(70),
          comment: true,
        ),
      ],
    ),
    // 누락 탭 확인용 — 마감이 지났는데 할 일이 남은 프로젝트 (연장 신청이 올라와 있다)
    _Project(
      name: '상반기 시설 안전 점검',
      desc: '소방·전기 설비 정기 점검과 보수. 업체 일정이 밀려 마감을 넘겼습니다.',
      color: AppColors.warning,
      owner: '민중기',
      start: day(-25),
      due: day(-4),
      members: [me, '민중기', '김피스'],
      todos: [
        _Todo(text: '소방 설비 점검', assignee: '민중기', done: true),
        _Todo(text: '전기 안전 진단', assignee: '김피스'),
        _Todo(text: '점검 결과 보고서 제출', assignee: me),
      ],
      events: [_Event(author: '민중기', text: "'소방 설비 점검' 완료", time: ago(120))],
      request: _Extension(
        requester: '민중기',
        due: day(7),
        reason: '전기 진단 업체 일정이 밀려서 다음 주까지 연장이 필요합니다',
        time: ago(5),
      ),
    ),
    // 완료 탭 확인용 — 할 일이 모두 체크된 프로젝트
    _Project(
      name: '상반기 회원권 정책 개편',
      desc: '상반기 회원권 가격과 환불 규정을 정비했습니다.',
      color: AppColors.success,
      owner: '이준승',
      start: day(-40),
      due: day(-6),
      members: [me, '이준승', '민중기'],
      todos: [
        _Todo(text: '경쟁사 가격 조사', assignee: '민중기', done: true),
        _Todo(text: '신규 가격표 확정', assignee: '이준승', done: true),
        _Todo(text: '환불 규정 문구 수정', assignee: me, done: true),
      ],
      events: [_Event(author: '이준승', text: "'신규 가격표 확정' 완료", time: ago(150))],
    ),
  ];
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
