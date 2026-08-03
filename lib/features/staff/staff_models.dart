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

  /// 화면에 적을 소속
  ///
  /// MASTER·ADMIN 은 한 지점을 맡지 않는다. 서버에는 본사(HQ) 소속으로
  /// 들어 있지만 그걸 그대로 적으면 지점 하나인 것처럼 보인다.
  String get branchLabel => switch (permission) {
    Role.master || Role.admin => '전 지점',
    _ => branch,
  };

  Role get permission => source.role;

  _Employment get employment => _Employment.of(source.status);

  /// 사번
  String get code => source.empNo ?? '미발급';
  String get phone => source.phone ?? '';
  String get email => source.email;

  DateTime? get joined => source.joinedAt;
  DateTime? get resigned => source.resignedAt;

  /// 상태 메시지 (예: 14시까지 외근)
  String? get note => source.statusMessage;

  Color get color => source.color ?? avatarColorFor(name);

  String? get avatarUrl => source.avatarImageUrl;

  bool get isMe => source.id == currentUser?.id;

  bool get active => employment == _Employment.active;

  /// 지금 상태 — 스스로 고른 값이 먼저고, 없으면 서버의 오늘 판정을 따른다
  ///
  /// 서버 `workStatus` 가 `AUTO` 면 "출근 기준으로 알아서"라는 뜻이라
  /// 오늘 판정([Employee.todayStatus])을 본다. 명단에 같이 실려 온다.
  ///
  /// **휴가도 가린다** — 예전에는 `GET /attendance` 를 받아 앱이 갈랐는데
  /// 그 응답에는 휴가가 안 나와서 휴가 중인 사람이 '퇴근'으로 보였다
  /// (backend-gap.md 59번).
  _Status get status => switch (source.workStatus) {
    WorkStatus.meeting => _Status.meeting,
    WorkStatus.meal => _Status.meal,
    WorkStatus.out => _Status.out,
    WorkStatus.away => _Status.away,
    WorkStatus.auto => switch (source.todayStatus) {
      AttendanceStatus.onLeave => _Status.leave,
      // 출근했고 아직 퇴근을 안 찍었다
      final s? when s.working => _Status.working,
      // 퇴근했거나(NORMAL·LATE…) 휴무거나 아직 출근 전(null)
      _ => _Status.off,
    },
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

bool _staffLoaded = false;

/// 명단·지점을 받아 화면 모델을 세운다
///
/// 오늘 근태는 따로 부르지 않는다 — 명단에 사람마다 실려 온다
/// ([Employee.todayStatus]).
Future<void> _loadStaff() async {
  final directory = StaffDirectory.instance;

  await directory.load();

  _members
    ..clear()
    ..addAll([for (final employee in directory.employees) _Member(employee)])
    ..sort(_byRoleThenBranch);

  _staffLoaded = true;
}

/// 1:1 사내톡 열기 — 방을 만들고(있으면 그 방을) 연다
///
/// 명단 카드와 상세 화면 둘 다 쓴다. **서버가 기존 DM 을 찾아 주므로**
/// 같은 사람에게 여러 번 눌러도 방이 새로 생기지 않는다.
Future<void> _openChat(BuildContext context, _Member member) async {
  try {
    final room = await ChatStore.instance.createRoom([member.id]);
    if (!context.mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => ChatScreen(roomId: room.id)),
    );
  } catch (error) {
    if (context.mounted) AppToast.show(context, messageOf(error));
  }
}

/// 서버가 돌려준 사람으로 명단의 그 자리를 갈아끼운다
///
/// 명단(`_members`)과 디렉터리(`StaffDirectory`) 둘 다 고친다 — 디렉터리는
/// 다른 화면(멘션·참석자)도 보는 곳이라 어긋나면 안 된다.
/// 지점·권한이 바뀌면 정렬 자리도 달라지므로 다시 세운다.
void _replaceMember(Employee saved) {
  final index = _members.indexWhere((m) => m.id == saved.id);
  if (index >= 0) {
    _members[index] = _Member(saved);
    _members.sort(_byRoleThenBranch);
  }
  final directory = StaffDirectory.instance;
  final at = directory.employees.indexWhere((e) => e.id == saved.id);
  if (at >= 0) directory.employees = [...directory.employees]..[at] = saved;
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
///
/// **본사(HQ)는 세우지 않는다.** 지점이 아니라 전사라서 고를 대상이 아니다.
/// 거기 소속인 MASTER·ADMIN 은 어느 지점을 골라도 보인다 ([_inBranch]).
const _allBranches = '전체';

List<String> get _branches {
  final directory = StaffDirectory.instance;
  final sorted = [...directory.branches.where((b) => !b.isHq)]
    ..sort(
      (a, b) =>
          directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
    );
  return [_allBranches, for (final branch in sorted) branch.name];
}

/// 이 사람이 고른 지점에 드는가
///
/// **MASTER·ADMIN 은 전 지점 소속이라 늘 든다.** 한 지점을 맡는 게 아니라
/// 전사를 보는 자리라, 화순을 골라도 첨단을 골라도 명단에 있어야 한다.
bool _inBranch(_Member member, String branch) =>
    branch == _allBranches ||
    member.permission == Role.master ||
    member.permission == Role.admin ||
    member.branch == branch;

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
