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

/// 재직 상태 — 서로 겹치지 않아 탭으로 나눈다
///
/// 서버 `EmployeeStatus` 와 1:1 이다. 가운데 칸은 예전에 '대기자'(가입 승인
/// 대기)였는데, **서버가 승인 대기를 폐지**해서 지금은 잠가 둔 계정을 뜻한다
/// (backend-gap.md 11·58번).
enum _Employment {
  active('재직자', EmployeeStatus.active),
  inactive('비활성', EmployeeStatus.inactive),
  left('퇴사자', EmployeeStatus.resigned);

  const _Employment(this.label, this.wire);

  final String label;
  final EmployeeStatus wire;

  static _Employment of(EmployeeStatus status) =>
      _Employment.values.firstWhere((e) => e.wire == status);
}

/// 직원 한 명 — 서버 `EmployeeOut` 을 화면 말로 옮긴 것
///
/// 값을 복사하지 않고 [source] 를 그대로 들고 있는다. 프로필에서 이름·색을
/// 바꾸면 명단을 다시 받는데, 복사해 두면 두 벌이 어긋난다.
class _Member {
  _Member(this.source);

  final Employee source;

  String get id => source.id;
  String get name => source.name;

  Rank get rank => source.rank;

  /// 직급 이름 (트레이너·FC·팀장·점장·개발·대표)
  String get role => source.rank.label;

  /// 소속 지점 이름 — 서버는 uuid 로만 준다
  String get branch => StaffDirectory.instance.branchName(source.branchId);

  Role get permission => source.role;

  _Employment get employment => _Employment.of(source.status);

  /// 사번
  String get code => source.empNo ?? '미발급';
  String get phone => source.phone ?? '';
  String get email => source.email;

  DateTime? get joined => source.joinedAt;

  /// 상태 메시지 (예: 14시까지 외근)
  String? get note => source.statusMessage;

  Color get color => source.color ?? avatarColorFor(name);

  String? get avatarUrl => source.avatarImageUrl;

  bool get isMe => source.id == currentUser?.id;

  bool get active => employment == _Employment.active;

  /// 지금 상태 — 스스로 고른 값이 먼저고, 없으면 오늘 출퇴근으로 가른다
  ///
  /// 서버 `workStatus` 가 `AUTO` 면 "출근 기준으로 알아서"라는 뜻이라
  /// 오늘 기록을 봐야 한다. 그 기록은 [_todayWorking] 이 한 번에 받아 둔다.
  ///
  /// **월차는 못 가린다** — 오늘 휴가인 사람을 전원 분량으로 주는 길이 없다
  /// (backend-gap.md 59번). 휴가 중인 사람은 '퇴근'으로 보인다.
  _Status get status => switch (source.workStatus) {
    WorkStatus.meeting => _Status.meeting,
    WorkStatus.meal => _Status.meal,
    WorkStatus.out => _Status.out,
    WorkStatus.away => _Status.away,
    WorkStatus.auto =>
      _todayWorking.contains(source.id) ? _Status.working : _Status.off,
  };

  /// '3년 4개월' — 한 해가 안 됐으면 개월만
  String get career {
    final start = joined;
    if (start == null) return '-';
    final now = DateTime.now();
    var months = (now.year - start.year) * 12 + now.month - start.month;
    if (now.day < start.day) months--;
    if (months < 0) months = 0;
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '$years년' : '$years년 $rest개월';
  }
}

/// 화면이 쓰는 명단
final _members = <_Member>[];

/// 오늘 출근해서 아직 퇴근을 안 찍은 사람
///
/// `GET /attendance?month=` 을 **한 번** 불러 채운다. 사람마다 부르면
/// 인원수만큼 요청이 나간다.
final _todayWorking = <String>{};

bool _staffLoaded = false;

/// 명단·지점·오늘 근태를 받아 화면 모델을 세운다
Future<void> _loadStaff() async {
  final directory = StaffDirectory.instance;
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  // 명단과 근태를 같이 띄운다 — 근태는 실패해도 명단은 보여야 한다
  final attendance = AttendanceApi.list(month: month);

  await directory.load();

  _members
    ..clear()
    ..addAll([for (final employee in directory.employees) _Member(employee)])
    ..sort(_byRoleThenBranch);

  _todayWorking.clear();
  try {
    for (final row in await attendance) {
      final at = row.date;
      final today =
          at.year == now.year && at.month == now.month && at.day == now.day;
      // 퇴근을 찍었으면 지금은 자리에 없다
      if (today && row.checkOut == null) _todayWorking.add(row.employeeId);
    }
  } catch (_) {
    // 근태를 못 받으면 자동 상태인 사람이 전부 '퇴근'으로 보인다
  }

  _staffLoaded = true;
}

/// 명단 정렬 — **권한이 먼저, 그다음 지점**
///
/// MASTER·ADMIN 은 한 지점 소속이 아니라 전사를 본다. 권한을 먼저 보므로
/// 그 둘은 지점과 상관없이 늘 맨 앞에 선다.
/// 같은 권한 안에서는 지점 차례(본사 → 화순 → 첨단 → 동광주), 그다음 이름순.
int _byRoleThenBranch(_Member a, _Member b) {
  final role = a.permission.index.compareTo(b.permission.index);
  if (role != 0) return role;

  final directory = StaffDirectory.instance;
  final branch = directory
      .branchRank(a.source.branchId)
      .compareTo(directory.branchRank(b.source.branchId));
  if (branch != 0) return branch;

  return a.name.compareTo(b.name);
}

/// 지점 필터 목록 — 맨 앞은 모든 지점을 함께 보는 '전체'
const _allBranches = '전체';

List<String> get _branches {
  final directory = StaffDirectory.instance;
  final sorted = [...directory.branches]
    ..sort(
      (a, b) =>
          directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
    );
  return [_allBranches, for (final branch in sorted) branch.name];
}

/// 필터에 쓸 직급 목록 — 서버 `Rank` 를 그대로 쓴다
///
/// 명단에 있는 것만 세우지 않고 **여섯 개를 늘 다 세운다.** 지점·재직 상태 탭을
/// 옮길 때마다 칩이 늘었다 줄었다 하면 자리를 못 외운다.
const _allRanks = '전체';

List<String> get _ranks => [_allRanks, for (final r in Rank.values) r.label];

/// 명단에서 나를 찾는다 — 못 찾으면 로그인 정보로 만든다
///
/// 서버 명단에는 내가 반드시 있다. 다만 명단을 못 받아온 동안
/// (서버가 꺼져 있거나 요청이 실패)에도 내 카드는 떠야 해서 폴백을 둔다.
_Member get _meOrSelf {
  final id = currentUser?.id;
  for (final member in _members) {
    if (member.id == id) return member;
  }
  return _Member(
    currentUser ??
        Employee(
          id: '',
          name: me,
          email: '',
          branchId: '',
          rank: Rank.trainer,
          role: myRole,
          avatarColor: '',
        ),
  );
}
