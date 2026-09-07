import 'package:flutter/cupertino.dart';
import '../../core/data/data_signal.dart';
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
import '../../core/widgets/display/scroll_box.dart';
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
import '../../core/util/skeleton_delay.dart';

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

class _AttendanceScreenState extends State<AttendanceScreen>
    with ScreenRefresh<AttendanceScreen>, SkeletonDelay<AttendanceScreen> {
  /// 달력이 보고 있는 달
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  /// 월차 결재함·남은 월차가 바뀐다 (근태는 카운터 스캐너가 찍는다)
  @override
  List<ValueNotifier<int>> get watchSignals => [
    attendanceChanged,
    approvalChanged,
  ];

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
  ///
  /// **달력을 안 지운다.** 빨리 오면 뼈대가 아예 안 뜨고 옛 달력 위에 새 값이
  /// 얹힌다 (`SkeletonDelay`) — 지점을 바꿀 때마다 화면이 깜빡이던 자리다.
  void _onBranchScope() {
    if (!mounted) return;
    setState(beginLoad);
    _load();
  }

  Future<void> _load() async {
    await _reload();
    if (mounted) setState(endLoad);
  }

  /// 월차를 승인·반려한 뒤 다시 받는다 — 결재함과 달력이 같이 바뀐다
  Future<void> _reload() async {
    try {
      await _loadAttendance();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
    // `_loadAttendance` 는 받아 둔 것을 통째로 비우고 **지난달·이번 달**만 다시
    // 채운다. 그래서 다른 달을 보고 있으면 승인한 순간 그 칸이 빈칸이 된다 —
    // **월차는 미리 내는 것이라 결재하는 자리가 다음 달인 경우가 흔하다.**
    // (이미 받은 달은 그냥 지나가므로 이번 달을 보고 있으면 아무 일도 안 한다)
    await _fetchMonths([_month]);
  }

  Future<void> _moveMonth(int delta) async {
    final month = DateTime(_month.year, _month.month + delta);
    setState(() => _month = month);
    // 대표 달력은 전사 기록이라 달마다 따로 받아야 한다
    await _fetchMonths([month]);
  }

  /// 그 달들의 기록을 받아 둔다 (이미 받은 달은 그냥 지나간다)
  ///
  /// **둘 다 받는다** — 내 근태(달력 칸)와 전사 기록(대표 달력).
  /// 예전에는 전사 것만 받아서, 달을 넘기면 **본인 달력이 빈칸**이었다.
  /// 미래 달에 미리 낸 월차가 뜨기 시작하면서 그게 드러났다 (2026-08-21).
  Future<void> _fetchMonths(List<DateTime> months) async {
    try {
      for (final key in {for (final m in months) _monthKey(m)}) {
        await _loadDays(key);
        await _loadRoster(key);
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  /// 보고 있는 달의 기록만 추린다 (요약 카드가 쓴다)
  ///
  /// **오늘까지만 센다.** 서버가 미래 날에도 승인된 월차를 주게 되면서
  /// (달력 칸에 미리 보이라고 — 2026-08-21) 여기까지 세면 요약 카드의
  /// `월차` 만 달 전체가 되고 `근무 · 지각 · 결근` 은 오늘까지라
  /// **한 카드 안에서 기준이 갈린다.**
  ///
  /// 달력 칸은 `_dayOf` 가 `_days` 를 직접 보므로 미래 월차는 그대로 뜬다.
  List<_Day> get _monthDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _days
        .where(
          (d) =>
              d.date.year == _month.year &&
              d.date.month == _month.month &&
              !d.date.isAfter(today),
        )
        .toList();
  }

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
    if (showSkeleton) {
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

    // **어느 화면이든 한 달 달력이다** (2026-09-07 요청). 예전에는 폰에서
    // 대표·관리자만 주 단위로 접어서 봤다 — 칸에 `이름 외 N명 출근` 이 들어가
    // 한 달이면 화면이 길어진다는 이유였는데, 한 주씩 넘겨 보느라 **이번 달을
    // 한눈에 못 봤다.** 칸 높이는 그 달에서 제일 바쁜 날에 맞춰 자란다
    // (`_bossCellHeight`) — 길어지더라도 달이 통째로 보이는 쪽을 골랐다.
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
