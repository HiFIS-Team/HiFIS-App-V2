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
}

/// 하루치 근태 기록
class _Day {
  _Day({required this.date, required this.status, this.checkIn, this.checkOut});

  /// 서버 기록에서 만든다
  ///
  /// 서버는 찍힌 시각만 주고 지각·조기퇴근 판정은 안 한다. 기준이 사람마다
  /// 다르기 때문(각자의 `shiftStart`/`shiftEnd`)이라 여기서 계산한다.
  /// 근무 시간이 설정 안 된 사람은 기본값 9~18시로 본다.
  factory _Day.from(AttendanceRecord record) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;

    // 기록은 있는데 출근 시각이 없으면 판단할 근거가 없다
    if (checkIn == null) {
      return _Day(date: record.date, status: _DayStatus.off);
    }

    final start = _shiftMinutes(currentUser?.shiftStart, _startHour);
    final end = _shiftMinutes(currentUser?.shiftEnd, _endHour);
    final inMinutes = checkIn.hour * 60 + checkIn.minute;

    var status = _DayStatus.normal;
    if (inMinutes > start) {
      status = _DayStatus.late;
    } else if (checkOut != null && checkOut.hour * 60 + checkOut.minute < end) {
      status = _DayStatus.early;
    }

    return _Day(
      date: record.date,
      status: status,
      checkIn: checkIn,
      checkOut: checkOut,
    );
  }

  final DateTime date;
  final _DayStatus status;

  /// 출근·퇴근 시각 (쉬는 날은 null)
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// 실제 근무 시간 — 휴게 1시간을 뺀다
  Duration get worked {
    if (checkIn == null || checkOut == null) return Duration.zero;
    final gap = checkOut!.difference(checkIn!);
    return gap > _breakTime ? gap - _breakTime : gap;
  }
}

/// 점심 휴게 시간 (근무 시간에서 제외한다)
const _breakTime = Duration(hours: 1);

/// 근무 시간이 설정 안 된 사람에게 쓰는 기본 출근 시각
const _startHour = 9;

/// 기본 퇴근 시각
const _endHour = 18;

/// 서버가 주는 `"HH:MM"` 을 분으로 바꾼다 (없거나 깨졌으면 기본 시각)
int _shiftMinutes(String? value, int fallbackHour) {
  final parts = value?.split(':');
  if (parts == null || parts.length != 2) return fallbackHour * 60;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return fallbackHour * 60;
  return hour * 60 + minute;
}

/// 월차 종류
///
/// 서버는 반차를 `HALF` 하나로만 받아서 오전·오후를 구분하지 못한다.
/// 화면에서는 골라도 서버에 가면 같은 값이 되고, 다시 받아오면 '오전 반차'로
/// 떨어진다 (backend-gap.md 15번).
enum _LeaveKind {
  full('종일', 1.0, LeaveType.annual),
  morning('오전 반차', 0.5, LeaveType.half),
  afternoon('오후 반차', 0.5, LeaveType.half);

  const _LeaveKind(this.label, this.days, this.type);

  final String label;

  /// 차감되는 일수
  final double days;

  /// 서버에 보낼 값
  final LeaveType type;

  static _LeaveKind of(LeaveType type) =>
      type == LeaveType.half ? _LeaveKind.morning : _LeaveKind.full;
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
    kind: _LeaveKind.of(request.type),
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

/// 올해 부여된 월차
///
/// 서버에 연차 부여 일수를 주는 자리가 없어 아직 고정값이다
/// (backend-gap.md 16번).
const _grantedLeave = 15.0;

/// 근태 기록 — 탭을 오가도 유지되도록 모듈 전역으로 둔다.
/// 서버에서 받아 채운다 ([_loadAttendance]).
final _days = <_Day>[];

final _leaves = <_Leave>[];

/// 근태·월차를 서버에서 받아 온다
///
/// 달력이 앞뒤 달을 넘겨볼 수 있어야 해서 이번 달과 지난달을 같이 받는다.
/// 월차는 기간 필터가 없어 통째로 받아 둔다.
Future<void> _loadAttendance() async {
  final now = DateTime.now();
  final thisMonth = _monthKey(now);
  final lastMonth = _monthKey(DateTime(now.year, now.month - 1));

  final records = <AttendanceRecord>[
    ...await AttendanceApi.list(month: lastMonth, employeeId: currentUser?.id),
    ...await AttendanceApi.list(month: thisMonth, employeeId: currentUser?.id),
  ];
  final leaves = await AttendanceApi.leaves(employeeId: currentUser?.id);

  _leaves
    ..clear()
    ..addAll(leaves.map(_Leave.from));

  _days
    ..clear()
    ..addAll([for (final record in records) _Day.from(record)]);
}

/// `2026-07`
String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

/// 승인된 월차만 차감한다 (대기 중인 건 아직 안 쓴 것으로 본다)
double get _usedLeave => _leaves
    .where((l) => l.status == _LeaveStatus.approved)
    .fold(0.0, (sum, l) => sum + l.days);

double get _remainingLeave => _grantedLeave - _usedLeave;

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
