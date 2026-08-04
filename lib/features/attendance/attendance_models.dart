part of 'attendance_screen.dart';

/// 하루의 근태 상태
enum _DayStatus {
  normal('정상'),
  late('지각'),
  early('조기 퇴근'),
  absent('결근'),
  leave('월차'),
  off('휴무');

  const _DayStatus(this.label);

  final String label;

  Color get color => switch (this) {
    _DayStatus.normal => AppColors.success,
    _DayStatus.late => AppColors.warning,
    _DayStatus.early => AppColors.warning,
    _DayStatus.absent => AppColors.error,
    _DayStatus.leave => AppColors.primary,
    _DayStatus.off => AppColors.gray300,
  };

  /// 근무한 날인지 (요약의 근무일 수에 들어간다)
  bool get worked =>
      this == _DayStatus.normal ||
      this == _DayStatus.late ||
      this == _DayStatus.early;

  /// 서버 판정을 화면 상태로 옮긴다
  ///
  /// 서버는 지각+조기퇴근을 따로 구분하고 퇴근 전·퇴근 누락도 나누는데,
  /// 달력 칸은 색 하나뿐이라 가까운 쪽으로 모은다.
  static _DayStatus of(AttendanceStatus status) => switch (status) {
    // 야근도 달력 칸에서는 정상 근무다 — 그날 일한 시간이 그대로 보인다
    AttendanceStatus.normal ||
    AttendanceStatus.overtime ||
    AttendanceStatus.inProgress => _DayStatus.normal,
    AttendanceStatus.late || AttendanceStatus.lateAndEarly => _DayStatus.late,
    AttendanceStatus.earlyLeave ||
    AttendanceStatus.noCheckout => _DayStatus.early,
    AttendanceStatus.absent => _DayStatus.absent,
    AttendanceStatus.onLeave => _DayStatus.leave,
    AttendanceStatus.dayOff || AttendanceStatus.unknown => _DayStatus.off,
  };
}

/// 하루치 근태 기록
class _Day {
  _Day({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workMinutes,
  });

  /// 서버가 판정한 하루를 그대로 받는다
  ///
  /// 지각·결근 판정을 앱이 직접 하면 급여·평가가 쓰는 기준과 갈린다.
  /// 결근은 기록이 아예 없는 날이라 앱이 만들 수도 없다.
  factory _Day.from(AttendanceDay day) => _Day(
    date: day.date,
    status: _DayStatus.of(day.status),
    checkIn: day.checkIn,
    checkOut: day.checkOut,
    workMinutes: day.workMinutes,
  );

  final DateTime date;
  final _DayStatus status;

  /// 출근·퇴근 시각 (쉬는 날은 null)
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// 서버가 계산한 근무 분 — 급여가 이 값을 쓴다
  final int? workMinutes;

  /// 근무 시간 — 출근부터 퇴근까지 그대로다 (휴게 시간을 빼지 않는다)
  ///
  /// 급여가 기본급 기준이라 휴게를 빼면 화면 시간과 급여 시간이 어긋난다.
  /// 서버가 준 값이 있으면 그걸 쓰고, 없을 때만 직접 뺀다.
  Duration get worked {
    if (workMinutes != null) return Duration(minutes: workMinutes!);
    if (checkIn == null || checkOut == null) return Duration.zero;
    return checkOut!.difference(checkIn!);
  }
}

/// 월차 종류
enum _LeaveKind {
  full('종일', 1.0, LeaveType.annual, null),
  morning('오전 반차', 0.5, LeaveType.half, HalfPeriod.am),
  afternoon('오후 반차', 0.5, LeaveType.half, HalfPeriod.pm);

  const _LeaveKind(this.label, this.days, this.type, this.period);

  final String label;

  /// 차감되는 일수
  final double days;

  /// 서버에 보낼 값
  final LeaveType type;

  /// 반차일 때 오전·오후 구분
  final HalfPeriod? period;

  static _LeaveKind of(LeaveType type, HalfPeriod? period) {
    if (type != LeaveType.half) return _LeaveKind.full;
    return period == HalfPeriod.pm ? _LeaveKind.afternoon : _LeaveKind.morning;
  }
}

/// 월차 신청 상태
enum _LeaveStatus {
  pending('대기'),
  approved('승인'),
  rejected('반려'),
  cancelled('취소');

  const _LeaveStatus(this.label);

  final String label;

  Color get color => switch (this) {
    _LeaveStatus.pending => AppColors.warning,
    _LeaveStatus.approved => AppColors.success,
    _LeaveStatus.rejected => AppColors.error,
    _LeaveStatus.cancelled => AppColors.gray400,
  };

  /// 달력에 표시할 신청인지 — 반려·취소된 건 그날 쉬는 게 아니다
  bool get counted =>
      this == _LeaveStatus.pending || this == _LeaveStatus.approved;

  static _LeaveStatus of(LeaveStatus status) => switch (status) {
    LeaveStatus.pending => _LeaveStatus.pending,
    LeaveStatus.approved => _LeaveStatus.approved,
    LeaveStatus.rejected => _LeaveStatus.rejected,
    LeaveStatus.cancelled => _LeaveStatus.cancelled,
  };
}

/// 월차 신청 한 건
class _Leave {
  _Leave({
    required this.date,
    required this.kind,
    required this.reason,
    this.id,
    DateTime? endDate,
    double? days,
    this.status = _LeaveStatus.pending,
  }) : endDate = endDate ?? date,
       days = days ?? kind.days;

  factory _Leave.from(LeaveRequest request) => _Leave(
    id: request.id,
    date: request.startDate,
    endDate: request.endDate,
    days: request.days,
    kind: _LeaveKind.of(request.type, request.halfPeriod),
    reason: request.reason ?? '',
    status: _LeaveStatus.of(request.status),
  );

  /// 서버 id — 취소할 때 쓴다. 아직 안 보낸 신청은 null.
  final String? id;

  /// 시작일 (하루짜리면 [endDate]와 같다)
  final DateTime date;
  final DateTime endDate;

  final _LeaveKind kind;
  final String reason;

  /// 차감 일수 — 서버가 계산해 준 값을 그대로 쓴다
  final double days;

  _LeaveStatus status;

  /// 이 날짜가 신청 기간에 걸리는지 — 여러 날짜리 신청도 달력에 칠해야 한다
  bool covers(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final from = DateTime(date.year, date.month, date.day);
    final to = DateTime(endDate.year, endDate.month, endDate.day);
    return !target.isBefore(from) && !target.isAfter(to);
  }
}

/// 연차 부여·사용·잔여 — 서버가 입사일 기준으로 산정해 준다
LeaveBalance? _balance;

double get _grantedLeave => _balance?.granted ?? 0;

/// 사용 일수 — 승인분에 대기 중인 신청까지 포함한 서버 기준
double get _usedLeave => _balance?.used ?? 0;

double get _remainingLeave => _balance?.remaining ?? 0;

/// 근태 기록 — 탭을 오가도 유지되도록 모듈 전역으로 둔다.
/// 서버에서 받아 채운다 ([_loadAttendance]).
final _days = <_Day>[];

final _leaves = <_Leave>[];

/// 결재를 기다리는 월차 신청 — 결재함을 볼 수 있는 사람에게만 채워진다.
/// 승인 화면을 따로 두지 않고 '남은 월차' 카드 안에서 바로 처리한다.
final _leaveInbox = <LeaveRequest>[];

/// 대표가 보는 오늘 현황의 재료 — 전 직원 명단
///
/// `Employee.todayStatus` 에 오늘 판정이 얹혀 온다 (지각·결근·야근·월차·휴무).
/// 사람마다 캘린더를 부르지 않아도 되게 서버가 명단에 실어 준다.
final _todayStaff = <Employee>[];

/// 근태·월차를 서버에서 받아 온다
///
/// 달력이 앞뒤 달을 넘겨볼 수 있어야 해서 이번 달과 지난달을 같이 받는다.
/// 월차는 기간 필터가 없어 통째로 받아 둔다.
Future<void> _loadAttendance() async {
  final now = DateTime.now();

  final days = <AttendanceDay>[
    ...await AttendanceApi.calendar(
      month: _monthKey(DateTime(now.year, now.month - 1)),
    ),
    ...await AttendanceApi.calendar(month: _monthKey(now)),
  ];
  final leaves = await AttendanceApi.leaves(employeeId: currentUser?.id);
  final balance = await AttendanceApi.balance();
  // 남이 낸 신청은 결재할 수 있는 사람만 받는다 (지점 제한은 서버가 건다)
  final inbox = _canSeeLeaveInbox
      ? await AttendanceApi.leaves(status: LeaveStatus.pending)
      : const <LeaveRequest>[];
  // 대표 화면의 '오늘 근무' 판 — 명단에 오늘 판정이 얹혀 온다
  final staff = myRole == Role.master
      ? await StaffApi.list()
      : const <Employee>[];

  _balance = balance;

  _leaves
    ..clear()
    ..addAll(leaves.map(_Leave.from));

  _leaveInbox
    ..clear()
    ..addAll(inbox);

  _days
    ..clear()
    ..addAll(days.map(_Day.from));

  _todayStaff
    ..clear()
    ..addAll(staff);
}

/// 오늘 이 상태인 사람들 — 대표 화면의 '오늘 근무' 판이 쓴다
///
/// [status] 가 null 이면 **미출근**이다 (근무일인데 아직 스캔이 없음).
/// 퇴근 시간이 지나면 서버가 결근으로 바꿔 주므로 여기서 판정하지 않는다.
///
/// 다만 **근무 요일을 설정 안 한 사람도 null** 로 온다 — 서버가 근무일인지를
/// 몰라 판정을 못 하는 것이라 미출근이 아니다. 그 사람들은 빼고 센다
/// (안 빼면 설정 안 한 사람들이 매일 미출근으로 줄줄이 뜬다).
List<Employee> _todayWith(AttendanceStatus? status) => [
  for (final person in _todayStaff)
    if (person.todayStatus == status &&
        (status != null || person.workDays.isNotEmpty))
      person,
];

/// `2026-07`
String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

/// 소수점이 있을 때만 .5를 보여준다 (8일 / 8.5일)
String _dayCount(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toString();

/// '8시간 12분' 형태
String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}

/// 달력 칸에 들어갈 짧은 근무 시간 — '8:08'
String _shortDuration(Duration value) =>
    '${value.inHours}:${(value.inMinutes % 60).toString().padLeft(2, '0')}';

/// '09:02' 형태
String _clock(DateTime? time) => time == null
    ? '--:--'
    : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

String _weekday(DateTime date) => _weekdayLabels[date.weekday % 7];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
