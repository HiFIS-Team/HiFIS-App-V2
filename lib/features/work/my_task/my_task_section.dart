import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/my_task_api.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/display/avatar.dart';
import '../../../core/util/layout.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/data/branch_scope.dart';
import '../../../core/data/current_user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/util/screen_refresh.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/weekday_picker.dart';
import '../../../core/widgets/nav/phone_scaffold.dart';

part 'my_task_forms.dart';
part 'my_task_roster.dart';

/// 마지막으로 받아 둔 하루치 — **화면 밖에 둔다**
///
/// `공통 업무 ↔ 내 업무` 칸을 옮기면 이 화면이 통째로 새로 만들어져서,
/// 화면 안에만 들고 있으면 들어올 때마다 `initState → 뼈대` 가 번쩍인다.
/// 옛 목록을 여기 두고 **그걸 그린 채로 조용히 다시 받는다**
/// (claude.md 의 `뼈대를 그리는 동안 옛 내용을 지우지 않는다`).
///
/// 세션 안에서만 산다 — 로그아웃하면 [resetMyTaskCache].
MyTaskDay? _cached;

/// 대표·관리자가 보던 사람 목록 — 같은 이유로 화면 밖에 둔다
List<MyTaskRosterRow> _cachedRoster = const [];

/// 로그아웃할 때 비운다 — 다음 사람에게 앞사람 할 일이 보이면 안 된다
void resetMyTaskCache() {
  _cached = null;
  _cachedRoster = const [];
}

/// 내 업무 추가 — **업무 화면 머리말의 `+` 가 부른다**
///
/// 카드 안이 아니라 밖에서 부르는 이유: 추가 버튼이 환경정비 머리말로
/// 올라갔다 (2026-08-14). 만들었으면 true — 부른 쪽이 목록을 다시 받는다.
Future<bool> addMyTasks(BuildContext context) async {
  // 폰은 오른쪽에서 밀려 들어오고, 데스크톱은 가운데 모달이다
  // (프로젝트 만들기·내역 전체보기와 같은 `showFullPage`)
  // 업무 이름 → 걸리는 요일. 요일을 하나씩 훑으며 채운 결과다
  final plan = await showFullPage<Map<String, List<int>>>(
    context,
    (_) => const _AddTaskScreen(),
  );
  if (plan == null || plan.isEmpty || !context.mounted) return false;
  try {
    // 여러 줄을 **한 번에** 보낸다 — 줄마다 부르면 중간에 끊겼을 때
    // 반만 들어간 채로 화면이 닫힌다
    await MyTaskApi.create(plan);
    if (context.mounted) {
      AppToast.show(
        context,
        plan.length == 1 ? '업무를 추가했어요' : '업무 ${plan.length}개를 추가했어요',
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) AppToast.show(context, messageOf(error));
    return false;
  }
}

/// 내 업무 — 하루에 한 번씩 체크하는 개인 업무 목록
///
/// 공통 업무(환경정비 칩)와 **도는 방식이 다르다.**
///
/// | | 하루에 |
/// |---|---|
/// | 공통 업무 | 여러 번 — 할 때마다 횟수가 는다 |
/// | 내 업무 | **한 번씩 체크** — 다 하면 완료, 남으면 누락 |
///
/// 추가는 본인이 바로 하고, **수정·삭제는 대표 결재**를 받는다.
/// 결재를 기다리는 동안에는 그 줄을 손댈 수 없다.
class MyTaskSection extends StatefulWidget {
  const MyTaskSection({super.key, this.reloadToken = 0});

  /// 밖에서 업무를 추가하면 이 값이 오른다 — 그때 목록을 다시 받는다
  /// (추가 버튼이 머리말로 올라가서 카드 밖에 있다)
  final int reloadToken;

  @override
  State<MyTaskSection> createState() => _MyTaskSectionState();
}

class _MyTaskSectionState extends State<MyTaskSection>
    with ScreenRefresh<MyTaskSection>, SkeletonDelay<MyTaskSection> {
  /// 옛 목록으로 시작한다 — 처음 들어올 때만 비어 있다
  MyTaskDay? _day = _cached;

  /// 서버에 보내는 중인 줄 — 답이 오기 전에 또 누르면 두 번 나간다
  final _busy = <String>{};

  /// 보고 있는 요일 (ISO 1=월 … 7=일) — **기본은 오늘**
  ///
  /// 업무마다 도는 요일이 달라져서(2026-08-20), 오늘 것만 보면 **다른 요일에
  /// 뭘 넣어 뒀는지 알 길이 없다.** 줄 오른쪽에 `월·수·금` 을 적는 대신
  /// 요일을 골라 그날 목록을 본다.
  int _viewDay = DateTime.now().weekday;

  bool get _isToday => _viewDay == DateTime.now().weekday;

  /// 보고 있는 요일의 **이번 주 날짜** — 서버에 넘길 값
  DateTime get _viewDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + (_viewDay - now.weekday));
  }

  static const _dayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    // 보여줄 옛 목록이 있으면 뼈대를 건너뛴다 — 그게 곧 깜빡임이다
    if (_cached != null) skipFirstSkeleton();
    _load();
  }

  @override
  void didUpdateWidget(MyTaskSection old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _load();
  }

  @override
  Future<void> onScreenRefresh() => _load();

  Future<void> _load() async {
    try {
      final day = await MyTaskApi.day(
        // 오늘은 날짜를 안 넘긴다 — 서버가 오늘로 본다 (자정을 넘겨도 맞다)
        date: _isToday ? null : dateKey(_viewDate),
      );
      if (!mounted) return;
      // **옛 목록을 안 지운다** — 지우면 그 사이가 빈 화면이라 깜빡인다.
      // 캐시는 오늘 것만 — 다른 요일을 보다 나갔다 오면 오늘로 돌아온다
      if (_isToday) _cached = day;
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

  /// 요일을 옮긴다 — 옛 목록을 둔 채로 새 값을 받는다 (`SkeletonDelay`)
  void _pickDay(int day) {
    if (day == _viewDay) return;
    setState(() {
      _viewDay = day;
      beginLoad();
    });
    _load();
  }

  /// 체크 — **되돌릴 수 없어서 한 번 묻는다** (2026-08-20 요청)
  ///
  /// 체크하는 순간 그 업무는 수정·삭제가 결재를 타게 된다. 해제하는 길이
  /// 없으므로 잘못 누르면 되돌릴 방법이 없다.
  Future<void> _check(MyTask task) async {
    if (task.checked || _busy.contains(task.id)) return;
    final ok = await showConfirmDialog(
      context,
      title: '완료하시겠어요?',
      // 결재를 받게 된다는 말은 **처음 체크할 때만** 한다 (2026-08-20 요청).
      // 이미 한 번 한 업무는 그때부터 줄곧 결재를 타고 있어서, 매일 다시
      // 알리면 아는 이야기를 반복하는 것이 된다
      message: task.everChecked
          ? '한 번 체크하면 되돌릴 수 없어요.'
          : '한 번 체크하면 되돌릴 수 없어요.\n그 뒤로는 고치거나 지울 때 대표님 승인이 필요해요.',
      confirmLabel: '완료',
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(task.id));
    try {
      await MyTaskApi.check(task.id);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _busy.remove(task.id));
  }

  /// 수정·삭제 — **체크한 적이 있으면 결재, 없으면 바로** (2026-08-20 요청)
  ///
  /// 아직 아무 기록이 없는 업무는 잘못 적은 것을 고치는 것뿐이라 막을
  /// 이유가 없다. 한 번이라도 한 업무는 '한 일을 없던 일로 만드는' 길이
  /// 되므로 그때부터 결재를 받는다 (프로젝트 할 일과 같은 규칙).
  Future<void> _change(MyTask task, MyTaskRequestType type) {
    if (task.everChecked) return _request(task, type);
    return type == MyTaskRequestType.delete ? _removeNow(task) : _editNow(task);
  }

  /// 결재 없이 바로 고친다 — 사유를 안 묻는다
  Future<void> _editNow(MyTask task) async {
    final result = await showAppDialog<_RequestResult>(
      context,
      (_) => _RequestCard(
        task: task,
        type: MyTaskRequestType.edit,
        approval: false,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await MyTaskApi.update(
        task.id,
        content: result.content,
        weekdays: result.weekdays,
      );
      await _load();
      if (mounted) AppToast.show(context, '업무를 고쳤어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 결재 없이 바로 지운다 — 되돌릴 수 없어서 한 번 묻는다
  Future<void> _removeNow(MyTask task) async {
    final ok = await showConfirmDialog(
      context,
      title: '업무를 지울까요?',
      message: '${task.content}\n아직 한 번도 안 한 업무라 바로 지워져요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await MyTaskApi.remove(task.id);
      await _load();
      if (mounted) AppToast.show(context, '업무를 지웠어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _request(MyTask task, MyTaskRequestType type) async {
    final result = await showAppDialog<_RequestResult>(
      context,
      (_) => _RequestCard(task: task, type: type),
    );
    if (result == null || !mounted) return;
    try {
      await MyTaskApi.request(
        task.id,
        type: type,
        reason: result.reason,
        content: result.content,
        weekdays: result.weekdays,
      );
      await _load();
      if (mounted) AppToast.show(context, '${type.label} 결재를 올렸어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return const _MyTaskSkeleton();
    final day = _day;
    if (day == null) return const SizedBox();

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
                Expanded(
                  child: Text(
                    _isToday ? '오늘 할 일' : '${_dayNames[_viewDay - 1]}요일 할 일',
                    style: AppTextStyles.label,
                  ),
                ),
                _DoneBadge(day: day),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 요일 줄 — 눌러서 그날 목록을 본다
          _DayTabs(selected: _viewDay, onSelect: _pickDay),
          const SizedBox(height: 12),
          if (day.tasks.isEmpty)
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
            for (var i = 0; i < day.tasks.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _TaskRow(
                task: day.tasks[i],
                // **오늘이 아니면 못 체크한다.** 서버는 체크를 늘 오늘로 찍어서
                // (`check_my_task` 가 `_today()`), 다른 요일을 보다 누르면
                // 엉뚱한 날에 찍힌다
                busy: _busy.contains(day.tasks[i].id) || !_isToday,
                onCheck: () => _check(day.tasks[i]),
                onEdit: () => _change(day.tasks[i], MyTaskRequestType.edit),
                onDelete: () => _change(day.tasks[i], MyTaskRequestType.delete),
              ),
            ],
        ],
      ),
    );
  }
}

/// 요일 줄 — 누르면 그날 목록으로 갈린다 (2026-08-20 요청)
///
/// 업무마다 도는 요일이 달라지면서 **오늘 것만 보면 다른 요일에 뭘 넣어
/// 뒀는지 알 길이 없어졌다.** 줄마다 `월·수·금` 을 적는 것보다 요일을
/// 골라 보는 편이 읽을 것이 적다.
///
/// **이레를 다 세운다.** 근무일만 세우면 쉬는 날에 넣어 둔 업무(선택)를
/// 볼 자리가 없어진다.
class _DayTabs extends StatelessWidget {
  const _DayTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 5),
          Expanded(
            child: Pressable(
              onTap: () => onSelect(day),
              scale: 0.92,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: day == selected ? AppColors.primary : AppColors.gray50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _MyTaskSectionState._dayNames[day - 1],
                  style: AppTextStyles.body2.copyWith(
                    // 오늘은 안 골랐어도 도드라진다 — 돌아올 자리를 잃지 않게
                    fontWeight: day == selected || day == today
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: day == selected
                        ? Colors.white
                        : day == today
                        ? AppColors.primary
                        : day == 7
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 오른쪽 위 진행 표시 — `3/5` · 다 하면 `완료`
class _DoneBadge extends StatelessWidget {
  const _DoneBadge({required this.day});

  final MyTaskDay day;

  @override
  Widget build(BuildContext context) {
    final complete = day.complete;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: complete
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        complete ? '완료' : '${day.done}/${day.total}',
        style: AppTextStyles.caption.copyWith(
          color: complete ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 업무 한 줄 — 왼쪽 동그라미를 누르면 체크된다
///
/// **결재를 기다리는 줄은 잠근다.** 대표가 승인하기 전에 또 올리면
/// 서버가 `ALREADY_PENDING` 으로 막는데, 눌러 놓고 실패 문구를 보는 것보다
/// 안 눌리는 편이 낫다 (완료된 프로젝트와 같은 방식).
///
/// **다 한 줄도 같이 잠근다 (2026-08-20).** 체크는 되돌릴 수 없어서
/// 누를 자리가 아니다.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.busy,
    required this.onCheck,
    required this.onEdit,
    required this.onDelete,
  });

  final MyTask task;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final checked = task.checked;
    final pending = task.pendingRequest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // **다 한 줄은 도드라지지 않는다.** 파란 면으로 띄우면 눈이 거기
        // 멈추는데, 봐야 하는 건 아직 안 한 줄이다. 줄이 그어진 채로
        // 조용히 물러난다.
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 결재를 기다리는 줄·다 한 줄은 **누름 효과도 안 준다** — 눌리는
          // 것처럼 보이는데 아무 일이 없으면 고장으로 읽힌다
          if (checked || busy || pending != null)
            _CheckMark(checked: checked)
          else
            Pressable(
              onTap: onCheck,
              scale: 0.9,
              child: _CheckMark(checked: checked),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.content,
                  style: AppTextStyles.body2.copyWith(
                    // 다 한 줄은 **글자를 눕힌다** — 색만 바꾸면 남은 것과
                    // 한눈에 안 갈린다. 줄이 그어지면 훑어보다 멈추지 않는다
                    color: checked
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textTertiary,
                    decorationThickness: 1.6,
                  ),
                ),
                if (pending != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${pending.type.label} 결재를 기다리는 중',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 줄에는 요일을 안 적는다 — 목록 위 요일 줄이 이미 어느 요일을
          // 보고 있는지 말해 준다 (2026-08-20 요청)
          if (pending == null) ...[
            _RowAction(icon: CupertinoIcons.pencil, onTap: onEdit),
            _RowAction(icon: CupertinoIcons.trash, onTap: onDelete),
          ],
        ],
      ),
    );
  }
}

/// 왼쪽 동그라미 — 체크되면 채워진다
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => Icon(
    checked ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
    size: 22,
    color: checked ? AppColors.primary : AppColors.gray300,
  );
}

/// 줄 오른쪽 연필·휴지통 — 누르면 결재 폼이 뜬다
class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Icon(icon, size: 15, color: AppColors.textTertiary),
    ),
  );
}

/// 뼈대 — 줄 간격을 실제 목록과 맞춘다 (안 맞추면 바뀔 때 줄이 밀린다)
class _MyTaskSkeleton extends StatelessWidget {
  const _MyTaskSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: SkeletonCard(
      children: [
        Row(
          children: [
            Skeleton(width: 64, height: 13),
            const Spacer(),
            Skeleton(width: 38, height: 22, radius: 10),
          ],
        ),
        const SizedBox(height: 12),
        // 줄 간격을 실제 목록과 맞춘다 — 안 맞추면 뼈대에서 목록으로 바뀔 때 밀린다
        SkeletonRows(rows: 4, avatar: 22, gap: 20, trailing: 40),
      ],
    ),
  );
}
