import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/attendance_api.dart';
import '../../core/api/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/decide_buttons.dart';
import '../../core/widgets/desktop_header.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reject_reason_dialog.dart';
import '../../core/widgets/see_all_button.dart';

part 'attendance_models.dart';
part 'attendance_leave.dart';
part 'attendance_approval.dart';

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
          SizedBox(height: 12),
          _LeaveList(
            leaves: _leaves,
            onCancel: _cancelLeave,
            onOpenAll: _openLeaveHistory,
          ),
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
            SizedBox(height: 16),
            _LeaveList(
              leaves: _leaves,
              onCancel: _cancelLeave,
              onOpenAll: _openLeaveHistory,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 달 요약 ──

/// 보고 있는 달의 근무일·근무시간·지각·결근
///
/// 대표는 출퇴근을 안 찍어서 이 값이 전부 0이다. 그래서 대표 화면에서는
/// 같은 자리에 **오늘 누가 어떤지**를 이름으로 띄운다 ([_TodayBoard]).
class _MonthSummary extends StatelessWidget {
  _MonthSummary({required this.days, required this.month});

  final List<_Day> days;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    if (_isBoss) return _TodayBoard();

    final worked = days.where((d) => d.status.worked).length;
    final total = days.fold(Duration.zero, (sum, d) => sum + d.worked);
    final late = days.where((d) => d.status == _DayStatus.late).length;
    final absent = days.where((d) => d.status == _DayStatus.absent).length;
    final early = days.where((d) => d.status == _DayStatus.early).length;
    final leave = days.where((d) => d.status == _DayStatus.leave).length;
    final off = days.where((d) => d.status == _DayStatus.off).length;
    final average = worked == 0
        ? Duration.zero
        : Duration(minutes: total.inMinutes ~/ worked);
    final now = DateTime.now();
    final thisMonth = month.year == now.year && month.month == now.month;

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
                child: Text('${month.month}월 근무', style: AppTextStyles.label),
              ),
              Text(
                // 이번 달은 아직 안 끝났다는 걸 알려준다
                thisMonth ? '오늘까지' : '한 달 전체',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '$worked일', AppColors.textPrimary),
              _divider(),
              // 폰은 칸이 좁아 네 개면 숫자가 줄어든다.
              // 총 근무는 아래 날짜별 목록에서 다시 볼 수 있어 여기서 뺀다
              if (isDesktop) ...[
                _stat('총 근무', _duration(total), AppColors.primary),
                _divider(),
              ],
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
          // 데스크톱은 옆 월차 카드에 높이를 맞추느라 아래가 비어서,
          // 그 자리를 한 줄 더 채운다 (폰은 카드가 세로로 쌓여 필요 없다)
          if (isDesktop) ...[
            SizedBox(height: 16),
            Spacer(),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 16),
            Row(
              children: [
                _stat('평균 근무', _duration(average), AppColors.textPrimary),
                _divider(),
                _stat(
                  '조기 퇴근',
                  '$early회',
                  early > 0 ? AppColors.warning : AppColors.textPrimary,
                ),
                _divider(),
                _stat(
                  '월차',
                  '$leave일',
                  leave > 0 ? AppColors.primary : AppColors.textPrimary,
                ),
                _divider(),
                _stat('휴무', '$off일', AppColors.textPrimary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

/// 대표가 보는 오늘 근무 — 숫자 대신 **누가** 그런지를 띄운다
///
/// 대표는 자기 출퇴근이 없어서 달 요약이 빈 껍데기다. 칸 모양은 달 요약과
/// 그대로 두고 값만 이름으로 바꾼다. 판정은 서버가 명단에 얹어 주는
/// `Employee.todayStatus` 를 쓴다 (근태 달력·홈과 같은 기준).
///
/// **자정이 지나면 저절로 전원 미출근으로 돌아간다** — 날짜가 바뀌면 그날
/// 기록이 아직 없고, 결근 판정도 '퇴근 시간이 지났나'를 보므로 새벽에는 안 걸린다.
class _TodayBoard extends StatelessWidget {
  _TodayBoard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 지각·조기퇴근을 같이 한 사람은 두 칸에 다 선다 (판정 값은 하나뿐이라)
    final both = _todayWith(AttendanceStatus.lateAndEarly);
    final cells = <(String, Color, List<Employee>)>[
      ('출근', AppColors.success, _todayWith(AttendanceStatus.inProgress)),
      ('퇴근', AppColors.textPrimary, _todayWith(AttendanceStatus.normal)),
      ('야근', AppColors.primary, _todayWith(AttendanceStatus.overtime)),
      (
        '조기퇴근',
        AppColors.warning,
        [..._todayWith(AttendanceStatus.earlyLeave), ...both],
      ),
      (
        '지각',
        AppColors.warning,
        [..._todayWith(AttendanceStatus.late), ...both],
      ),
      ('결근', AppColors.error, _todayWith(AttendanceStatus.absent)),
      ('월차', AppColors.primary, _todayWith(AttendanceStatus.onLeave)),
      ('미출근', AppColors.textSecondary, _todayWith(null)),
    ];
    // 폰은 칸이 좁아 두 개씩 네 줄, 데스크톱은 네 개씩 두 줄
    final perRow = isDesktop ? 4 : 2;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('오늘 근무', style: AppTextStyles.label)),
              Text(
                '${now.month}월 ${now.day}일 (${_weekday(now)})',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          for (var start = 0; start < cells.length; start += perRow) ...[
            if (start > 0) ...[
              SizedBox(height: 16),
              Container(height: 1, color: AppColors.gray100),
              SizedBox(height: 16),
            ],
            Row(
              children: [
                for (var i = start; i < start + perRow; i++) ...[
                  if (i > start) _divider(),
                  _cell(cells[i].$1, cells[i].$2, cells[i].$3),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 달 요약의 `_stat` 과 같은 칸 — 숫자 자리에 이름이 들어간다
  Widget _cell(String label, Color color, List<Employee> people) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _names(people),
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(
              fontSize: 17,
              // 아무도 없는 칸은 색까지 빼서 눈이 안 가게 한다
              color: people.isEmpty ? AppColors.gray300 : color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);

  /// 없으면 `-`, 한 명이면 이름, 여럿이면 `김트레이너 외 2명`
  String _names(List<Employee> people) {
    if (people.isEmpty) return '-';
    if (people.length == 1) return people.first.name;
    return '${people.first.name} 외 ${people.length - 1}명';
  }
}

// ── 달력 ──

/// 화면의 주인공 — 칸마다 그날의 근무나 월차가 바로 보인다
class _MonthCalendar extends StatelessWidget {
  _MonthCalendar({
    required this.month,
    required this.days,
    required this.leaves,
    required this.onMove,
    required this.onPick,
  });

  final DateTime month;
  final List<_Day> days;
  final List<_Leave> leaves;
  final ValueChanged<int> onMove;
  final ValueChanged<DateTime> onPick;

  _Day? _dayOf(DateTime date) {
    for (final day in days) {
      if (_sameDay(day.date, date)) return day;
    }
    return null;
  }

  _Leave? _leaveOf(DateTime date) {
    for (final leave in leaves) {
      if (leave.covers(date) && leave.status.counted) {
        return leave;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    // 1일이 무슨 요일인지에 따라 앞을 비운다 (일요일 시작)
    final lead = month.weekday % 7;
    final rows = ((lead + lastDay) / 7).ceil();
    // 칸 안에 근무 시간까지 들어가야 해서 넉넉히 잡는다.
    // 대표 칸은 상태마다 한 줄씩 들어가서 더 높다
    final cellHeight = _isBoss
        ? (isDesktop ? 118.0 : 92.0)
        : (isDesktop ? 84.0 : 62.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _arrow(CupertinoIcons.chevron_left, () => onMove(-1)),
                SizedBox(width: 10),
                Text(
                  '${month.year}년 ${month.month}월',
                  style: AppTextStyles.title3,
                ),
                SizedBox(width: 10),
                _arrow(CupertinoIcons.chevron_right, () => onMove(1)),
                Spacer(),
                // 폰은 자리가 좁아 범례를 뺀다
                if (isDesktop)
                  for (final status in [
                    _DayStatus.normal,
                    _DayStatus.late,
                    _DayStatus.absent,
                    _DayStatus.leave,
                  ]) ...[_legend(status), SizedBox(width: 9)],
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          for (var row = 0; row < rows; row++)
            // 칸이 스스로 높이를 정하므로 stretch를 쓰면 안 된다
            // (세로가 무한대인 스크롤 안에서는 높이를 못 정해 터진다)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + col - lead + 1;
                        if (dayNumber < 1 || dayNumber > lastDay) {
                          return SizedBox(height: cellHeight);
                        }
                        final date = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        return _DayCell(
                          date: date,
                          day: _dayOf(date),
                          leave: _leaveOf(date),
                          today: _sameDay(date, now),
                          height: cellHeight,
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

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    ),
  );

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

/// 달력 칸 하나 — 날짜 + 그날의 한 줄 요약
class _DayCell extends StatefulWidget {
  _DayCell({
    required this.date,
    required this.day,
    required this.leave,
    required this.today,
    required this.height,
    required this.onTap,
  });

  final DateTime date;
  final _Day? day;
  final _Leave? leave;
  final bool today;
  final double height;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final day = widget.day;
    final leave = widget.leave;
    final sunday = date.weekday == DateTime.sunday;
    // 기록도 월차도 없는 앞날
    final empty = day == null && leave == null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.96,
        child: Container(
          height: widget.height,
          margin: EdgeInsets.all(2),
          padding: EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: BoxDecoration(
            // 잡아둔 월차는 칸 전체를 옅게 물들여 앞으로의 일정이 눈에 띈다
            color: leave != null
                ? AppColors.primary.withValues(alpha: 0.08)
                : _hover
                ? AppColors.gray50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.today ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 12,
                    fontWeight: widget.today
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.today
                        ? Colors.white
                        : empty
                        ? AppColors.gray300
                        : sunday
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isBoss)
                // 대표는 자기 기록이 아니라 그날 전 직원이 어땠는지를 본다
                Expanded(child: _roster(date))
              else ...[
                Spacer(),
                if (leave != null)
                  _tag(
                    leave.kind == _LeaveKind.full ? '월차' : '반차',
                    AppColors.primary,
                    faded: leave.status == _LeaveStatus.pending,
                  )
                else if (day != null)
                  switch (day.status) {
                    // 정상 근무는 배지 대신 근무 시간만 담백하게 보여준다
                    _DayStatus.normal => _hours(day),
                    _DayStatus.late => _tag('지각', AppColors.warning),
                    _DayStatus.early => _tag('조퇴', AppColors.warning),
                    _DayStatus.absent => _tag('결근', AppColors.error),
                    _DayStatus.leave => _tag('월차', AppColors.primary),
                    _DayStatus.off => SizedBox(),
                  },
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 대표 칸 — 상태마다 `이름 외 N명 상태` 한 줄
  ///
  /// 다들 출근·퇴근뿐이면 줄을 늘어놓지 않고 `전원 출근` 한 줄로 끝낸다.
  Widget _roster(DateTime date) {
    final groups = _rosterOf(date);
    if (groups.isEmpty) return SizedBox();

    // 카드와 같은 차례다 — 출근·퇴근 먼저, 챙길 것 나중
    const order = [
      (AttendanceStatus.inProgress, '출근', 0),
      (AttendanceStatus.normal, '퇴근', 1),
      (AttendanceStatus.overtime, '야근', 2),
      (AttendanceStatus.earlyLeave, '조기퇴근', 3),
      (AttendanceStatus.lateAndEarly, '지각·조퇴', 3),
      (AttendanceStatus.late, '지각', 3),
      (AttendanceStatus.noCheckout, '퇴근누락', 4),
      (AttendanceStatus.absent, '결근', 4),
      (AttendanceStatus.onLeave, '월차', 5),
    ];
    final colors = [
      AppColors.success,
      AppColors.textSecondary,
      AppColors.primary,
      AppColors.warning,
      AppColors.error,
      AppColors.primary,
    ];

    final lines = <Widget>[];
    var onlyPlain = true;
    for (final (status, label, tone) in order) {
      final names = groups[status];
      if (names == null || names.isEmpty) continue;
      if (tone > 1) onlyPlain = false;
      lines.add(_line('${_who(names)} $label', colors[tone]));
    }
    if (lines.isEmpty) return SizedBox();
    if (onlyPlain) return _line('전원 출근', AppColors.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: lines,
    );
  }

  /// `김트레이너` · `김트레이너 외 3명`
  String _who(List<String> names) =>
      names.length == 1 ? names.first : '${names.first} 외 ${names.length - 1}명';

  Widget _line(String text, Color color) => SizedBox(
    width: double.infinity,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        height: 1.45,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _hours(_Day day) => Row(
    children: [
      Container(
        width: 5,
        height: 5,
        margin: EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _shortDuration(day.worked),
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ],
  );

  /// 지각·결근·월차처럼 눈에 띄어야 하는 것만 알약으로
  Widget _tag(String label, Color color, {bool faded = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: faded ? 0.1 : 0.16),
      borderRadius: BorderRadius.circular(6),
      // 아직 결재 전인 월차는 테두리만 둘러 예정임을 알린다
      border: faded ? Border.all(color: color.withValues(alpha: 0.4)) : null,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

// ── 날짜 상세 ──

/// 달력에서 날짜를 누르면 뜨는 창 — 그날의 출퇴근과 월차
class _DayDialog extends StatelessWidget {
  _DayDialog({required this.date, required this.day, required this.leave});

  final DateTime date;
  final _Day? day;
  final _Leave? leave;

  @override
  Widget build(BuildContext context) {
    final record = day;

    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${date.month}월 ${date.day}일 (${_weekday(date)})',
                  style: AppTextStyles.title3,
                ),
              ),
              if (record != null) _StatusChip(status: record.status),
            ],
          ),
          SizedBox(height: 18),
          if (record != null && record.checkIn != null) ...[
            Row(
              children: [
                _cell('출근', _clock(record.checkIn)),
                Container(width: 1, height: 34, color: AppColors.gray100),
                _cell('퇴근', _clock(record.checkOut)),
                Container(width: 1, height: 34, color: AppColors.gray100),
                _cell('근무', _duration(record.worked)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '출근부터 퇴근까지의 시간이에요',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ] else
            _empty(),
          if (leave != null) ...[
            SizedBox(height: 16),
            Container(height: 1, color: AppColors.divider),
            SizedBox(height: 14),
            Row(
              children: [
                Text('월차', style: AppTextStyles.label),
                SizedBox(width: 8),
                Text(
                  leave!.kind.label,
                  style: AppTextStyles.body2.copyWith(fontSize: 13),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: leave!.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    leave!.status.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: leave!.status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              leave!.reason,
              style: AppTextStyles.body2.copyWith(fontSize: 13, height: 1.5),
            ),
          ],
          SizedBox(height: 18),
          Pressable(
            onTap: () => Navigator.pop(context),
            scale: 0.97,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '닫기',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
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

  Widget _empty() {
    final text = switch (day?.status) {
      _DayStatus.off => '쉬는 날이에요',
      _DayStatus.absent => '출근 기록이 없어요',
      _DayStatus.leave => '월차를 쓴 날이에요',
      _ => leave != null ? '월차가 잡혀 있어요' : '아직 기록이 없어요',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.body2.copyWith(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
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
