import 'package:dio/dio.dart';

import '../data/current_user.dart';
import '../data/employee.dart';
import 'api_client.dart';

/// `/employees` — 전사 인원 디렉터리와 내 계정
///
/// 목록은 지점 업무 데이터가 아니라 '사람' 목록이라 지점 제한이 없다.
/// 프로젝트 담당자·회의 참석자·멘션·랭킹에서 다른 지점 사람도 골라야 하기 때문.
///
/// `/me` 로 시작하는 것들은 **본인 것만** 건드린다. 직급·권한·지점처럼
/// 남이 정해 주는 값은 여기서 못 바꾼다 (관리자용 `PATCH /employees/{id}` 쪽이다).
class StaffApi {
  StaffApi._();

  static final _client = ApiClient.instance;

  static Future<List<Employee>> list({String? branchId, String? query}) async {
    final rows = await _client.getList(
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

  /// 내 계정 다시 받기
  static Future<Employee> me() async {
    final data = await _client.get('/employees/me');
    return Employee.fromJson(data);
  }

  /// 내가 바꿀 수 있는 것 — 이름·아바타 색·상태
  ///
  /// 상태 메시지는 **빈 문자열도 보낼 수 있다** (지우기). 그래서 넘겼는지
  /// 여부로 가르지 않고 `null` 이면 안 건드리는 것으로 둔다.
  static Future<Employee> updateMe({
    String? name,
    String? phone,
    String? avatarColor,
    String? statusMessage,
    WorkStatus? workStatus,
  }) async {
    final data = await _client.patch(
      '/employees/me',
      body: {
        'name': ?name,
        'phone': ?phone,
        'avatarColor': ?avatarColor,
        'statusMessage': ?statusMessage,
        'workStatus': ?workStatus?.wire,
      },
    );
    return Employee.fromJson(data!);
  }

  /// 프로필 사진 올리기 — png·jpg·gif·webp, **5MB 이하**.
  /// 올리면 서버가 이전 파일을 지운다
  static Future<Employee> uploadAvatar(String path, {String? filename}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final data = await _client.post('/employees/me/avatar', body: form);
    return Employee.fromJson(data!);
  }

  /// 비밀번호 바꾸기 — **바꾸면 다른 기기의 로그인이 전부 풀린다**
  /// (서버가 토큰 버전을 올린다)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _client
      .post(
        '/employees/me/password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      )
      .then((_) {});

  /// 탈퇴 — 되돌릴 수 없다.
  ///
  /// 계정이 비활성화되고 이름·연락처가 익명 처리된다. 근태·급여 기록은 남는다.
  /// 대표(MASTER)가 혼자면 승인권이 비어서 서버가 막는다.
  static Future<void> withdraw() =>
      _client.post('/employees/me/withdraw').then((_) {});
}

/// 서버가 준 최신 내 계정을 앱 전체에 반영한다
///
/// [currentUser] 는 화면 여러 곳이 그냥 읽는 값이라, 프로필에서 바꾼 뒤
/// 이걸 안 갈아끼우면 사이드바·아바타가 옛 이름·색으로 남는다.
void applyCurrentUser(Employee employee) => currentUser = employee;
