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
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/display/avatar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/nav/month_bar.dart';

/// 업무 탭의 **목표** — 이달의 목표 (2026-09-28 대표 요청)
///
/// MANAGER·MEMBER 는 이번 달 목표를 **2개 이상** 적어 낸다. 내면 그 달은
/// 잠긴다 — 못 이뤄도 불이익이 없어서 승인 절차는 없다.
/// MASTER·ADMIN 은 적지 않고 직원별로 모아 본다 (같은 지점 점장에게도 안 연다).
class GoalSection extends StatelessWidget {
  const GoalSection({super.key, this.branchId});

  /// 지점을 바꾸면 명단을 다시 그린다 — 대표·관리자만 쓴다
  final String? branchId;

  @override
  Widget build(BuildContext context) => myRole.doesFieldWork
      ? const _MyGoal()
      : _GoalRoster(key: ValueKey(branchId));
}

// ── 적는 쪽 ──

class _MyGoal extends StatefulWidget {
  const _MyGoal();

  @override
  State<_MyGoal> createState() => _MyGoalState();
}

class _MyGoalState extends State<_MyGoal> with SkeletonDelay<_MyGoal> {
  MyGoal? _mine;

  /// 지난 달까지 낸 목표 — 이번 달 카드 아래에 쌓인다
  List<MonthlyGoal> _past = const [];
  final _fields = [TextEditingController(), TextEditingController()];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      field.addListener(_onType);
    }
    _fetch();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _onType() => setState(() {});

  Future<void> _fetch() async {
    setState(beginLoad);
    try {
      final (mine, all) = await (GoalApi.me(), GoalApi.mine()).wait;
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _past = [
          for (final goal in all)
            if (goal.yearMonth != mine.yearMonth) goal,
        ];
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

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
      message: '내면 이번 달에는 고칠 수 없어요',
      confirmLabel: '내기',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final goal = await GoalApi.submit(_filled);
      if (!mounted) return;
      setState(() {
        _mine = MyGoal(
          yearMonth: goal.yearMonth,
          writes: true,
          due: false,
          goal: goal,
        );
        _busy = false;
      });
      AppToast.show(context, '이번 달 목표를 냈어요');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    if (showSkeleton || mine == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: SkeletonRows(rows: 3, avatar: 0, trailing: 0),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mine.goal case final goal?)
          _Submitted(goal: goal, current: true)
        else
          _form(mine),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '지난 목표',
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (_past.isEmpty)
          EmptyCard(icon: Icons.flag_rounded, text: '지난 달 목표가 여기에 쌓여요')
        else
          for (var i = 0; i < _past.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _Submitted(goal: _past[i], current: false),
          ],
      ],
    );
  }

  /// 이번 달 목표를 적는 카드 — 아직 안 냈을 때
  Widget _form(MyGoal mine) {
    final month = int.parse(mine.yearMonth.split('-').last);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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

/// 낸 목표 — 잠겨 있다
class _Submitted extends StatelessWidget {
  const _Submitted({required this.goal, required this.current});

  final MonthlyGoal goal;

  /// 이번 달 것인가 — '고칠 수 없어요' 는 이번 달에만 붙인다
  final bool current;

  @override
  Widget build(BuildContext context) {
    final at = goal.createdAt;
    final [year, month] = [
      for (final part in goal.yearMonth.split('-')) int.parse(part),
    ];
    // 올해가 아니면 해를 같이 적는다 — 12월과 다음 해 1월이 나란히 선다
    final title = year == DateTime.now().year
        ? '$month월 목표'
        : '$year년 $month월 목표';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.title3),
          const SizedBox(height: 4),
          Text(
            current
                ? '${at.month}월 ${at.day}일에 냈어요 · 이번 달은 고칠 수 없어요'
                : '${at.month}월 ${at.day}일에 냈어요',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          _GoalLines(items: goal.items),
        ],
      ),
    );
  }
}

/// 번호 붙은 목표 줄들 — 내 목표와 대표 화면이 같이 쓴다
class _GoalLines extends StatelessWidget {
  const _GoalLines({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Number(i + 1),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  items[i],
                  style: AppTextStyles.body2.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ],
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

// ── 대표·관리자 ──

class _GoalRoster extends StatefulWidget {
  const _GoalRoster({super.key});

  @override
  State<_GoalRoster> createState() => _GoalRosterState();
}

class _GoalRosterState extends State<_GoalRoster>
    with SkeletonDelay<_GoalRoster> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
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
          onNext: () => _move(1),
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
            _PersonGoal(employee: staff[i], goal: _goals[staff[i].id]),
          ],
      ],
    );
  }
}

class _PersonGoal extends StatelessWidget {
  const _PersonGoal({required this.employee, this.goal});

  final Employee employee;
  final MonthlyGoal? goal;

  @override
  Widget build(BuildContext context) {
    final directory = StaffDirectory.instance;
    final branch = directory.branchName(employee.branchId);
    final subtitle = rosterBranchId == null && branch.isNotEmpty
        ? '${employee.rank.label} · $branch'
        : employee.rank.label;
    final goal = this.goal;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(name: employee.name, size: 36),
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
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                goal == null ? '아직 안 적었어요' : '${goal.items.length}개',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: goal == null
                      ? AppColors.textTertiary
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          if (goal != null) ...[
            const SizedBox(height: 14),
            _GoalLines(items: goal.items),
          ],
        ],
      ),
    );
  }
}
