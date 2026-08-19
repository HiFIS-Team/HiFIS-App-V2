part of 'project_screen.dart';

// ── 폰 화면 ──

/// 폰: 단계 탭 + 프로젝트 카드 목록.
/// 카드를 누르면 상세가 옆에서 밀려 들어온다 (2단 대신 두 화면으로 나눈다).
class _ProjectPhone extends StatelessWidget {
  _ProjectPhone({
    required this.projects,
    required this.onRetry,
    required this.phase,
    required this.onFilter,
    required this.onCreate,
    required this.onChanged,
    required this.onOpen,
  });

  final List<_Project> projects;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;
  final _Phase phase;
  final ValueChanged<_Phase> onFilter;
  final VoidCallback onCreate;

  /// 상세에서 바꾼 내용이 목록에도 반영되도록 돌아올 때 알린다
  final VoidCallback onChanged;

  /// 상세를 열기 전에 체크리스트를 받아 온다
  final Future<void> Function(_Project) onOpen;

  Future<void> _open(BuildContext context, _Project project) async {
    // **받아 둔 것이 있으면 기다리지 않는다.** 들고 있는 줄을 그대로 띄우고,
    // 새 값은 상세 화면이 받아서 오는 대로 갈아끼운다
    // (`_ProjectDetailScreenState._load`). 기다리면 눌렀는데 화면이 잠깐
    // 멈춘 것처럼 보인다 — 두 번째로 여는 것부터는 보여줄 것이 이미 있다
    if (project.todos.isEmpty && project.events.isEmpty) {
      await onOpen(project);
      if (!context.mounted) return;
    }
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _ProjectDetailScreen(project: project),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PhoneListScaffold(
      title: '프로젝트',
      count: projects.length,
      filter: _PhaseTabs(selected: phase, onSelect: onFilter),
      onCreate: onCreate,
      children: [
        if (projects.isEmpty)
          if (onRetry case final retry?)
            FailedCard(onRetry: retry)
          else
            EmptyCard(
              icon: Icons.folder_rounded,
              text: '${phase.label} 프로젝트가 없어요',
            )
        else
          for (var i = 0; i < projects.length; i++) ...[
            if (i > 0) SizedBox(height: 12),
            _ProjectCard(
              project: projects[i],
              onTap: () => _open(context, projects[i]),
            ),
          ],
      ],
    );
  }
}

/// 폰 목록 카드 — 이름·D-day·설명·진행률·참여자
class _ProjectCard extends StatelessWidget {
  _ProjectCard({required this.project, required this.onTap});

  final _Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dday = _dday(project.due);
    final done = project.phase == _Phase.done;

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
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (project.request case final request?) ...[
                  SizedBox(width: 6),
                  _RequestChip(type: request.type),
                ],
                SizedBox(width: 8),
                _DdayBadge(dday: dday, phase: project.phase),
              ],
            ),
            if (project.desc.isNotEmpty) ...[
              SizedBox(height: 6),
              Text(
                project.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ProgressBar(
                    value: project.progress,
                    color: project.color,
                    height: 6,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '${(project.progress * 100).round()}%',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: done ? AppColors.success : project.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                AvatarStack(names: project.members, size: 22),
                Spacer(),
                // 결재를 기다리는 연장 신청이 있으면 목록에서도 바로 보이게 한다
                if (project.request != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '연장 대기',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Text(
                  '할 일 ${project.doneCount}/${project.todos.length}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 폰 상세 화면 — 목록에서 밀려 들어온다
class _ProjectDetailScreen extends StatefulWidget {
  _ProjectDetailScreen({required this.project});

  final _Project project;

  @override
  State<_ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<_ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 홈 카드에서 열면 목록을 안 거치므로 여기서도 받아 둔다.
  /// 목록에서 들어온 거라면 이미 받아 놔서 둘 다 바로 빠져나온다.
  Future<void> _load() async {
    try {
      await _loadDetail(widget.project);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '프로젝트',
      // 자주 쓰는 동작은 본문 대신 상단 글래스 버튼에 둔다.
      // 수정·인원 추가는 **담당자·참여 멤버와 대표**에게만 뜬다 (2026-08-19) —
      // PC 머리말의 글자 버튼과 같은 조건이라 어느 쪽에서 봐도 같다
      actions: [
        if (_canExtendProject(widget.project))
          GlassIconButton(
            symbol: 'calendar.badge.plus',
            onPressed: () =>
                _extendProject(context, widget.project, () => setState(() {})),
          ),
        if (_canTouchProject(widget.project)) ...[
          GlassIconButton(
            symbol: 'square.and.pencil',
            onPressed: () => _projectActions(
              widget.project,
              () => setState(() {}),
            )._requestEdit(context),
          ),
          GlassIconButton(
            symbol: 'person.badge.plus',
            onPressed: () => _projectActions(
              widget.project,
              () => setState(() {}),
            )._requestMembers(context),
          ),
        ],
      ],
      child: _ProjectDetail(
        project: widget.project,
        onChanged: () => setState(() {}),
        phone: true,
      ),
    );
  }
}

/// 받아오는 동안의 뼈대 — 목록 카드 자리를 미리 잡아 둔다
///
/// 카드 안 구성이 진짜 카드와 같다 (색 점과 이름 · D-day · 설명 ·
/// 진행률 막대 · 참여자와 할 일 수).
class _ProjectSkeleton extends StatelessWidget {
  _ProjectSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: PhoneListScaffold(
      title: '프로젝트',
      // _PhaseTabs 와 같은 높이(44) — 다 받아왔을 때 목록이 안 밀린다
      filter: Skeleton(height: 44, radius: 14),
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) SizedBox(height: 12),
          SkeletonCard(
            children: [
              Row(
                children: [
                  SkeletonCircle(size: 8),
                  SizedBox(width: 8),
                  Skeleton(width: 140, height: 15),
                  Spacer(),
                  Skeleton(width: 44, height: 20, radius: 10),
                ],
              ),
              SizedBox(height: 10),
              Skeleton(width: 190, height: 11),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Skeleton(height: 6, radius: 3)),
                  SizedBox(width: 10),
                  Skeleton(width: 30, height: 11),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  SkeletonCircle(size: 22),
                  Spacer(),
                  Skeleton(width: 62, height: 11),
                ],
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
