import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/my_task_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/screen_refresh.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../../core/widgets/input/pressable.dart';

part 'my_task_forms.dart';

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
  const MyTaskSection({super.key});

  @override
  State<MyTaskSection> createState() => _MyTaskSectionState();
}

class _MyTaskSectionState extends State<MyTaskSection>
    with ScreenRefresh<MyTaskSection>, SkeletonDelay<MyTaskSection> {
  MyTaskDay? _day;

  /// 서버에 보내는 중인 줄 — 답이 오기 전에 또 누르면 두 번 나간다
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onScreenRefresh() => _load();

  Future<void> _load() async {
    try {
      final day = await MyTaskApi.day();
      if (!mounted) return;
      // **옛 목록을 안 지운다** — 지우면 그 사이가 빈 화면이라 깜빡인다
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

  /// 체크/해제 — 서버 답을 받고 나서 목록을 다시 받는다
  Future<void> _toggle(MyTask task) async {
    if (_busy.contains(task.id)) return;
    setState(() => _busy.add(task.id));
    try {
      if (task.checked) {
        await MyTaskApi.uncheck(task.id);
      } else {
        await MyTaskApi.check(task.id);
      }
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _busy.remove(task.id));
  }

  Future<void> _add() async {
    final content = await showAppDialog<String>(
      context,
      (_) => const _AddTaskCard(),
    );
    if (content == null || !mounted) return;
    try {
      await MyTaskApi.create(content);
      await _load();
      if (mounted) AppToast.show(context, '업무를 추가했어요');
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
                Expanded(child: Text('오늘 할 일', style: AppTextStyles.label)),
                _DoneBadge(day: day),
              ],
            ),
          ),
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
                busy: _busy.contains(day.tasks[i].id),
                onToggle: () => _toggle(day.tasks[i]),
                onEdit: () => _request(day.tasks[i], MyTaskRequestType.edit),
                onDelete: () =>
                    _request(day.tasks[i], MyTaskRequestType.delete),
              ),
            ],
          const SizedBox(height: 14),
          AppButton(label: '업무 추가', filled: true, onTap: _add),
        ],
      ),
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
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MyTask task;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final checked = task.checked;
    final pending = task.pendingRequest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: checked ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: checked
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // 결재를 기다리는 줄은 **누름 효과도 안 준다** — 눌리는 것처럼
          // 보이는데 아무 일이 없으면 고장으로 읽힌다
          if (busy || pending != null)
            _CheckMark(checked: checked)
          else
            Pressable(
              onTap: onToggle,
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
                    color: checked ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
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
        const SizedBox(height: 14),
        Skeleton(height: 48, radius: 14),
      ],
    ),
  );
}
