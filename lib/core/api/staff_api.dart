import '../data/employee.dart';
import 'api_client.dart';

/// `/employees` — 전사 인원 디렉터리
///
/// 지점 업무 데이터가 아니라 '사람' 목록이라 지점 제한이 없다.
/// 프로젝트 담당자·회의 참석자·멘션·랭킹에서 다른 지점 사람도 골라야 하기 때문.
class StaffApi {
  StaffApi._();

  static Future<List<Employee>> list({String? branchId, String? query}) async {
    final rows = await ApiClient.instance.getList(
      '/employees',
      query: {
        'branchId': ?branchId,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return [
      for (final row in rows)
        Employee.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
