import 'dart:ui' show Color;

/// 권한 — 서버 `Role` 과 같은 값. MASTER > ADMIN > MANAGER > MEMBER
enum Role {
  master('MASTER', '대표'),
  admin('ADMIN', '관리자'),
  manager('MANAGER', '점장'),
  member('MEMBER', '직원');

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
enum Rank {
  trainer('TRAINER', '트레이너'),
  fc('FC', 'FC'),
  teamLead('TEAM_LEAD', '팀장'),
  storeManager('STORE_MANAGER', '점장'),
  developer('DEVELOPER', '개발'),
  ceo('CEO', '대표');

  const Rank(this.wire, this.label);

  final String wire;
  final String label;

  static Rank parse(String? value) => Rank.values.firstWhere(
    (r) => r.wire == value,
    orElse: () => Rank.trainer,
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
  final String? avatarUrl;
  final String? statusMessage;

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
