import '../../data/attendance_status.dart';
import '../../data/employee.dart';
import '../client/api_client.dart';

// 근태 판정은 직원 명단(`Employee.todayStatus`)도 쓴다 — 서로 import 하지
// 않도록 `data/attendance_status.dart` 로 빼 두고 여기서 다시 내보낸다.
export '../../data/attendance_status.dart';

/// 휴가 종류 — 서버 `LeaveType`
///
/// 앱 화면은 '월차'만 다루지만 서버는 병가·외근까지 한 테이블에 담는다.
/// 오전/오후 반차 구분은 서버에 없다 (backend-gap.md 15번).
enum LeaveType {
  annual('ANNUAL', '연차'),
  half('HALF', '반차'),
  sick('SICK', '병가'),
  field('FIELD', '외근'),
  etc('ETC', '기타');

  const LeaveType(this.wire, this.label);

  final String wire;
  final String label;

  static LeaveType parse(String? value) => LeaveType.values.firstWhere(
    (t) => t.wire == value,
    orElse: () => LeaveType.annual,
  );

  /// 차감되는 일수 — 반차만 0.5, 나머지는 날짜 수만큼
  double get dayValue => this == LeaveType.half ? 0.5 : 1.0;
}

/// 반차 시간대 — 서버 `HalfPeriod`. `LeaveType.half` 일 때만 의미가 있다.
enum HalfPeriod {
  am('AM', '오전 반차'),
  pm('PM', '오후 반차');

  const HalfPeriod(this.wire, this.label);

  final String wire;
  final String label;

  static HalfPeriod? parse(String? value) => value == null
      ? null
      : HalfPeriod.values.firstWhere(
          (p) => p.wire == value,
          orElse: () => HalfPeriod.am,
        );
}

/// 캘린더 하루 (서버 `AttendanceDayOut`)
class AttendanceDay {
  AttendanceDay({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workMinutes,
    this.leaveType,
    this.halfPeriod,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
    date: DateTime.parse(json['date'] as String),
    status: AttendanceStatus.parse(json['status'] as String?),
    checkIn: _localTime(json['checkIn'] as String?),
    checkOut: _localTime(json['checkOut'] as String?),
    workMinutes: json['workMinutes'] as int?,
    leaveType: json['leaveType'] == null
        ? null
        : LeaveType.parse(json['leaveType'] as String?),
    halfPeriod: HalfPeriod.parse(json['halfPeriod'] as String?),
  );

  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? workMinutes;

  /// 휴가인 날만 채워진다
  final LeaveType? leaveType;
  final HalfPeriod? halfPeriod;
}

/// 전사 캘린더 하루 (서버 `AttendanceRosterDayOut`)
///
/// 하루마다 **누가 어떤 상태였는지**를 상태별로 묶어 준다. 사람별 캘린더를
/// 인원수만큼 부르지 않으려고 서버가 한 번에 준다.
class AttendanceRosterDay {
  AttendanceRosterDay({required this.date, required this.groups});

  factory AttendanceRosterDay.fromJson(Map<String, dynamic> json) =>
      AttendanceRosterDay(
        date: DateTime.parse(json['date'] as String),
        groups: {
          for (final group in (json['groups'] as List<dynamic>? ?? const []))
            AttendanceStatus.parse((group as Map)['status'] as String?): [
              for (final name in (group['names'] as List<dynamic>? ?? const []))
                name as String,
            ],
        },
      );

  final DateTime date;

  /// 상태 → 그 상태였던 사람 이름들. 휴무·판정불가는 서버가 안 담는다.
  final Map<AttendanceStatus, List<String>> groups;
}

/// 연차 부여·사용·잔여 (서버 `LeaveBalanceOut`)
class LeaveBalance {
  LeaveBalance({
    required this.granted,
    required this.used,
    required this.remaining,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) => LeaveBalance(
    granted: (json['granted'] as num).toDouble(),
    used: (json['used'] as num).toDouble(),
    remaining: (json['remaining'] as num).toDouble(),
  );

  /// 입사일 기준 근로기준법 산정 일수
  final double granted;

  /// 승인 + 대기 중인 신청까지 합친 확정 일수
  final double used;
  final double remaining;
}

/// 휴가 신청 상태 — 서버 `LeaveStatus`
enum LeaveStatus {
  pending('PENDING', '대기'),
  approved('APPROVED', '승인'),
  rejected('REJECTED', '반려'),
  cancelled('CANCELLED', '취소');

  const LeaveStatus(this.wire, this.label);

  final String wire;
  final String label;

  static LeaveStatus parse(String? value) => LeaveStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => LeaveStatus.pending,
  );
}

/// 하루치 출퇴근 기록 (서버 `AttendanceOut`)
///
/// 서버는 찍힌 시각만 준다. 지각·결근 판정은 각자의 근무 시간과 비교해야
/// 나오므로 앱에서 계산한다.
class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.workMinutes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        date: DateTime.parse(json['date'] as String),
        checkIn: _localTime(json['checkIn'] as String?),
        checkOut: _localTime(json['checkOut'] as String?),
        workMinutes: json['workMinutes'] as int?,
      );

  final String id;
  final String employeeId;

  /// 근무일 (KST 기준으로 서버가 끊어 준다)
  final DateTime date;

  final DateTime? checkIn;
  final DateTime? checkOut;

  /// 서버가 계산한 근무 분 — 휴게 시간은 빠져 있지 않다
  final int? workMinutes;
}

/// 휴가 신청 한 건 (서버 `LeaveRequestOut`)
class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.halfPeriod,
    this.reason,
    this.rejectReason,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    type: LeaveType.parse(json['type'] as String?),
    halfPeriod: HalfPeriod.parse(json['halfPeriod'] as String?),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    days: (json['days'] as num).toDouble(),
    status: LeaveStatus.parse(json['status'] as String?),
    reason: json['reason'] as String?,
    rejectReason: json['rejectReason'] as String?,
  );

  final String id;
  final String employeeId;
  final LeaveType type;

  /// 반차일 때만 채워진다 (오전/오후)
  final HalfPeriod? halfPeriod;

  final DateTime startDate;
  final DateTime endDate;

  /// 차감 일수 — 서버가 계산해 준다
  final double days;
  final LeaveStatus status;
  final String? reason;
  final String? rejectReason;

  /// 신청자 본인이 취소할 수 있는 상태인지
  bool get cancellable => status == LeaveStatus.pending;
}

/// 서버가 UTC 로 주는 시각을 기기 시간대로 바꾼다
DateTime? _localTime(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();

/// `2026-07-31` — 서버가 날짜만 받는 자리에 쓴다
String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 근태·휴가 API
class AttendanceApi {
  AttendanceApi._();

  static final _client = ApiClient.instance;

  /// 출퇴근 스캔 — 첫 스캔이 출근, 그다음이 퇴근이다.
  ///
  /// [code]에 사번을 주면 지점 스캐너처럼 그 사람 것을 찍고,
  /// 안 주면 로그인한 본인 것을 찍는다.
  static Future<AttendanceRecord> scan({String? code}) async {
    final data = await _client.post('/attendance/scan', body: {'code': ?code});
    return AttendanceRecord.fromJson(data!);
  }

  /// 근태 기록 — [month]는 `2026-07` 꼴
  static Future<List<AttendanceRecord>> list({
    String? employeeId,
    String? month,
  }) async {
    final rows = await _client.getList(
      '/attendance',
      query: {'employeeId': ?employeeId, 'month': ?month},
    );
    return [
      for (final row in rows)
        AttendanceRecord.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 휴가 신청 목록
  ///
  /// [status] 를 주면 그 상태만 (`PENDING` 이면 승인 대기함이 된다).
  static Future<List<LeaveRequest>> leaves({
    String? employeeId,
    LeaveStatus? status,
  }) async {
    final rows = await _client.getList(
      '/leaves',
      query: {'employeeId': ?employeeId, 'status': ?status?.wire},
    );
    return [
      for (final row in rows)
        LeaveRequest.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 전사 월 캘린더 — **MASTER · ADMIN · MANAGER 만** (MANAGER 는 자기 지점)
  ///
  /// [month]는 `2026-08` 꼴. 하루마다 상태별로 누가 그랬는지 이름이 온다.
  static Future<List<AttendanceRosterDay>> roster({
    required String month,
  }) async {
    final rows = await _client.getList(
      '/attendance/calendar/all',
      query: {'month': month},
    );
    return [
      for (final row in rows)
        AttendanceRosterDay.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 휴가 승인 — **MASTER · MANAGER 만** 된다 (ADMIN 은 보기만)
  static Future<LeaveRequest> approveLeave(String id) async {
    final data = await _client.post('/leaves/$id/approve');
    return LeaveRequest.fromJson(data!);
  }

  /// 휴가 반려 — 사유는 신청자에게 알림으로 그대로 간다
  static Future<LeaveRequest> rejectLeave(String id, String reason) async {
    final data = await _client.post(
      '/leaves/$id/reject',
      body: {'reason': reason},
    );
    return LeaveRequest.fromJson(data!);
  }

  /// 월 캘린더 — 하루하루 판정된 상태를 그대로 받는다
  ///
  /// 결근처럼 기록이 없는 날도 서버가 채워 준다. 다만 근무 요일이 설정 안 된
  /// 사람은 결근·휴무를 못 가려서 기록 있는 날만 온다.
  static Future<List<AttendanceDay>> calendar({
    required String month,
    String? employeeId,
  }) async {
    final rows = await _client.getList(
      '/attendance/calendar',
      query: {'month': month, 'employeeId': ?employeeId},
    );
    return [
      for (final row in rows)
        AttendanceDay.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 연차 부여·사용·잔여
  static Future<LeaveBalance> balance({String? employeeId}) async {
    final data = await _client.get(
      '/leaves/balance',
      query: {'employeeId': ?employeeId},
    );
    return LeaveBalance.fromJson(data);
  }

  static Future<LeaveRequest> createLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    HalfPeriod? halfPeriod,
    String? reason,
  }) async {
    final data = await _client.post(
      '/leaves',
      body: {
        'type': type.wire,
        'halfPeriod': ?halfPeriod?.wire,
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'reason': ?reason,
      },
    );
    return LeaveRequest.fromJson(data!);
  }

  /// 근무 시간·근무 요일 설정
  ///
  /// [workDays]는 ISO 요일 1(월)~7(일). 하나 이상 없으면 서버가 422 를 준다.
  /// 근무 시간 중에는 바꿀 수 없다 (403 WITHIN_SHIFT).
  static Future<Employee> setSchedule({
    required String shiftStart,
    required String shiftEnd,
    required List<int> workDays,
  }) async {
    final data = await _client.post(
      '/employees/me/schedule',
      body: {
        'shiftStart': shiftStart,
        'shiftEnd': shiftEnd,
        'workDays': workDays,
      },
    );
    return Employee.fromJson(data!);
  }

  /// 신청자 본인이 대기중인 신청을 물린다 (이력은 남는다)
  static Future<LeaveRequest> cancelLeave(String id) async {
    final data = await _client.post('/leaves/$id/cancel');
    return LeaveRequest.fromJson(data!);
  }
}
