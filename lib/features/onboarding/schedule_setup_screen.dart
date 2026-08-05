import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/data/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/pressable.dart';

/// 근무 설정 — 첫 로그인 때 한 번 받는다
///
/// 근무 시간과 근무 요일이 있어야 서버가 지각·결근을 판정한다.
/// 요일을 안 보내면 저장 자체가 안 되고(422), 결근이 영영 안 잡힌다.
///
/// 근무 시간 중에는 서버가 변경을 막는다(403) — 퇴근 시각을 당겨
/// 초과근무 점수를 만드는 걸 막기 위한 규칙이다.
class ScheduleSetupScreen extends StatefulWidget {
  ScheduleSetupScreen({super.key, this.onDone});

  /// 저장이 끝나면 알린다 (게이트가 메인 화면으로 넘어간다)
  final VoidCallback? onDone;

  @override
  State<ScheduleSetupScreen> createState() => _ScheduleSetupScreenState();
}

class _ScheduleSetupScreenState extends State<ScheduleSetupScreen> {
  /// ISO 요일 1(월) ~ 7(일) — 이미 설정한 게 있으면 그걸, 없으면 주 5일
  late final Set<int> _days = {
    ...(currentUser?.workDays.isNotEmpty ?? false)
        ? currentUser!.workDays
        : const [1, 2, 3, 4, 5],
  };

  late TimeOfDay _start = _parse(currentUser?.shiftStart) ?? _at(9);
  late TimeOfDay _end = _parse(currentUser?.shiftEnd) ?? _at(18);

  bool _busy = false;

  static TimeOfDay _at(int hour) => TimeOfDay(hour: hour, minute: 0);

  static TimeOfDay? _parse(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _wire(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (context, child) => MediaQuery(
        // 24시간 표기로 고정 — 근무 시간은 오전/오후가 헷갈리면 안 된다
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (_days.isEmpty) {
      return AppToast.show(context, '근무 요일을 하나 이상 골라 주세요');
    }
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (endMinutes <= startMinutes) {
      return AppToast.show(context, '퇴근 시간이 출근 시간보다 늦어야 해요');
    }

    setState(() => _busy = true);
    try {
      final updated = await AttendanceApi.setSchedule(
        shiftStart: _wire(_start),
        shiftEnd: _wire(_end),
        workDays: _days.toList()..sort(),
      );
      currentUser = updated;
      if (!mounted) return;
      widget.onDone?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('근무 설정', style: AppTextStyles.title1),
        SizedBox(height: 8),
        Text(
          '출퇴근 기록과 결근 판정에 쓰여요.\n나중에 근태 화면에서 바꿀 수 있어요.',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 28),
        Text('근무 요일', style: AppTextStyles.label),
        SizedBox(height: 10),
        _WeekdayPicker(
          selected: _days,
          onToggle: (day) => setState(() {
            _days.contains(day) ? _days.remove(day) : _days.add(day);
          }),
        ),
        SizedBox(height: 24),
        Text('근무 시간', style: AppTextStyles.label),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: '출근',
                time: _start,
                onTap: () => _pick(start: true),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _TimeBox(
                label: '퇴근',
                time: _end,
                onTap: () => _pick(start: false),
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        AppButton(label: '저장', onTap: _busy ? () {} : _save, filled: true),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.fromLTRB(36, 30, 36, 30),
                decoration: AppDecorations.card(),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: content,
        ),
      ),
    );
  }
}

/// 월~일 동그라미 — 누르면 켜지고 꺼진다
class _WeekdayPicker extends StatelessWidget {
  _WeekdayPicker({required this.selected, required this.onToggle});

  /// ISO 요일 1(월) ~ 7(일)
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => onToggle(day),
              scale: 0.94,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 120),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected.contains(day)
                      ? AppColors.primary
                      : AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _labels[day - 1],
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected.contains(day)
                        ? Colors.white
                        : AppColors.textTertiary,
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

/// 출근·퇴근 시각 상자
class _TimeBox extends StatelessWidget {
  _TimeBox({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppTextStyles.caption),
            SizedBox(height: 2),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}',
              style: AppTextStyles.title3,
            ),
          ],
        ),
      ),
    );
  }
}
