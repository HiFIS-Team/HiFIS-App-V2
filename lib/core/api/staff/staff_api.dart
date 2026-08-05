import 'package:dio/dio.dart';

import '../../data/current_user.dart';
import '../../data/employee.dart';
import '../client/api_client.dart';

/// 지점 (서버 `BranchOut`)
class Branch {
  Branch({required this.id, required this.name, required this.type});

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? '',
  );

  final String id;
  final String name;

  /// `HQ`(본사) · `BRANCH`(지점)
  final String type;

  bool get isHq => type == 'HQ';
}

/// `/branches` — 지점 목록
///
/// 사람·업무 데이터가 전부 `branchId` 로만 오기 때문에 이름을 붙이려면 필요하다.
class BranchApi {
  BranchApi._();

  static Future<List<Branch>> list() async {
    final rows = await ApiClient.instance.getList('/branches');
    return [
      for (final row in rows)
        Branch.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}

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

  /// 남의 계정 고치기 — **점장 이상만** 된다 (MEMBER 는 403)
  ///
  /// 직급·권한·재직 상태·팀·지점처럼 **남이 정해 주는 값**이 여기 있다.
  /// 본인이 바꾸는 것들은 [updateMe] 쪽이다.
  static Future<Employee> updateEmployee(
    String id, {
    Rank? rank,
    Role? role,
    EmployeeStatus? status,
    EmploymentType? employmentType,
    String? team,
    String? branchId,
    String? phone,
  }) async {
    final data = await _client.patch(
      '/employees/$id',
      body: {
        'rank': ?rank?.wire,
        'role': ?role?.wire,
        'status': ?status?.wire,
        'employmentType': ?employmentType?.wire,
        'team': ?team,
        'branchId': ?branchId,
        'phone': ?phone,
      },
    );
    return Employee.fromJson(data!);
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
