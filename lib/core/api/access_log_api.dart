import 'api_client.dart';

/// 접속 이벤트 — 서버 `AccessEvent`
enum AccessEvent {
  loginSuccess('LOGIN_SUCCESS', '로그인'),
  loginFail('LOGIN_FAIL', '로그인 실패');

  const AccessEvent(this.wire, this.label);

  final String wire;
  final String label;

  bool get failed => this == AccessEvent.loginFail;

  static AccessEvent parse(String? value) => AccessEvent.values.firstWhere(
    (e) => e.wire == value,
    orElse: () => AccessEvent.loginSuccess,
  );
}

/// 접속 기록 한 줄 (서버 `AccessLogOut`)
///
/// 로그인 실패는 계정이 없을 수도 있어서 [employeeId] 가 비고 [email] 만 남는다.
class AccessLog {
  AccessLog({
    required this.id,
    required this.event,
    required this.createdAt,
    this.employeeId,
    this.email,
    this.ip,
    this.userAgent,
  });

  factory AccessLog.fromJson(Map<String, dynamic> json) => AccessLog(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String?,
    email: json['email'] as String?,
    event: AccessEvent.parse(json['event'] as String?),
    ip: json['ip'] as String?,
    userAgent: json['userAgent'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  /// 로그인에 성공한 사람. 실패는 비어 있을 수 있다
  final String? employeeId;

  /// 로그인 창에 적은 이메일 (실패 추적용)
  final String? email;

  final AccessEvent event;
  final String? ip;

  /// 접속한 프로그램이 스스로 밝힌 이름 — **서버가 받은 그대로다**
  final String? userAgent;

  final DateTime createdAt;
}

/// `/access-logs` — 접속 기록 (읽기 전용)
///
/// **MASTER · ADMIN 만** 볼 수 있다. 전 지점 보안 데이터라 지점으로 안 나눈다.
class AccessLogApi {
  AccessLogApi._();

  static final _client = ApiClient.instance;

  /// 최신순. [limit] 은 서버가 1~500 으로 제한한다
  static Future<List<AccessLog>> list({
    String? employeeId,
    AccessEvent? event,
    int limit = 200,
  }) async {
    final rows = await _client.getList(
      '/access-logs',
      query: {
        'employeeId': ?employeeId,
        'event': ?event?.wire,
        'limit': '$limit',
      },
    );
    return [
      for (final row in rows)
        AccessLog.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 번호 페이지 한 장 — [total] 전체 건수 · [failed] 그중 로그인 실패
  ///
  /// 90일치가 쌓이면 한 번에 다 받을 수 없어서 목록은 이 길로 받는다.
  /// 두 건수는 필터와 무관한 전체값이라 탭 라벨에 그대로 쓴다.
  /// [before] 는 장을 넘기는 동안 고정하는 기준선이다 (활동 로그와 같은 이유)
  static Future<({List<AccessLog> items, int total, int failed})> page({
    AccessEvent? event,
    int limit = 100,
    int offset = 0,
    DateTime? before,
  }) async {
    final result = await _client.getLogPage(
      '/access-logs',
      query: {
        'event': ?event?.wire,
        'limit': '$limit',
        'offset': '$offset',
        'before': ?before?.toUtc().toIso8601String(),
      },
    );
    return (
      items: [
        for (final row in result.items)
          AccessLog.fromJson((row as Map).cast<String, dynamic>()),
      ],
      total: result.total,
      failed: result.failed,
    );
  }
}
