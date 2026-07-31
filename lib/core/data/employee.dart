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

  bool get needsSchedule => shiftStart == null || shiftEnd == null;
}
