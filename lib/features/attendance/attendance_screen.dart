import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/widgets/nav/pane_transition.dart';
import '../../core/widgets/input/app_button.dart';

part 'attendance_models.dart';
part 'attendance_leave.dart';
part 'attendance_approval.dart';
part 'attendance_summary.dart';
part 'attendance_calendar.dart';
part 'attendance_day.dart';

/// 근태·월차 화면 (목업)
///
/// 달력 하나로 근태와 월차를 같이 본다. 지나간 날에는 그날의 근무가,
/// 앞날에는 잡아둔 월차가 칸 안에 바로 보이고, 날짜를 누르면 상세가 뜬다.
class AttendanceScreen extends StatefulWidget {
  AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  /// 달력이 보고 있는 달
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// 첫 로딩 — 받아오기 전에는 빈 달력 대신 로딩을 보여준다
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _reload();
    if (mounted) setState(() => _loading = false);
  }

  /// 월차를 승인·반려한 뒤 다시 받는다 — 결재함과 달력이 같이 바뀐다
  Future<void> _reload() async {
    try {
      await _loadAttendance();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  Future<void> _moveMonth(int delta) async {
    final month = DateTime(_month.year, _month.month + delta);
    setState(() => _month = month);
    // 대표 달력은 전사 기록이라 달마다 따로 받아야 한다
    try {
      await _loadRoster(_monthKey(month));
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  /// 보고 있는 달의 기록만 추린다 (요약도 이 달 기준)
  List<_Day> get _monthDays => _days
      .where((d) => d.date.year == _month.year && d.date.month == _month.month)
      .toList();

  _Day? _dayOf(DateTime date) {
    for (final day in _days) {
      if (_sameDay(day.date, date)) return day;
    }
    return null;
  }

  /// 그날 잡혀 있는 월차 (반려·취소된 건 빼고)
  _Leave? _leaveOf(DateTime date) {
    for (final leave in _leaves) {
      if (leave.covers(date) && leave.status.counted) return leave;
    }
    return null;
  }

  void _openDay(DateTime date) {
    showAppDialog<void>(
      context,
      (context) =>
          _DayDialog(date: date, day: _dayOf(date), leave: _leaveOf(date)),
    );
  }

  Future<void> _requestLeave() async {
    final draft = await _showLeaveComposer(context);
    if (draft == null || !mounted) return;

    try {
      final created = await AttendanceApi.createLeave(
        type: draft.kind.type,
        halfPeriod: draft.kind.period,
        startDate: draft.date,
        endDate: draft.endDate,
        reason: draft.reason,
      );
      if (!mounted) return;
      setState(() {
        _leaves.insert(0, _Leave.from(created));
        // 신청한 달을 바로 보여준다
        _month = DateTime(draft.date.year, draft.date.month);
      });
      AppToast.show(context, '월차를 신청했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _cancelLeave(_Leave leave) async {
    final id = leave.id;
    if (id == null) return;
    try {
      final cancelled = await AttendanceApi.cancelLeave(id);
      if (!mounted) return;
      // 서버가 이력을 남기므로 목록에서 지우지 않고 상태만 바꾼다
      setState(() => leave.status = _LeaveStatus.of(cancelled.status));
      AppToast.show(context, '신청을 취소했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 전체 목록에서 취소하고 돌아올 수 있어 다녀오면 다시 그린다
  Future<void> _openLeaveHistory() async {
    await showFullPage<void>(context, (_) => _LeaveHistoryScreen());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final calendar = _MonthCalendar(
      month: _month,
      days: _days,
      leaves: _leaves,
      onMove: _moveMonth,
      onPick: _openDay,
    );

    if (!isDesktop) {
      return PhoneListScaffold(
        title: '근태·월차',
        children: [
          _MonthSummary(days: _monthDays, month: _month),
          SizedBox(height: 12),
          _LeaveBalance(onRequest: _requestLeave, onDecided: _reload),
          SizedBox(height: 12),
          calendar,
          // 대표는 본인 월차를 안 써서 이 카드가 늘 비어 있다
          if (!_isBoss) ...[
            SizedBox(height: 12),
            _LeaveList(
              leaves: _leaves,
              onCancel: _cancelLeave,
              onOpenAll: _openLeaveHistory,
            ),
          ],
        ],
      );
    }

    // 데스크톱은 폭이 남아서 요약 두 장을 나란히 두고 달력을 넓게 쓴다
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(title: '근태·월차', subtitle: '이번 달 근무 기록과 월차를 관리해요'),
            SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _MonthSummary(days: _monthDays, month: _month),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _LeaveBalance(
                      onRequest: _requestLeave,
                      onDecided: _reload,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            calendar,
            if (!_isBoss) ...[
              SizedBox(height: 16),
              _LeaveList(
                leaves: _leaves,
                onCancel: _cancelLeave,
                onOpenAll: _openLeaveHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
