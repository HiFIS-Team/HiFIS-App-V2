part of 'staff_screen.dart';

/// 지금 무엇을 하고 있는지 — 내 프로필의 '업무 상태'가 여기에 그대로 보인다
enum _Status {
  working('근무중'),
  meeting('회의중'),
  meal('식사'),
  out('외출'),
  away('자리비움'),
  leave('월차'),
  off('퇴근');

  const _Status(this.label);

  final String label;

  Color get color => switch (this) {
    _Status.working => AppColors.success,
    _Status.meeting => AppColors.primary,
    _Status.meal || _Status.out => AppColors.warning,
    _Status.away => AppColors.gray400,
    _Status.leave => AppColors.primary,
    _Status.off => AppColors.gray300,
  };

  /// 지금 지점에 나와 있는 상태
  bool get present => this == _Status.working || this == _Status.meeting;

  /// 나왔지만 자리를 비운 상태
  bool get stepped =>
      this == _Status.meal || this == _Status.out || this == _Status.away;
}

/// 시스템 권한 — 사람을 찾는 기준이 아니라서 필터로 쓰지 않고 배지로만 보여준다
enum _Permission {
  master('MASTER'),
  admin('ADMIN'),
  member('MEMBER');

  const _Permission(this.label);

  final String label;

  bool get strong => this != _Permission.member;
}

/// 직원 한 명 (목업)
///
/// 이름과 아바타 색은 공용 명단([staffList])을 따르고, 조직도에서만 쓰는
/// 소속·연락처·근태 요약을 여기에 덧붙인다.
class _Member {
  const _Member({
    required this.name,
    required this.role,
    required this.team,
    required this.permission,
    required this.code,
    required this.phone,
    required this.email,
    required this.joined,
    required this.status,
    this.note,
    this.clients = 0,
    this.sessions = 0,
    required this.workedDays,
    required this.workedHours,
    this.lateCount = 0,
    this.leaveUsed = 0,
  });

  final String name;
  final String role;
  final String team;
  final _Permission permission;

  /// 사번
  final String code;
  final String phone;
  final String email;
  final DateTime joined;

  final _Status status;

  /// 상태 메시지 (예: 14시까지 외근)
  final String? note;

  /// 담당 회원 수 · 이번 달 세션 (트레이너·FC만 채운다)
  final int clients;
  final int sessions;

  /// 이번 달 근태 요약
  final int workedDays;
  final int workedHours;
  final int lateCount;
  final double leaveUsed;

  Color get color => staffOf(name).color;

  bool get isMe => name == me;

  /// '3년 4개월' — 한 해가 안 됐으면 개월만
  String get career {
    final now = DateTime.now();
    var months = (now.year - joined.year) * 12 + now.month - joined.month;
    if (now.day < joined.day) months--;
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '$years년' : '$years년 $rest개월';
  }
}

final _members = <_Member>[
  _Member(
    name: '이준승',
    role: '대표',
    team: '대표',
    permission: _Permission.master,
    code: 'FS-0001',
    phone: '010-4410-0001',
    email: 'js.lee@hifis.app',
    joined: DateTime(2019, 1, 2),
    status: _Status.meeting,
    note: '본사 임원 회의',
    workedDays: 19,
    workedHours: 162,
  ),
  _Member(
    name: '민중기',
    role: '점장',
    team: '대표',
    permission: _Permission.admin,
    code: 'FS-0044',
    phone: '010-7720-0044',
    email: 'jk.min@hifis.app',
    joined: DateTime(2020, 7, 13),
    status: _Status.working,
    workedDays: 19,
    workedHours: 171,
    leaveUsed: 1,
  ),
  _Member(
    name: '김피스',
    role: '개발',
    team: '개발',
    permission: _Permission.admin,
    code: 'FS-0102',
    phone: '010-3388-0102',
    email: 'peace@hifis.app',
    joined: DateTime(2024, 5, 20),
    status: _Status.out,
    note: '14시까지 외근',
    workedDays: 18,
    workedHours: 152,
    lateCount: 2,
  ),
  _Member(
    name: '정다은',
    role: '마케터',
    team: '마케팅',
    permission: _Permission.member,
    code: 'FS-0826',
    phone: '010-6650-0826',
    email: 'de.jung@hifis.app',
    joined: DateTime(2023, 8, 21),
    status: _Status.working,
    workedDays: 18,
    workedHours: 150,
    leaveUsed: 2,
  ),
  _Member(
    name: me,
    role: '트레이너',
    team: '트레이너',
    permission: _Permission.member,
    code: 'FS-0903',
    phone: '010-2913-0903',
    email: 'eunhoo@hifis.app',
    joined: DateTime(2023, 3, 2),
    status: _Status.working,
    clients: 14,
    sessions: 62,
    workedDays: 18,
    workedHours: 148,
    lateCount: 1,
    leaveUsed: 3,
  ),
  _Member(
    name: '박준현',
    role: '트레이너',
    team: '트레이너',
    permission: _Permission.member,
    code: 'FS-0311',
    phone: '010-9042-0311',
    email: 'jh.park@hifis.app',
    joined: DateTime(2022, 11, 1),
    status: _Status.meal,
    clients: 11,
    sessions: 51,
    workedDays: 18,
    workedHours: 145,
    leaveUsed: 2,
  ),
  _Member(
    name: '유찬빈',
    role: '트레이너',
    team: '트레이너',
    permission: _Permission.member,
    code: 'FS-0520',
    phone: '010-5517-0520',
    email: 'cb.yoo@hifis.app',
    joined: DateTime(2025, 2, 17),
    status: _Status.leave,
    clients: 9,
    sessions: 40,
    workedDays: 17,
    workedHours: 139,
    leaveUsed: 4,
  ),
  _Member(
    name: '전상현',
    role: 'FC',
    team: 'FC',
    permission: _Permission.member,
    code: 'FS-0715',
    phone: '010-2266-0715',
    email: 'sh.jeon@hifis.app',
    joined: DateTime(2021, 9, 6),
    status: _Status.working,
    clients: 23,
    sessions: 0,
    workedDays: 19,
    workedHours: 158,
    lateCount: 1,
    leaveUsed: 1,
  ),
];

/// 필터에 쓸 팀 목록 — 명단에 실제로 있는 팀만 명단 순서대로
final _teams = [
  '전체',
  ...{for (final m in _members) m.team},
];
