part of 'project_screen.dart';

// ── 폰 화면 ──

/// 폰: 단계 탭 + 프로젝트 카드 목록.
/// 카드를 누르면 상세가 옆에서 밀려 들어온다 (2단 대신 두 화면으로 나눈다).
class _ProjectPhone extends StatelessWidget {
  _ProjectPhone({
    required this.projects,
    required this.phase,
    required this.onFilter,
    required this.onCreate,
    required this.onChanged,
  });

  final List<_Project> projects;
  final _Phase phase;
  final ValueChanged<_Phase> onFilter;
  final VoidCallback onCreate;

  /// 상세에서 바꾼 내용이 목록에도 반영되도록 돌아올 때 알린다
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context, _Project project) async {
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
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '프로젝트',
      // 연장 신청은 자주 쓰는 동작이 아니라 본문 대신 상단 글래스 버튼에 둔다
      actions: [
        if (_canExtendProject(widget.project))
          GlassIconButton(
            symbol: 'calendar.badge.plus',
            onPressed: () =>
                _extendProject(context, widget.project, () => setState(() {})),
          ),
      ],
      child: _ProjectDetail(
        project: widget.project,
        onChanged: () => setState(() {}),
        phone: true,
      ),
    );
  }
}
