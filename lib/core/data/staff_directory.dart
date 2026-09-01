import '../api/staff/staff_api.dart';
import 'employee.dart';

/// 전사 인원 명단
///
/// 로그인 직후 한 번 받아 두고 앱이 살아 있는 동안 그대로 쓴다.
/// 화면들이 명단을 동기적으로(빌드 중에) 읽기 때문에 매번 요청할 수 없다.
///
/// 아직 목업이 남은 화면이 많아서, 못 받아온 동안에는 [staffList]가
/// 목업 명단으로 떨어진다 (`staff.dart` 참고).
class StaffDirectory {
  StaffDirectory._();

  static final StaffDirectory instance = StaffDirectory._();

  List<Employee> employees = const [];

  /// 지점 — 사람·업무 데이터가 `branchId` 로만 와서 이름을 붙이려면 필요하다.
  /// 명단과 같이 한 번 받아 두고 화면이 동기적으로 읽는다.
  List<Branch> branches = const [];

  bool get isEmpty => employees.isEmpty;

  /// 명단 받아오기 — 실패해도 앱은 떠야 하므로 조용히 넘긴다
  ///
  /// 둘을 같이 띄우되 **각자에게 바로 에러 처리를 붙인다.** `await` 한 뒤에
  /// try 로 감싸면, 먼저 실패한 쪽이 아직 아무도 안 기다리는 동안 터져서
  /// 콘솔에 `Unhandled Exception` 이 찍힌다 (실제로 찍혔다 — 잡히기는 하는데
  /// 빨간 로그가 남아 진짜 문제를 가린다).
  Future<void> load() async {
    // 서버가 꺼져 있거나 권한이 없다 — 목업 명단으로 계속 간다
    final people = StaffApi.list().catchError((_) => employees);
    // 지점 이름을 못 받으면 화면이 uuid 대신 빈 값으로 떨어진다
    final places = BranchApi.list().catchError((_) => branches);

    employees = await people;
    branches = await places;
  }

  void clear() {
    employees = const [];
    branches = const [];
  }

  Branch? branchOf(String? id) {
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  /// 지점 이름 — 못 찾으면 빈 문자열 (화면이 빈 값은 빼고 그린다)
  String branchName(String? id) => branchOf(id)?.name ?? '';

  /// 지점 표시 순서 — 작을수록 앞
  ///
  /// HQ 는 지점이 아니라 전사라서 맨 앞이다 (서버가 `전체` 라고 부른다).
  /// 그다음은 정해진 차례 (화순 → 첨단 → 동광주).
  /// 목록에 없는 지점은 뒤로 밀고 이름순으로 둔다.
  static const _order = ['화순', '첨단', '동광주'];

  int branchRank(String? id) {
    final branch = branchOf(id);
    if (branch == null) return _order.length + 1;
    if (branch.isHq) return -1;
    final at = _order.indexOf(branch.name);
    return at < 0 ? _order.length : at;
  }

  /// 사람을 세우는 **공통 차례 — 지점 → 직급 → 이름**
  ///
  /// | 순위 | 기준 | 차례 |
  /// |---|---|---|
  /// | 1 | 지점 | 전 지점(HQ) · 화순 · 첨단 · 동광주 ([branchRank]) |
  /// | 2 | 직급 | 대표 · 개발자 · 마케터 · 점장 · 팀장 · 트레이너 · FC |
  /// | 3 | 이름 | 가나다 |
  ///
  /// 직급 차례는 [Rank] **선언 순서 그대로**다 (backend-gap 61번). 여기에
  /// 표를 새로 만들면 둘이 갈린다.
  ///
  /// **명단을 세우는 자리는 다 이걸 쓴다** (조직도·동료평가·환경정비 사람
  /// 필터·수업 트레이너·일정 참석자·사내톡 멤버·홈 출근). 화면마다 이름순으로
  /// 세우면 같은 사람이 화면마다 다른 자리에 있어서 눈이 자리를 못 외운다.
  ///
  /// 먼저 볼 것이 따로 있는 화면(홈은 근무중, 동료평가 현황은 미제출)은
  /// 그 기준을 앞에 두고 **여기를 뒷차례로** 쓴다.
  int compareStaff(Employee a, Employee b) {
    final branch = branchRank(a.branchId).compareTo(branchRank(b.branchId));
    if (branch != 0) return branch;
    final rank = a.rank.index.compareTo(b.rank.index);
    if (rank != 0) return rank;
    return a.name.compareTo(b.name);
  }

  /// id 로 세우는 공통 차례 — **고르개**가 쓴다
  ///
  /// 필터 메뉴는 사람 객체가 아니라 `(id, 이름)` 짝만 들고 있다. 명단에서
  /// 못 찾은 사람(지워진 계정 등)은 뒤로 밀고 이름순으로 둔다.
  int compareStaffIds(String aId, String bId, String aName, String bName) {
    final a = byId(aId);
    final b = byId(bId);
    if (a != null && b != null) return compareStaff(a, b);
    if (a != null) return -1;
    if (b != null) return 1;
    return aName.compareTo(bName);
  }

  /// uuid 로 찾기 — 서버 데이터를 다루는 화면이 쓴다
  Employee? byId(String id) {
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  /// 이름으로 찾기 — 아직 이름을 사람 키로 쓰는 목업 화면들이 쓴다
  ///
  /// 동명이인이 오면 먼저 등록된 쪽이 잡힌다. uuid 기준으로 바꾸는 건
  /// 화면별 연동 때 같이 정리한다 (backend-gap.md 10번).
  Employee? byName(String name) {
    for (final employee in employees) {
      if (employee.name == name) return employee;
    }
    return null;
  }
}
