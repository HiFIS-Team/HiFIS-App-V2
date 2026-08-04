import 'api_client.dart';
import 'attendance_api.dart';

export 'attendance_api.dart' show AttendanceStatus, HalfPeriod, LeaveType;
export 'period.dart' show periodKey;

/// 홈의 오늘 근태 (서버 `HomeAttendanceOut`)
///
/// 근태 화면의 `AttendanceDay` 와 같은 판정을 쓰되 날짜가 없다 — 늘 오늘이다.
class HomeAttendance {
  HomeAttendance({
    this.status,
    this.checkIn,
    this.checkOut,
    this.workMinutes,
    this.leaveType,
    this.halfPeriod,
  });

  factory HomeAttendance.fromJson(Map<String, dynamic> json) => HomeAttendance(
    status: json['status'] == null
        ? null
        : AttendanceStatus.parse(json['status'] as String?),
    checkIn: _localTime(json['checkIn'] as String?),
    checkOut: _localTime(json['checkOut'] as String?),
    workMinutes: json['workMinutes'] as int?,
    leaveType: json['leaveType'] == null
        ? null
        : LeaveType.parse(json['leaveType'] as String?),
    halfPeriod: HalfPeriod.parse(json['halfPeriod'] as String?),
  );

  /// **비어 있으면 아직 출근 전이다.** 근무일인데 기록이 없는 상태로,
  /// 서버는 오늘을 결근으로 찍지 않는다 (하루가 끝나야 알 수 있으므로).
  final AttendanceStatus? status;

  final DateTime? checkIn;
  final DateTime? checkOut;

  /// 서버가 계산한 근무 분 — 퇴근을 찍어야 채워진다
  final int? workMinutes;

  /// 휴가인 날만 채워진다
  final LeaveType? leaveType;
  final HalfPeriod? halfPeriod;
}

/// 결재를 기다리는 것 (서버 `HomePendingOut`)
///
/// **MASTER · ADMIN 에게만 온다.** 대표·관리자는 출근을 안 해서 홈의 출퇴근
/// 카드가 늘 비어 있다. 그 자리에 '지금 눌러야 할 것'을 대신 놓는다.
class HomePending {
  HomePending({
    required this.approvals,
    required this.payslips,
    required this.leaves,
  });

  factory HomePending.fromJson(Map<String, dynamic> json) => HomePending(
    approvals: json['approvals'] as int? ?? 0,
    payslips: json['payslips'] as int? ?? 0,
    leaves: json['leaves'] as int? ?? 0,
  );

  /// 아직 안 끝난 전자결재
  final int approvals;

  /// 제출된 급여
  final int payslips;

  /// 대기 중인 월차
  final int leaves;

  int get total => approvals + payslips + leaves;
}

/// 홈 첫 화면 요약 (서버 `HomeSummaryOut`)
class HomeSummary {
  HomeSummary({
    required this.period,
    required this.attendance,
    required this.incompleteProjects,
    required this.unreadNotices,
    required this.monthScore,
    this.pending,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
    period: json['period'] as String,
    attendance: HomeAttendance.fromJson(
      (json['todayAttendance'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    incompleteProjects: json['incompleteProjects'] as int? ?? 0,
    unreadNotices: json['unreadNotices'] as int? ?? 0,
    monthScore: json['monthScore'] as int? ?? 0,
    pending: switch (json['pending']) {
      final Map row => HomePending.fromJson(row.cast<String, dynamic>()),
      _ => null,
    },
  );

  /// `2026-07` — 이번 달
  final String period;

  final HomeAttendance attendance;

  /// 내가 담당인 미완료 프로젝트 수
  final int incompleteProjects;

  /// 안 읽은 공지 수
  final int unreadNotices;

  /// 이번 달 내 점수 합 (점수 원장 전 항목)
  final int monthScore;

  /// MASTER·ADMIN 이 아니면 null — 나머지 직원 홈은 모양이 그대로다
  final HomePending? pending;
}

/// `/me/home` — 개인 홈 요약
///
/// 지점 집계인 `/dashboard` 와 다르다. 그쪽은 관리자·점장만 볼 수 있고
/// 내용도 지점 전체 합계라, 모든 직원이 보는 첫 화면에는 쓸 수 없다.
class HomeApi {
  HomeApi._();

  static final _client = ApiClient.instance;

  /// 권한 없이 본인 것만 온다
  static Future<HomeSummary> summary() async {
    final data = await _client.get('/me/home');
    return HomeSummary.fromJson(data);
  }
}

/// 서버가 UTC 로 주는 시각을 기기 시간대로 바꾼다
DateTime? _localTime(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
