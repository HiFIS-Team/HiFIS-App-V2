import 'dart:ui' show Color;

import '../api/client/api_client.dart' show apiBaseUrl;
import 'attendance_status.dart';

/// 권한 — 서버 `Role` 과 같은 값. MASTER > ADMIN > MANAGER > MEMBER
///
/// **화면에도 영어 그대로 쓴다.** 예전에는 '대표·관리자·점장·직원'으로 옮겼는데,
/// 권한과 직군([Rank])이 따로 있어서 한국어로 쓰면 둘이 헷갈린다 —
/// 권한 `MANAGER` 인 사람의 직군이 '점장'이 아닐 수도 있다.
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

/// 직군 — 서버 `Rank` 와 같은 값
///
/// **순서가 곧 조직 순서다** (위에서 아래로). 조직도 직군 칩이 이 차례로 선다.
/// 서버 `app/enums.py` 는 반대로(트레이너부터) 적혀 있지만 그건 저장 값일 뿐이라
/// 화면 순서는 여기서 정한다.
///
/// 조직도 **필터 칩**에서는 점장·팀장이 '관리자' 한 칸으로 묶인다
/// (`_RankGroup`). 직군 자체는 갈라져 있어서 초대키·인사 정보 변경에서는
/// 따로 고르고, 카드·상세에도 각자 이름으로 적힌다.
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

/// 고용 형태 — 서버 `EmploymentType` 과 같은 값
///
/// **재직 상태와 다른 축이다.** 알바가 그만두면 `status` 가 퇴사자로 가고
/// 고용 형태는 그대로 남는다. 알바로 시작해 정규직이 되는 경우도 이 값만 바뀐다.
///
/// 급여가 갈린다 — 정규직은 직군별 기본급 + 인센티브, 알바는 **시급만**이다.
enum EmploymentType {
  fullTime('FULL_TIME', '정규직'),
  partTime('PART_TIME', '알바');

  const EmploymentType(this.wire, this.label);

  final String wire;
  final String label;

  static EmploymentType parse(String? value) =>
      EmploymentType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => EmploymentType.fullTime,
      );
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

  /// 좁은 자리용 짧은 이름 — `자동 (출근 기준)` 의 괄호 설명을 뗀다
  ///
  /// 고르개에서는 무슨 뜻인지 알려줘야 해서 긴 [label] 이 맞지만,
  /// 프로필 요약처럼 반쪽 폭인 칸에서는 그대로 두면 줄이 넘어간다.
  String get short => label.split(' (').first;

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
    this.employmentType = EmploymentType.fullTime,
    this.joinedAt,
    this.resignedAt,
    this.lastActiveAt,
    this.firstLoginAt,
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
    employmentType: EmploymentType.parse(json['employmentType'] as String?),
    joinedAt: _date(json['joinedAt']),
    resignedAt: _date(json['resignedAt']),
    lastActiveAt: _date(json['lastActiveAt']),
    firstLoginAt: _date(json['firstLoginAt']),
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

  /// 재직 상태 — 조직도가 재직자·퇴사자로 가른다
  final EmployeeStatus status;

  /// 정규직인가 알바인가 — 조직도 가운데 탭과 급여 계산이 이 값을 본다
  final EmploymentType employmentType;

  /// 가입한 시각 — 계정을 만든 때다 (프로필 상세의 '가입일')
  final DateTime? joinedAt;

  /// 퇴사한 시각 — [status] 가 `RESIGNED` 일 때만 값이 있다
  ///
  /// 복직시키면(다시 `ACTIVE`) 서버가 지운다.
  final DateTime? resignedAt;

  /// 마지막으로 앱을 쓴 시각. **출근 여부가 아니다**
  final DateTime? lastActiveAt;

  /// 처음 로그인한 시각 — null 이면 **가입만 하고 아직 안 들어온 사람**이다
  ///
  /// 서버가 첫 로그인에 한 번 찍고 그 뒤로는 안 바꾼다. 이 컬럼이 생기기 전에
  /// 들어온 사람은 접속 기록에서 채웠는데, 그 기록은 90일 뒤 파기되므로
  /// 그보다 오래된 사람은 비어 있다.
  final DateTime? firstLoginAt;

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

  /// 첫 로그인에 근무 설정을 받아야 하는가
  ///
  /// **대표·관리자는 안 받는다** (2026-08-11 대표 결정). 출퇴근을 안 찍으니
  /// 기준이 있어도 쓸 데가 없다 — 근태 판정에서도 이미 빠져 있다
  /// (전사 캘린더·결근 알림, backend-gap 70번).
  bool get needsSchedule =>
      role != Role.master &&
      role != Role.admin &&
      (shiftStart == null || shiftEnd == null || workDays.isEmpty);

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
