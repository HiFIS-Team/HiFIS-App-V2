import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/period.dart' show periodKey;
import '../../../core/api/work/goal_api.dart';
import '../../../core/data/branch_scope.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart' show myRole;
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/layout.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/display/avatar.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/nav/month_bar.dart';
import '../../../core/widgets/nav/phone_scaffold.dart';

/// 환경정비 목록바의 **내 목표** — 이달의 목표 (2026-09-28 대표 요청)
///
/// MANAGER·MEMBER 는 이번 달 목표를 **2개 이상** 적어 낸다. 내면 글은
/// 잠기고, 이뤘는지만 줄마다 체크한다 (그 달과 다음 달까지). 못 이뤄도
/// 불이익이 없어서 승인 절차는 없다.
///
/// MASTER·ADMIN 은 적지 않고 직원 명단을 본다 — 누르면 그 사람의 목표가
/// 같은 모양(달 이동 · 달성률 · 그래프)으로 밀려 들어온다.
class GoalSection extends StatelessWidget {
  const GoalSection({super.key, this.branchId});

  /// 지점을 바꾸면 명단을 다시 그린다 — 대표·관리자만 쓴다
  final String? branchId;

  @override
  Widget build(BuildContext context) => myRole.doesFieldWork
      ? const _MyGoal()
      : _GoalRoster(key: ValueKey(branchId));
}

DateTime _thisMonth() => DateTime(DateTime.now().year, DateTime.now().month);

DateTime _monthOf(String yearMonth) {
  final [year, month] = [
    for (final part in yearMonth.split('-')) int.parse(part),
  ];
  return DateTime(year, month);
}

String _percent(double rate) => '${(rate * 100).round()}%';

// ── 적는 쪽 ──

class _MyGoal extends StatefulWidget {
  const _MyGoal();

  @override
  State<_MyGoal> createState() => _MyGoalState();
}

class _MyGoalState extends State<_MyGoal> with SkeletonDelay<_MyGoal> {
  /// 이번 달 (`YYYY-MM`) — 서버(KST) 기준
  String? _yearMonth;
  List<MonthlyGoal> _goals = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(beginLoad);
    try {
      final (mine, all) = await (GoalApi.me(), GoalApi.mine()).wait;
      if (!mounted) return;
      setState(() {
        _yearMonth = mine.yearMonth;
        _goals = all;
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

  /// 낸 것·체크한 것을 목록에 갈아끼운다
  void _put(MonthlyGoal goal) => setState(() {
    _goals = [
      goal,
      for (final g in _goals)
        if (g.yearMonth != goal.yearMonth) g,
    ]..sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
  });

  @override
  Widget build(BuildContext context) {
    final yearMonth = _yearMonth;
    if (showSkeleton || yearMonth == null) return const _BoardSkeleton();
    return _GoalBoard(
      goals: _goals,
      current: _monthOf(yearMonth),
      mine: true,
      onChanged: _put,
      form: _GoalForm(yearMonth: yearMonth, onSubmitted: _put),
    );
  }
}

/// 이번 달 목표를 적는 카드 — 아직 안 냈을 때
class _GoalForm extends StatefulWidget {
  const _GoalForm({required this.yearMonth, required this.onSubmitted});

  final String yearMonth;
  final ValueChanged<MonthlyGoal> onSubmitted;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _fields = [TextEditingController(), TextEditingController()];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      field.addListener(_onType);
    }
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _onType() => setState(() {});

  List<String> get _filled => [
    for (final field in _fields)
      if (field.text.trim().isNotEmpty) field.text.trim(),
  ];

  bool get _ready => _filled.length >= GoalApi.minItems;

  void _add() {
    if (_fields.length >= GoalApi.maxItems) return;
    setState(() => _fields.add(TextEditingController()..addListener(_onType)));
  }

  void _remove(int i) {
    final field = _fields.removeAt(i);
    field.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    final ok = await showConfirmDialog(
      context,
      icon: Icons.flag_rounded,
      title: '목표를 낼까요?',
      message: '내면 이번 달에는 목표를 고칠 수 없어요.\n이룬 것은 나중에 체크할 수 있어요',
      confirmLabel: '내기',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final goal = await GoalApi.submit(_filled);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSubmitted(goal);
      AppToast.show(context, '이번 달 목표를 냈어요');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthOf(widget.yearMonth).month;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$month월 목표를 적어 주세요', style: AppTextStyles.title3),
          const SizedBox(height: 6),
          Text(
            '이번 달에 이루고 싶은 것을 ${GoalApi.minItems}개 이상 적어요.\n'
            '내면 이번 달에는 고칠 수 없어요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _GoalField(
              index: i,
              controller: _fields[i],
              hint: i == 0
                  ? '예) 신규 매출 300만원 올리기'
                  : i == 1
                  ? '예) 생활스포츠지도사 자격증 따기'
                  : '목표를 적어 주세요',
              onRemove: i < GoalApi.minItems ? null : () => _remove(i),
            ),
          ],
          if (_fields.length < GoalApi.maxItems) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: _add,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '+ 목표 추가',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: _ready
                ? '목표 내기'
                : '${GoalApi.minItems - _filled.length}개 더 적어 주세요',
            filled: _ready,
            busy: _busy,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

/// 목표 한 줄 입력칸 — 번호 · 글 · (세 번째부터) 지우기
class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.index,
    required this.controller,
    required this.hint,
    this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Number(index + 1),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.body2,
              cursorColor: AppColors.primary,
              minLines: 1,
              maxLines: 3,
              maxLength: GoalApi.maxLength,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                counterText: '',
              ),
            ),
          ),
          if (onRemove case final remove?)
            Pressable(
              onTap: remove,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.gray400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 한 사람의 목표판 — 본인과 대표 상세가 같이 쓴다 ──

/// `‹ 2026년 9월 ›` · 달성률 · 목표 줄 · 최근 6개월 그래프
class _GoalBoard extends StatefulWidget {
  const _GoalBoard({
    required this.goals,
    required this.current,
    required this.mine,
    this.onChanged,
    this.form,
  });

  /// 그 사람이 낸 목표 전부
  final List<MonthlyGoal> goals;

  /// 이번 달 — 이보다 뒤로는 못 넘긴다
  final DateTime current;

  /// 본인 것인가 — 본인만 체크한다
  final bool mine;
  final ValueChanged<MonthlyGoal>? onChanged;

  /// 이번 달 목표가 없을 때 그 자리에 세울 카드 (본인만)
  final Widget? form;

  @override
  State<_GoalBoard> createState() => _GoalBoardState();
}

class _GoalBoardState extends State<_GoalBoard> {
  late DateTime _month = widget.current;

  /// 체크를 보내는 중인 줄 — 연달아 누르면 순서가 엉킨다
  final _busy = <int>{};

  MonthlyGoal? _goalOf(DateTime month) {
    final key = periodKey(month);
    for (final goal in widget.goals) {
      if (goal.yearMonth == key) return goal;
    }
    return null;
  }

  /// 체크할 수 있나 — 본인 · 그 달과 다음 달까지 (서버 `can_check` 와 같다)
  bool get _checkable {
    if (!widget.mine) return false;
    final last = DateTime(widget.current.year, widget.current.month - 1);
    return _month == widget.current || _month == last;
  }

  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _toggle(MonthlyGoal goal, int index) async {
    if (_busy.contains(index)) return;
    final done = !goal.achieved.contains(index);
    final next = {...goal.achieved};
    done ? next.add(index) : next.remove(index);
    // 누르는 순간 바꾼다 — 실패하면 되돌린다
    widget.onChanged?.call(goal.copyWith(achieved: next));
    setState(() => _busy.add(index));
    try {
      final saved = await GoalApi.check(goal.yearMonth, index, done: done);
      widget.onChanged?.call(saved);
    } catch (e) {
      widget.onChanged?.call(goal);
      if (mounted) AppToast.show(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goalOf(_month);
    final atCurrent = _month == widget.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthBar(
          month: _month,
          count: 0,
          loading: false,
          showCount: false,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          onPrev: () => _move(-1),
          onNext: atCurrent ? null : () => _move(1),
        ),
        if (goal != null) ...[
          _RateCard(goal: goal),
          const SizedBox(height: 12),
          _ItemsCard(
            goal: goal,
            checkable: _checkable,
            onToggle: (i) => _toggle(goal, i),
          ),
        ] else if (atCurrent && widget.form != null)
          widget.form!
        else
          EmptyCard(
            icon: Icons.flag_rounded,
            text: atCurrent ? '이번 달 목표를 아직 안 적었어요' : '이 달에는 목표가 없어요',
          ),
        const SizedBox(height: 12),
        _TrendCard(
          goals: widget.goals,
          current: widget.current,
          selected: _month,
          onSelect: (month) => setState(() => _month = month),
        ),
      ],
    );
  }
}

/// 그 달 달성률 — 큰 숫자 + 막대
class _RateCard extends StatelessWidget {
  const _RateCard({required this.goal});

  final MonthlyGoal goal;

  @override
  Widget build(BuildContext context) {
    final at = goal.createdAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('달성률', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _percent(goal.rate),
                style: AppTextStyles.title1.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                '${goal.items.length}개 중 ${goal.achieved.length}개 이뤘어요',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(ratio: goal.rate),
          const SizedBox(height: 10),
          Text(
            '${at.month}월 ${at.day}일에 냈어요',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 목표 줄들 — 이룬 것은 체크 · 본인은 눌러서 바꾼다
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.goal,
    required this.checkable,
    required this.onToggle,
  });

  final MonthlyGoal goal;
  final bool checkable;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('목표', style: AppTextStyles.label)),
              if (checkable)
                Text(
                  '이룬 목표를 눌러 체크해요',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < goal.items.length; i++)
            _ItemRow(
              text: goal.items[i],
              done: goal.achieved.contains(i),
              onTap: checkable ? () => onToggle(i) : null,
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.text, required this.done, this.onTap});

  final String text;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: done ? AppColors.primary : AppColors.gray300,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body2.copyWith(
                height: 1.5,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap!, child: row);
  }
}

/// 최근 6개월 달성률 막대 — 급여 추이 그래프와 같은 틀. 누르면 그 달로 간다
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.goals,
    required this.current,
    required this.selected,
    required this.onSelect,
  });

  final List<MonthlyGoal> goals;
  final DateTime current;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final byMonth = {for (final g in goals) g.yearMonth: g};
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(current.year, current.month - i),
    ];
    final written = [for (final m in months) ?byMonth[periodKey(m)]];
    final average = written.isEmpty
        ? null
        : written.fold(0.0, (sum, g) => sum + g.rate) / written.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('최근 6개월', style: AppTextStyles.label)),
              if (average != null)
                Text(
                  '평균 ${_percent(average)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            // 수치(15) + 6 + 막대(최대 78) + 8 + 월(15)
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(
                    child: Pressable(
                      onTap: () => onSelect(m),
                      child: _Bar(
                        month: m,
                        goal: byMonth[periodKey(m)],
                        selected: m == selected,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.month, required this.goal, required this.selected});

  final DateTime month;

  /// 그 달에 목표를 안 냈으면 null — 막대 없이 `-`
  final MonthlyGoal? goal;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          goal == null ? '-' : _percent(goal.rate),
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            // 100% 를 78 로 둔다 — 0% 도 바닥에 얇게 보이게 6 을 깐다
            height: goal == null ? 4 : 6 + 72 * goal.rate,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.gray100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${month.month}월',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: SkeletonRows(rows: 3, avatar: 0, trailing: 0),
    );
  }
}

// ── 대표·관리자 ──

class _GoalRoster extends StatefulWidget {
  const _GoalRoster({super.key});

  @override
  State<_GoalRoster> createState() => _GoalRosterState();
}

class _GoalRosterState extends State<_GoalRoster>
    with SkeletonDelay<_GoalRoster> {
  DateTime _month = _thisMonth();
  Map<String, MonthlyGoal> _goals = const {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(beginLoad);
    final month = _month;
    try {
      final goals = await GoalApi.list(periodKey(month));
      if (!mounted || month != _month) return;
      setState(() {
        _goals = {for (final g in goals) g.employeeId: g};
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _fetch();
  }

  Future<void> _open(Employee employee) => showFullPage<void>(
    context,
    (context) => PhoneDetailScaffold(
      title: '${employee.name} 목표',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [_EmployeeGoals(employee: employee)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final directory = StaffDirectory.instance;
    final branch = rosterBranchId;
    final staff = [
      for (final e in directory.employees)
        if ((e.role == Role.manager || e.role == Role.member) &&
            e.status == EmployeeStatus.active &&
            (branch == null || e.branchId == branch))
          e,
    ]..sort(directory.compareStaff);
    final written = staff.where((e) => _goals.containsKey(e.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthBar(
          month: _month,
          count: written,
          unit: '명',
          loading: showSkeleton,
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 10),
          onPrev: () => _move(-1),
          onNext: _month == _thisMonth() ? null : () => _move(1),
        ),
        if (showSkeleton)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.card(),
            child: SkeletonRows(rows: 4),
          )
        else if (staff.isEmpty)
          EmptyCard(icon: Icons.flag_rounded, text: '목표를 적을 직원이 없어요')
        else
          for (var i = 0; i < staff.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _PersonCard(
              employee: staff[i],
              goal: _goals[staff[i].id],
              onTap: () => _open(staff[i]),
            ),
          ],
      ],
    );
  }
}

/// 명단 한 줄 — 이름 · 직급 · 그 달 달성
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.employee,
    required this.goal,
    required this.onTap,
  });

  final Employee employee;
  final MonthlyGoal? goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final directory = StaffDirectory.instance;
    final branch = directory.branchName(employee.branchId);
    final subtitle = rosterBranchId == null && branch.isNotEmpty
        ? '${employee.rank.label} · $branch'
        : employee.rank.label;
    final goal = this.goal;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Avatar(name: employee.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              goal == null
                  ? '아직 안 적었어요'
                  : '${goal.achieved.length}/${goal.items.length} 달성',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: goal == null
                    ? AppColors.textTertiary
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

/// 대표가 직원을 눌렀을 때 — 그 사람의 목표판 (읽기만)
class _EmployeeGoals extends StatefulWidget {
  const _EmployeeGoals({required this.employee});

  final Employee employee;

  @override
  State<_EmployeeGoals> createState() => _EmployeeGoalsState();
}

class _EmployeeGoalsState extends State<_EmployeeGoals>
    with SkeletonDelay<_EmployeeGoals> {
  List<MonthlyGoal> _goals = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(beginLoad);
    try {
      final goals = await GoalApi.ofEmployee(widget.employee.id);
      if (!mounted) return;
      setState(() {
        _goals = goals;
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return const _BoardSkeleton();
    return _GoalBoard(goals: _goals, current: _thisMonth(), mine: false);
  }
}
