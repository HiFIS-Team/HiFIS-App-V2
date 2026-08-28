part of 'my_task_section.dart';

/// 개인 업무 — **대표·관리자가 보는 판**
///
/// 직원이 보는 화면(`MyTaskSection`)과 완전히 다르다. 그쪽은 자기 할 일을
/// 체크하는 자리고, 여기는 **누가 오늘 다 했는지 훑어보는 자리**다.
///
/// | | 직원·점장 | 대표·관리자 |
/// |---|---|---|
/// | 목록바 | 공통 업무 / 내 업무 | 지점 업무 / 개인 업무 |
/// | 내용 | 내 할 일 체크 | **사람 목록** → 누르면 그 사람 업무 |
/// | `+` | 있다 | **없다** (남의 할 일을 대신 만들지 않는다) |
///
/// 사람 카드는 **동료 평가 목록과 같은 결**이다 (아바타 40 · 이름 · 직급 ·
/// 오른쪽 배지). 같은 화면 안에서 사람을 세우는 자리가 둘로 갈리면 안 된다.
class MyTaskRoster extends StatefulWidget {
  const MyTaskRoster({super.key});

  @override
  State<MyTaskRoster> createState() => _MyTaskRosterState();
}

class _MyTaskRosterState extends State<MyTaskRoster>
    with ScreenRefresh<MyTaskRoster>, SkeletonDelay<MyTaskRoster> {
  List<MyTaskRosterRow> _rows = _cachedRoster;

  @override
  void initState() {
    super.initState();
    // 옛 목록이 있으면 뼈대를 건너뛴다 — 그걸 그린 채로 조용히 다시 받는다
    if (_cachedRoster.isNotEmpty) skipFirstSkeleton();
    _load();
    branchScope.addListener(_onBranch);
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranch);
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다 — **옛 목록을 안 지운다** (지우면 그 사이가 빈 화면)
  void _onBranch() {
    if (!mounted) return;
    setState(beginLoad);
    _load();
  }

  @override
  Future<void> onScreenRefresh() => _load();

  /// 지점원 줄의 누락·사유 표시가 바뀐다
  @override
  List<ValueNotifier<int>> get watchSignals => [approvalChanged];

  Future<void> _load() async {
    try {
      final rows = await MyTaskApi.roster(branchId: branchScopeId);
      if (!mounted) return;
      _cachedRoster = rows;
      setState(() {
        _rows = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  void _open(MyTaskRosterRow row) =>
      showFullPage<void>(context, (_) => _PersonTaskScreen(row: row));

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return const _RosterSkeleton();
    if (_rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: AppDecorations.card(),
        child: Center(
          child: Text(
            '볼 직원이 없어요',
            style: AppTextStyles.body2.copyWith(color: AppColors.gray400),
          ),
        ),
      );
    }

    // 데스크톱은 넓어서 두 줄로 세운다 — 조직도·동료 평가와 같은 규칙
    final columns = isDesktop ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 12),
          if (columns == 1)
            _PersonTaskCard(row: _rows[i], onTap: () => _open(_rows[i]))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(
                    child: i + c < _rows.length
                        ? _PersonTaskCard(
                            row: _rows[i + c],
                            onTap: () => _open(_rows[i + c]),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }
}

/// 사람 한 명 — 동료 평가 목록 카드와 같은 결
class _PersonTaskCard extends StatelessWidget {
  const _PersonTaskCard({required this.row, required this.onTap});

  final MyTaskRosterRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final person = StaffDirectory.instance.byId(row.employeeId);
    // 업무를 안 정한 사람은 회색 — 다 한 것도 못 한 것도 아니다
    final color = row.total == 0
        ? AppColors.gray400
        : row.complete
        ? AppColors.success
        : AppColors.primary;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: row.name, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        person?.rank.label ?? '',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(row: row, color: color),
              ],
            ),
            const SizedBox(height: 14),
            ProgressBar(
              ratio: row.total == 0 ? 0 : row.done / row.total,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// 오른쪽 배지 — `3/5` · 다 하면 `완료` · 안 정했으면 `없음`
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.row, required this.color});

  final MyTaskRosterRow row;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      row.total == 0
          ? '없음'
          : row.complete
          ? '완료'
          : '${row.done}/${row.total}',
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 사람을 누르면 오른쪽에서 밀려 들어오는 화면 — **보기만 한다**
///
/// 체크·수정·삭제 버튼이 없다. 남의 할 일을 대신 체크하면 그 사람이
/// 안 했는데 한 것으로 남는다.
class _PersonTaskScreen extends StatefulWidget {
  const _PersonTaskScreen({required this.row});

  final MyTaskRosterRow row;

  @override
  State<_PersonTaskScreen> createState() => _PersonTaskScreenState();
}

class _PersonTaskScreenState extends State<_PersonTaskScreen>
    with SkeletonDelay<_PersonTaskScreen> {
  MyTaskDay? _day;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final day = await MyTaskApi.day(employeeId: widget.row.employeeId);
      if (!mounted) return;
      setState(() {
        _day = day;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = showSkeleton
        ? const _MyTaskSkeleton()
        : _PersonTaskCardBody(row: widget.row, day: _day);

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: widget.row.name,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            bottomBarInset(context),
          ),
          children: [body],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 18),
            child: Text(widget.row.name, style: AppTextStyles.title3),
          ),
          body,
        ],
      ),
    );
  }
}

/// 그 사람의 오늘 할 일 — 직원 화면과 **같은 줄 모양**이되 안 눌린다
class _PersonTaskCardBody extends StatelessWidget {
  const _PersonTaskCardBody({required this.row, required this.day});

  final MyTaskRosterRow row;
  final MyTaskDay? day;

  @override
  Widget build(BuildContext context) {
    final tasks = day?.tasks ?? const <MyTask>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('오늘 할 일', style: AppTextStyles.label)),
                if (day != null) _DoneBadge(day: day!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 직원 화면과 같은 머리말이라 진행 막대도 같이 둔다
          if (day != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ProgressBar(
                ratio: day!.total == 0 ? 0 : day!.done / day!.total,
                height: 6,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '아직 정한 업무가 없어요',
                  style: AppTextStyles.body2.copyWith(color: AppColors.gray400),
                ),
              ),
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              if (i > 0) const _RowDivider(),
              _ReadOnlyRow(task: tasks[i]),
            ],
        ],
      ),
    );
  }
}

/// 보기 전용 줄 — 직원 화면의 [_TaskRow] 와 같은 모양에서 손잡이만 뺐다
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.task});

  final MyTask task;

  @override
  Widget build(BuildContext context) {
    final checked = task.checked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          _CheckMark(checked: checked),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.content,
              style: AppTextStyles.body2.copyWith(
                color: checked ? AppColors.textTertiary : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                decoration: checked ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textTertiary,
                decorationThickness: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사람 목록 뼈대 — 줄 간격을 실제 카드와 맞춘다
class _RosterSkeleton extends StatelessWidget {
  const _RosterSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          SkeletonCard(
            children: [
              Row(
                children: [
                  Skeleton(width: 40, height: 40, radius: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 66, height: 14),
                      const SizedBox(height: 6),
                      Skeleton(width: 44, height: 11),
                    ],
                  ),
                  const Spacer(),
                  Skeleton(width: 42, height: 24, radius: 10),
                ],
              ),
              const SizedBox(height: 14),
              Skeleton(height: 8, radius: 4),
            ],
          ),
        ],
      ],
    ),
  );
}
