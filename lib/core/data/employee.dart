import 'dart:ui' show Color;

import '../api/api_client.dart' show apiBaseUrl;
import 'attendance_status.dart';

/// 권한 — 서버 `Role` 과 같은 값. MASTER > ADMIN > MANAGER > MEMBER
///
/// **화면에도 영어 그대로 쓴다.** 예전에는 '대표·관리자·점장·직원'으로 옮겼는데,
/// 권한과 직급([Rank])이 따로 있어서 한국어로 쓰면 둘이 헷갈린다 —
/// 권한 `MANAGER` 인 사람의 직급이 '점장'이 아닐 수도 있다.
///
/// **선언 순서가 곧 정렬 순서다** (높은 권한부터).
enum Role {
  master('MASTER', 'MASTER'),
  admin('ADMIN', 'ADMIN'),
  manager('MANAGER', 'MANAGER'),
  member('MEMBER', 'MEMBER');

  const Role(this.wire, this.label);

  final String wire;
  final String label;

  static Role parse(String? value) =>
      Role.values.firstWhere((r) => r.wire == value, orElse: () => Role.member);

  /// 관리 작업(직원·지점·점수 부여)을 할 수 있는가
  bool get strong => this != Role.member;

  /// 승인·반려를 실행할 수 있는가 — ADMIN 은 보기만 된다
  bool get canApprove => this == Role.master || this == Role.manager;

  /// 남에게 기여 점수를 줄 수 있는가 (마스터~매니저)
  bool get canGrant => strong;

  /// 현장 업무를 하는 사람인가 — 직원과 점장
  ///
  /// 세션 싸인·환경정비·동료 평가를 남길 수 있고, 동료 평가의 대상도 된다.
  /// 대표·관리자는 운영 전담이라 서버가 이 셋을 막는다.
  bool get doesFieldWork => this == Role.member || this == Role.manager;
}

/// 직급 — 서버 `Rank` 와 같은 값
///
/// **순서가 곧 조직 순서다** (위에서 아래로). 조직도 직급 칩이 이 차례로 선다.
/// 서버 `app/enums.py` 는 반대로(트레이너부터) 적혀 있지만 그건 저장 값일 뿐이라
/// 화면 순서는 여기서 정한다.
///
/// **`marketer` 는 아직 서버에 없다** (backend-gap.md 8번). 서버가 안 주므로
/// 지금은 아무도 이 직급이 아니고, 조직도 칩에 `마케터 0` 으로 뜬다.
/// **읽기 전용이라 문제는 없지만, 서버에 추가되기 전까지 아무도 배정할 수 없다.**
enum Rank {
  ceo('CEO', '대표'),
  developer('DEVELOPER', '개발자'),
  marketer('MARKETER', '마케터'),
  storeManager('STORE_MANAGER', '점장'),
  teamLead('TEAM_LEAD', '팀장'),
  trainer('TRAINER', '트레이너'),
  fc('FC', 'FC');

  const Rank(this.wire, this.label);

  final String wire;
  final String label;

  static Rank parse(String? value) => Rank.values.firstWhere(
    (r) => r.wire == value,
    orElse: () => Rank.trainer,
  );
}

/// 재직 상태 — 서버 `EmployeeStatus` 와 같은 값
///
/// `INACTIVE` 는 계정을 잠가 둔 사람이다. 예전 앱은 이 자리를 '가입 승인 대기'로
/// 썼는데 **서버가 승인 대기를 폐지**했다 (backend-gap.md 11번).
enum EmployeeStatus {
  active('ACTIVE', '재직자'),
  inactive('INACTIVE', '비활성'),
  resigned('RESIGNED', '퇴사자');

  const EmployeeStatus(this.wire, this.label);

  final String wire;
  final String label;

  static EmployeeStatus parse(String? value) => EmployeeStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => EmployeeStatus.active);
}

/// 스스로 바꾸는 업무 상태 — 서버 `WorkStatus` 와 같은 값
///
/// '근무중'·'오프라인'은 출퇴근 기록에서 서버가 정하는 값이라 여기 없다.
/// [auto] 를 고르면 그 자동 판정을 따른다.
enum WorkStatus {
  auto('AUTO', '자동 (출근 기준)', '🔄'),
  meeting('MEETING', '회의중', '💼'),
  meal('MEAL', '식사', '🍽️'),
  out('OUT', '외출', '🚶'),
  away('AWAY', '자리비움', '💤');

  const WorkStatus(this.wire, this.label, this.emoji);

  final String wire;
  final String label;
  final String emoji;

  static WorkStatus parse(String? value) => WorkStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => WorkStatus.auto,
  );
}

/// 로그인한 직원 (서버 `EmployeeOut`)
class Employee {
  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.branchId,
    required this.rank,
    required this.role,
    required this.avatarColor,
    this.phone,
    this.empNo,
    this.team,
    this.avatarUrl,
    this.statusMessage,
    this.workStatus = WorkStatus.auto,
    this.status = EmployeeStatus.active,
    this.joinedAt,
    this.resignedAt,
    this.lastActiveAt,
    this.todayStatus,
    this.shiftStart,
    this.shiftEnd,
    this.workDays = const [],
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    branchId: json['branchId'] as String,
    rank: Rank.parse(json['rank'] as String?),
    role: Role.parse(json['role'] as String?),
    avatarColor: json['avatarColor'] as String? ?? '#3182F6',
    phone: json['phone'] as String?,
    empNo: json['empNo'] as String?,
    team: json['team'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    statusMessage: json['statusMessage'] as String?,
    workStatus: WorkStatus.parse(json['workStatus'] as String?),
    status: EmployeeStatus.parse(json['status'] as String?),
    joinedAt: _date(json['joinedAt']),
    resignedAt: _date(json['resignedAt']),
    lastActiveAt: _date(json['lastActiveAt']),
    todayStatus: AttendanceStatus.parseOrNull(
      json['todayAttendanceStatus'] as String?,
    ),
    workDays: [
      for (final day in (json['workDays'] as List<dynamic>? ?? const []))
        day as int,
    ],
    shiftStart: json['shiftStart'] as String?,
    shiftEnd: json['shiftEnd'] as String?,
  );

  final String id;
  final String name;
  final String email;
  final String branchId;
  final Rank rank;
  final Role role;

  /// `#RRGGBB` 꼴 — 아바타 배경색
  final String avatarColor;

  final String? phone;

  /// 사번 {입사연도}-{순번} — 출퇴근 바코드가 이 값을 쓴다
  final String? empNo;
  final String? team;

  /// 프로필 사진 — 서버가 **서명이 붙은 상대 경로**(`/files/...?exp&sig`)로 준다.
  /// 그대로는 못 부르고 서버 주소를 앞에 붙여야 한다 ([avatarImageUrl])
  final String? avatarUrl;

  final String? statusMessage;

  /// 스스로 고른 업무 상태 (조직도·사내톡에 보인다)
  final WorkStatus workStatus;

  /// 재직 상태 — 조직도가 재직자·비활성·퇴사자 탭으로 가른다
  final EmployeeStatus status;

  /// 입사일 — 근속 계산에 쓴다
  final DateTime? joinedAt;

  /// 퇴사한 시각 — [status] 가 `RESIGNED` 일 때만 값이 있다
  ///
  /// 복직시키면(다시 `ACTIVE`) 서버가 지운다.
  final DateTime? resignedAt;

  /// 마지막으로 앱을 쓴 시각. **출근 여부가 아니다**
  final DateTime? lastActiveAt;

  /// 오늘 근태 판정 — **null 이면 '출근 전'**
  ///
  /// 서버가 목록에 얹어 준다 (`todayAttendanceStatus`). 근태 화면·홈과 같은
  /// 기준이라 앱이 따로 계산하지 않는다.
  ///
  /// 예전에는 `GET /attendance?month=` 을 받아 앱이 직접 갈랐는데,
  /// 서버가 권한 가드를 걸면서 **MEMBER 는 본인 것만** 오게 됐다
  /// (backend-gap.md 59·60번). 그 길로는 남이 근무 중인지 알 수 없다.
  final AttendanceStatus? todayStatus;

  /// 바로 불러 쓸 수 있는 프로필 사진 주소 — 없으면 null
  String? get avatarImageUrl {
    final path = avatarUrl;
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http') ? path : '$apiBaseUrl$path';
  }

  /// 기본 근무 시간 "HH:MM" — 미설정이면 첫 로그인 때 설정을 받아야 한다
  final String? shiftStart;
  final String? shiftEnd;

  /// 근무 요일 — ISO 기준 1(월) ~ 7(일)
  ///
  /// 결근 판정의 기준이라 이게 없으면 서버가 결근·휴무를 못 가른다.
  final List<int> workDays;

  bool get needsSchedule =>
      shiftStart == null || shiftEnd == null || workDays.isEmpty;

  /// 아바타 색 — 서버가 `#RRGGBB` 로 준다
  ///
  /// 서버 값이 `neutral` 처럼 색이 아닐 수도 있어서 못 읽으면 null 이다.
  /// 그 경우 이름에서 색을 만들어 쓴다 (`staff.dart`의 `staffOf` 참고).
  Color? get color {
    final hex = avatarColor.replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
