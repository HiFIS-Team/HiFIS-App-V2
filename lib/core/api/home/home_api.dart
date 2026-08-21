import '../client/api_client.dart';
import '../staff/attendance_api.dart';

export '../staff/attendance_api.dart'
    show AttendanceStatus, HalfPeriod, LeaveType;
export '../client/period.dart' show periodKey;

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

/// 결재함 한 줄의 출처 — 승인·반려를 어느 API 로 보낼지 가른다
enum InboxKind {
  payslip('PAYSLIP'),
  leave('LEAVE'),
  approval('APPROVAL'),
  event('EVENT'),
  myTask('MY_TASK'),
  project('PROJECT'),

  /// 개인 업무 **누락 사유서** — 주소가 달라서 [myTask] 와 따로다 (2026-08-21)
  taskMiss('TASK_MISS');

  const InboxKind(this.wire);

  final String wire;

  static InboxKind parse(String? value) => InboxKind.values.firstWhere(
    (k) => k.wire == value,
    orElse: () => InboxKind.approval,
  );
}

/// 결재함의 세 칸 (서버 `InboxStatus`) — 앱 결재 화면의 `대기 · 승인 · 반려` 탭
///
/// **종류마다 상태 이름이 다르다** (급여 `SUBMITTED`, 전자결재 `IN_PROGRESS` …).
/// 어느 상태가 어느 칸에 드는지는 서버가 알고, 앱은 이 셋으로만 묻는다.
enum InboxStatus {
  pending('PENDING', '대기'),
  approved('APPROVED', '승인'),

  /// 본인이 물린 것(월차 취소·결재 회수)도 여기 온다 — 전자결재 화면이
  /// 회수를 반려 탭에 두는 것과 같은 규칙이다
  rejected('REJECTED', '반려');

  const InboxStatus(this.wire, this.label);

  final String wire;
  final String label;
}

/// 결재를 기다리는 것 한 줄 (서버 `InboxItemOut`)
///
/// **MASTER · ADMIN 에게만 온다.** 급여·월차·전자결재가 테이블은 따로인데
/// 홈 카드에서는 한 목록으로 서므로 서버가 합쳐서 준다.
class InboxItem {
  InboxItem({
    required this.kind,
    required this.id,
    required this.employeeId,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    kind: InboxKind.parse(json['kind'] as String?),
    id: json['id'] as String,
    employeeId: json['employeeId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final InboxKind kind;

  /// 승인·반려 엔드포인트에 넘길 id — 종류마다 다른 테이블의 것이다
  final String id;

  /// 올린 사람
  final String employeeId;

  /// `2026년 7월 급여` · `연차` · `외근·출장` — **서버가 만들어 준다**
  final String title;

  /// `실수령 2,340,000원` · `8.12 ~ 8.14 · 3일`
  final String detail;

  final DateTime createdAt;
}

/// 홈 첫 화면 요약 (서버 `HomeSummaryOut`)
class HomeSummary {
  HomeSummary({
    required this.period,
    required this.attendance,
    required this.incompleteProjects,
    required this.unreadNotices,
    required this.monthScore,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
    period: json['period'] as String,
    attendance: HomeAttendance.fromJson(
      (json['todayAttendance'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    incompleteProjects: json['incompleteProjects'] as int? ?? 0,
    unreadNotices: json['unreadNotices'] as int? ?? 0,
    monthScore: json['monthScore'] as int? ?? 0,
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

  /// 결재 목록 — **MASTER · ADMIN 만** (그 외는 403)
  ///
  /// 대기는 **오래 묵은 것부터**(먼저 처리돼야 한다), 처리된 것은
  /// **최근 것부터** 온다.
  ///
  /// **일정 반려는 안 온다** — 서버가 반려할 때 행을 지운다.
  /// 승인된 일정도 결재를 거친 것만 온다 (대표가 올려 바로 선 일정은 빠진다).
  static Future<List<InboxItem>> inbox({
    InboxStatus status = InboxStatus.pending,
  }) async {
    final rows = await _client.getList(
      '/me/inbox',
      query: {'status': status.wire},
    );
    return [
      for (final row in rows)
        InboxItem.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}

/// 서버가 UTC 로 주는 시각을 기기 시간대로 바꾼다
DateTime? _localTime(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
