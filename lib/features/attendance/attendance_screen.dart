import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/data/branch_scope.dart';
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
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/util/screen_refresh.dart';

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

class _AttendanceScreenState extends State<AttendanceScreen> with ScreenRefresh<AttendanceScreen> {
  /// 달력이 보고 있는 달
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// 주 달력이 보고 있는 주의 **일요일** — 폰 대표 화면에서만 쓴다
  late DateTime _week = _sundayOf(DateTime.now());

  /// 폰에서 대표·관리자는 달 대신 주로 본다
  ///
  /// 대표 칸은 그날 누가 어땠는지를 이름으로 담아서 칸이 상태 줄만큼 자란다.
  /// 한 달을 세우면 폰에서 화면이 한참 길어져 훑기가 어렵다.
  bool get _weekly => !isDesktop && _isBoss;

  /// 그 주의 일요일 — 달력이 일요일 시작이라 거기에 맞춘다
  static DateTime _sundayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday % 7);

  /// 첫 로딩 — 받아오기 전에는 빈 달력 대신 로딩을 보여준다
  bool _loading = true;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    branchScope.addListener(_onBranchScope);
    _load();
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다 — 대표 화면의 오늘 판·달력을 그 지점으로 다시 받는다
  void _onBranchScope() {
    if (!mounted) return;
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    await _reload();
    // 이번 주가 지난달에 걸쳐 있으면 그 달 기록도 받아야 한다.
    // 첫 로딩은 이번 달만 받아 두어서(`_loadAttendance`) 안 받으면
    // 지난달에 걸친 날들이 기록 없는 날처럼 빈칸으로 뜬다.
    if (_weekly) {
      final end = DateTime(_week.year, _week.month, _week.day + 6);
      await _fetchRoster([_week, end]);
    }
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
    await _fetchRoster([month]);
  }

  Future<void> _moveWeek(int delta) async {
    final week = DateTime(_week.year, _week.month, _week.day + delta * 7);
    setState(() {
      _week = week;
      // 요약 카드는 달 기준이라 주가 넘어가면 같이 옮긴다
      _month = DateTime(week.year, week.month);
    });
    // 한 주가 달을 걸칠 수 있다 — 첫날과 마지막 날의 달을 둘 다 받는다
    final end = DateTime(week.year, week.month, week.day + 6);
    await _fetchRoster([week, end]);
  }

  /// 그 달들의 전사 기록을 받아 둔다 (이미 받은 달은 그냥 지나간다)
  Future<void> _fetchRoster(List<DateTime> months) async {
    try {
      for (final key in {for (final m in months) _monthKey(m)}) {
        await _loadRoster(key);
      }
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
      if (!isDesktop) return _AttendanceSkeleton();
      return SkeletonDesktopPage(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SkeletonCard(
                  padding: EdgeInsets.all(20),
                  children: [
                    Skeleton(width: 96, height: 14),
                    SizedBox(height: 18),
                    SkeletonRows(rows: 2, avatar: 0, trailing: 56),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SkeletonCard(
                  padding: EdgeInsets.all(20),
                  children: [
                    Skeleton(width: 72, height: 14),
                    SizedBox(height: 18),
                    SkeletonRows(rows: 2, avatar: 0, trailing: 56),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SkeletonCard(
            padding: EdgeInsets.fromLTRB(14, 18, 14, 14),
            children: [
              Row(
                children: [
                  SkeletonCircle(size: 18),
                  SizedBox(width: 10),
                  Skeleton(width: 110, height: 18),
                  SizedBox(width: 10),
                  SkeletonCircle(size: 18),
                ],
              ),
              SizedBox(height: 20),
              for (var row = 0; row < 5; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: SizedBox(
                          height: 84,
                          child: Center(
                            child: Skeleton(width: 26, height: 26, radius: 8),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      );
    }

    final calendar = _weekly
        ? _WeekCalendar(start: _week, onMove: _moveWeek, onPick: _openDay)
        : _MonthCalendar(
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
