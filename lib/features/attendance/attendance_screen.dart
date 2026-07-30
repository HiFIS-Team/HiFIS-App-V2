import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/pressable.dart';

part 'attendance_models.dart';
part 'attendance_leave.dart';

/// 근태·월차 화면 (목업)
///
/// 근태 탭은 이번 달 요약과 달력, 날짜별 출퇴근 기록을 보여준다.
/// 월차 탭은 남은 월차와 신청 내역을 다루고, 여기서 새 신청을 올린다.
class AttendanceScreen extends StatefulWidget {
  AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  /// true면 월차 탭
  bool _leaveTab = false;

  /// 달력에서 고른 날 (없으면 오늘)
  DateTime? _picked;

  _Day? get _pickedDay {
    final date = _picked;
    if (date == null) return null;
    for (final day in _days) {
      if (_sameDay(day.date, date)) return day;
    }
    return null;
  }

  Future<void> _requestLeave() async {
    final leave = await _showLeaveComposer(context);
    if (leave == null || !mounted) return;
    setState(() => _leaves.insert(0, leave));
    AppToast.show(context, '월차를 신청했어요');
  }

  void _cancelLeave(_Leave leave) {
    setState(() => _leaves.remove(leave));
    AppToast.show(context, '신청을 취소했어요');
  }

  /// 근태 탭 내용
  List<Widget> _attendance() {
    return [
      _MonthSummary(days: _days),
      SizedBox(height: 16),
      _MonthCalendar(
        days: _days,
        picked: _picked,
        onPick: (date) => setState(() {
          // 같은 날을 다시 누르면 선택을 푼다
          _picked = _picked != null && _sameDay(_picked!, date) ? null : date;
        }),
      ),
      if (_pickedDay != null) ...[
        SizedBox(height: 16),
        _DayDetail(day: _pickedDay!),
      ],
      SizedBox(height: 16),
      _RecordList(days: _days),
    ];
  }

  /// 월차 탭 내용
  List<Widget> _leave() {
    return [
      _LeaveBalance(onRequest: _requestLeave),
      SizedBox(height: 16),
      _LeaveList(leaves: _leaves, onCancel: _cancelLeave),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = _leaveTab ? _leave() : _attendance();
    final filter = ModeSwitch(
      left: '근태',
      right: '월차',
      value: _leaveTab,
      onChanged: (v) => setState(() => _leaveTab = v),
    );

    if (!isDesktop) {
      return PhoneListScaffold(title: '근태·월차', filter: filter, children: body);
    }

    // 데스크톱은 폭이 넓어 요약·달력과 목록을 좌우로 나눈다
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            Row(
              children: [
                Text('근태·월차', style: AppTextStyles.title1),
                SizedBox(width: 20),
                SizedBox(width: 240, child: filter),
              ],
            ),
            SizedBox(height: 20),
            if (_leaveTab)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _LeaveBalance(onRequest: _requestLeave)),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _LeaveList(
                        leaves: _leaves,
                        onCancel: _cancelLeave,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _MonthSummary(days: _days),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _MonthCalendar(
                          days: _days,
                          picked: _picked,
                          onPick: (date) => setState(() {
                            _picked =
                                _picked != null && _sameDay(_picked!, date)
                                ? null
                                : date;
                          }),
                        ),
                        if (_pickedDay != null) ...[
                          SizedBox(height: 16),
                          _DayDetail(day: _pickedDay!),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(child: _RecordList(days: _days)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 이번 달 요약 ──

/// 근무일·근무시간·지각·결근을 한 줄로 보여준다
class _MonthSummary extends StatelessWidget {
  _MonthSummary({required this.days});

  final List<_Day> days;

  @override
  Widget build(BuildContext context) {
    final worked = days.where((d) => d.status.worked).length;
    final total = days.fold(Duration.zero, (sum, d) => sum + d.worked);
    final late = days.where((d) => d.status == _DayStatus.late).length;
    final absent = days.where((d) => d.status == _DayStatus.absent).length;
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${now.month}월 근무', style: AppTextStyles.label),
              ),
              Text('오늘까지', style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '$worked일', AppColors.textPrimary),
              _divider(),
              _stat('총 근무', _duration(total), AppColors.primary),
              _divider(),
              _stat(
                '지각',
                '$late회',
                late > 0 ? AppColors.warning : AppColors.textPrimary,
              ),
              _divider(),
              _stat(
                '결근',
                '$absent회',
                absent > 0 ? AppColors.error : AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

// ── 달력 ──

/// 이번 달 달력 — 날짜마다 상태 점이 찍힌다
class _MonthCalendar extends StatelessWidget {
  _MonthCalendar({
    required this.days,
    required this.picked,
    required this.onPick,
  });

  final List<_Day> days;
  final DateTime? picked;
  final ValueChanged<DateTime> onPick;

  _Day? _dayOf(DateTime date) {
    for (final day in days) {
      if (_sameDay(day.date, date)) return day;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    // 1일이 무슨 요일인지에 따라 앞을 비운다 (일요일 시작)
    final lead = first.weekday % 7;
    final cells = lead + lastDay;
    final rows = (cells / 7).ceil();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${now.year}년 ${now.month}월',
                    style: AppTextStyles.label,
                  ),
                ),
                for (final status in [
                  _DayStatus.normal,
                  _DayStatus.late,
                  _DayStatus.absent,
                  _DayStatus.leave,
                ]) ...[_legend(status), SizedBox(width: 8)],
              ],
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + col - lead + 1;
                        if (dayNumber < 1 || dayNumber > lastDay) {
                          return SizedBox(height: 44);
                        }
                        final date = DateTime(now.year, now.month, dayNumber);
                        return _DayCell(
                          date: date,
                          day: _dayOf(date),
                          today: _sameDay(date, now),
                          picked: picked != null && _sameDay(picked!, date),
                          onTap: () => onPick(date),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legend(_DayStatus status) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
      ),
      SizedBox(width: 3),
      Text(status.label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
    ],
  );
}

/// 달력 칸 하나
class _DayCell extends StatelessWidget {
  _DayCell({
    required this.date,
    required this.day,
    required this.today,
    required this.picked,
    required this.onTap,
  });

  final DateTime date;
  final _Day? day;
  final bool today;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sunday = date.weekday == DateTime.sunday;
    // 기록이 없는 앞날은 흐리게 둔다
    final future = day == null;

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: picked
                    ? AppColors.primary
                    : today
                    ? AppColors.primaryLight
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: AppTextStyles.body2.copyWith(
                  fontSize: 13,
                  fontWeight: today || picked
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: picked
                      ? Colors.white
                      : today
                      ? AppColors.primary
                      : future
                      ? AppColors.gray300
                      : sunday
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: day?.status.color ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달력에서 고른 날의 상세
class _DayDetail extends StatelessWidget {
  _DayDetail({required this.day});

  final _Day day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${day.date.month}월 ${day.date.day}일 (${_weekday(day.date)})',
                  style: AppTextStyles.label,
                ),
              ),
              _StatusChip(status: day.status),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _cell('출근', _clock(day.checkIn)),
              Container(width: 1, height: 30, color: AppColors.gray100),
              _cell('퇴근', _clock(day.checkOut)),
              Container(width: 1, height: 30, color: AppColors.gray100),
              _cell(
                '근무',
                day.worked == Duration.zero ? '--' : _duration(day.worked),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value, style: AppTextStyles.title3.copyWith(fontSize: 16)),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );
}

// ── 기록 목록 ──

/// 최근 날짜부터 쌓아 보여주는 출퇴근 기록
class _RecordList extends StatelessWidget {
  _RecordList({required this.days});

  final List<_Day> days;

  @override
  Widget build(BuildContext context) {
    final sorted = [...days]..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('출퇴근 기록', style: AppTextStyles.label),
          ),
          SizedBox(height: 6),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            _RecordRow(day: sorted[i]),
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  _RecordRow({required this.day});

  final _Day day;

  @override
  Widget build(BuildContext context) {
    final rest = day.checkIn == null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Row(
              children: [
                Text(
                  '${day.date.day}',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  _weekday(day.date),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: day.date.weekday == DateTime.sunday
                        ? AppColors.error
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              rest ? '-' : '${_clock(day.checkIn)} – ${_clock(day.checkOut)}',
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                color: rest ? AppColors.textTertiary : AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 74,
            child: Text(
              rest ? '' : _duration(day.worked),
              textAlign: TextAlign.end,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 8),
          _StatusChip(status: day.status),
        ],
      ),
    );
  }
}

/// 상태 알약 (정상·지각·결근·월차·휴무)
class _StatusChip extends StatelessWidget {
  _StatusChip({required this.status});

  final _DayStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: status.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
