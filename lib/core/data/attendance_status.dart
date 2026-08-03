/// 하루 근태 판정 — 서버 `AttendanceStatus`
///
/// 기록이 없는 날(결근·휴무)까지 서버가 판정해 준다. 급여·평가가 같은 기준을
/// 쓰므로 앱이 따로 계산하지 않는다.
///
/// 근태 화면(`AttendanceDay`)과 직원 명단(`Employee.todayStatus`)이 같이 쓴다.
/// 두 곳이 서로를 import 하지 않도록 여기에 따로 뒀다.
library;

enum AttendanceStatus {
  normal('NORMAL'),
  late('LATE'),
  earlyLeave('EARLY_LEAVE'),
  lateAndEarly('LATE_AND_EARLY'),
  inProgress('IN_PROGRESS'),
  noCheckout('NO_CHECKOUT'),
  absent('ABSENT'),
  onLeave('ON_LEAVE'),
  dayOff('DAY_OFF'),
  unknown('UNKNOWN');

  const AttendanceStatus(this.wire);

  final String wire;

  static AttendanceStatus parse(String? value) =>
      AttendanceStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AttendanceStatus.unknown,
      );

  /// 값이 없으면 **null 을 그대로 돌려준다**
  ///
  /// 오늘 판정에서 null 은 '출근 전'이다 — 오늘은 아직 안 끝나서 결근을 못 찍는다.
  /// [parse] 처럼 `unknown` 으로 떨어뜨리면 출근 전과 판정불가가 섞인다.
  static AttendanceStatus? parseOrNull(String? value) =>
      value == null ? null : parse(value);

  /// 지금 근무 중인가 — 출근했고 아직 퇴근을 안 찍었다
  bool get working =>
      this == AttendanceStatus.inProgress ||
      this == AttendanceStatus.noCheckout;
}
