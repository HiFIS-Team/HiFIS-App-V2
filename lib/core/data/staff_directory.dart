import '../api/staff_api.dart';
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

  bool get isEmpty => employees.isEmpty;

  /// 명단 받아오기 — 실패해도 앱은 떠야 하므로 조용히 넘긴다
  Future<void> load() async {
    try {
      employees = await StaffApi.list();
    } catch (_) {
      // 서버가 꺼져 있거나 권한이 없다 — 목업 명단으로 계속 간다
    }
  }

  void clear() => employees = const [];

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
