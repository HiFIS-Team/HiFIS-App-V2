import 'api_client.dart';

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
    this.reason,
    this.rejectReason,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    type: LeaveType.parse(json['type'] as String?),
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

  static Future<List<LeaveRequest>> leaves({String? employeeId}) async {
    final rows = await _client.getList(
      '/leaves',
      query: {'employeeId': ?employeeId},
    );
    return [
      for (final row in rows)
        LeaveRequest.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<LeaveRequest> createLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final data = await _client.post(
      '/leaves',
      body: {
        'type': type.wire,
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'reason': ?reason,
      },
    );
    return LeaveRequest.fromJson(data!);
  }

  /// 신청자 본인이 대기중인 신청을 물린다 (이력은 남는다)
  static Future<LeaveRequest> cancelLeave(String id) async {
    final data = await _client.post('/leaves/$id/cancel');
    return LeaveRequest.fromJson(data!);
  }
}
