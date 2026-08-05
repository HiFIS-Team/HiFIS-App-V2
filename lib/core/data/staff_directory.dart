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
