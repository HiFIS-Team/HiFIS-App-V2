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

/// 정해진 출근 시각 — 이보다 늦으면 지각으로 본다
const _startHour = 9;

/// 정해진 퇴근 시각
const _endHour = 18;

/// 월차 종류
enum _LeaveKind {
  full('종일', 1.0),
  morning('오전 반차', 0.5),
  afternoon('오후 반차', 0.5);

  const _LeaveKind(this.label, this.days);

  final String label;

  /// 차감되는 일수
  final double days;
}

/// 월차 신청 상태
enum _LeaveStatus {
  pending('대기'),
  approved('승인'),
  rejected('반려');

  const _LeaveStatus(this.label);

  final String label;

  Color get color => switch (this) {
    _LeaveStatus.pending => AppColors.warning,
    _LeaveStatus.approved => AppColors.success,
    _LeaveStatus.rejected => AppColors.error,
  };
}

/// 월차 신청 한 건
class _Leave {
  _Leave({
    required this.date,
    required this.kind,
    required this.reason,
    required this.requested,
    this.status = _LeaveStatus.pending,
  });

  final DateTime date;
  final _LeaveKind kind;
  final String reason;

  /// 신청한 시각
  final DateTime requested;

  _LeaveStatus status;
}

/// 올해 부여된 월차 (목업)
const _grantedLeave = 15.0;

/// 근태 기록 — 탭을 오가도 유지되도록 모듈 전역으로 둔다
final _days = <_Day>[..._seedDays()];

final _leaves = <_Leave>[..._seedLeaves()];

/// 지난달 전체와 이번 달 오늘까지를 채운다 (달력에서 앞뒤로 넘겨볼 수 있게)
List<_Day> _seedDays() {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  final lastMonthDays = DateTime(now.year, now.month, 0).day;

  return [
    for (var day = 1; day <= lastMonthDays; day++)
      _seedDay(lastMonth.year, lastMonth.month, day),
    for (var day = 1; day <= now.day; day++) _seedDay(now.year, now.month, day),
  ];
}

/// 하루치 목업 기록
///
/// 날짜를 씨앗처럼 써서 값을 정한다. 난수를 쓰면 화면을 다시 그릴 때마다
/// 기록이 바뀌어 버린다.
_Day _seedDay(int year, int month, int day) {
  final date = DateTime(year, month, day);

  if (date.weekday == DateTime.sunday) {
    return _Day(date: date, status: _DayStatus.off);
  }
  if (day == 11) return _Day(date: date, status: _DayStatus.leave);
  if (day == 18) return _Day(date: date, status: _DayStatus.absent);

  final late = (day + month) % 9 == 4;
  final early = (day + month) % 7 == 5;

  return _Day(
    date: date,
    status: late
        ? _DayStatus.late
        : early
        ? _DayStatus.early
        : _DayStatus.normal,
    checkIn: DateTime(year, month, day, _startHour, late ? 24 : (day % 5) * 2),
    checkOut: DateTime(
      year,
      month,
      day,
      early ? _endHour - 1 : _endHour,
      early ? 40 : 5 + (day % 4) * 7,
    ),
  );
}

List<_Leave> _seedLeaves() {
  final now = DateTime.now();
  DateTime at(int daysAgo) =>
      DateTime(now.year, now.month, now.day - daysAgo, 10, 0);

  return [
    _Leave(
      date: DateTime(now.year, now.month, now.day + 9),
      kind: _LeaveKind.full,
      reason: '가족 행사 참석',
      requested: at(1),
    ),
    _Leave(
      date: DateTime(now.year, now.month, now.day + 3),
      kind: _LeaveKind.afternoon,
      reason: '병원 진료',
      requested: at(2),
      status: _LeaveStatus.approved,
    ),
    _Leave(
      date: DateTime(now.year, now.month, 11),
      kind: _LeaveKind.full,
      reason: '개인 사유',
      requested: at(20),
      status: _LeaveStatus.approved,
    ),
    _Leave(
      date: DateTime(now.year, now.month - 1, 27),
      kind: _LeaveKind.morning,
      reason: '이사 정리',
      requested: at(38),
      status: _LeaveStatus.rejected,
    ),
  ];
}

/// 승인된 월차만 차감한다 (대기 중인 건 아직 안 쓴 것으로 본다)
double get _usedLeave => _leaves
    .where((l) => l.status == _LeaveStatus.approved)
    .fold(0.0, (sum, l) => sum + l.kind.days);

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
