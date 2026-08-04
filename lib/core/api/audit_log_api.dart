import 'api_client.dart';

/// 활동 기록 한 줄 (서버 `AuditLogOut`)
///
/// 접속 기록([AccessLog])이 '들어왔다/못 들어왔다'만 남긴다면 이쪽은 **한 일**이다.
/// 쓰기 요청이 지나갈 때 서버가 한 줄씩 적는다.
class AuditLog {
  AuditLog({
    required this.id,
    required this.action,
    required this.method,
    required this.path,
    required this.route,
    required this.status,
    required this.ok,
    required this.createdAt,
    this.employeeId,
    this.payload,
    this.ip,
    this.userAgent,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String?,
    action: json['action'] as String? ?? '',
    method: json['method'] as String? ?? '',
    path: json['path'] as String? ?? '',
    route: json['route'] as String? ?? '',
    status: json['status'] as int? ?? 0,
    ok: json['ok'] as bool? ?? false,
    payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
    ip: json['ip'] as String?,
    userAgent: json['userAgent'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  /// 한 일을 한 사람. 로그인 전 요청(가입 등)은 비어 있다
  final String? employeeId;

  /// `공지 작성` 처럼 사람이 읽는 말 — **서버가 붙여 준다**
  final String action;

  final String method;

  /// 실제로 부른 주소 (id 가 들어 있다)
  final String path;

  /// id 를 `{id}` 로 바꾼 모양 — 같은 종류끼리 묶는 기준
  final String route;

  final int status;

  /// 2xx 였는지 — false 면 막힌 시도다 (403·400·401)
  final bool ok;

  /// 보낸 내용. 비밀번호는 서버가 `***` 로 가려서 준다.
  /// 파일 업로드·너무 큰 본문은 `_note` 만 들어 있다
  final Map<String, dynamic>? payload;

  final String? ip;
  final String? userAgent;
  final DateTime createdAt;
}

/// `/audit-logs` — 활동 기록 (읽기 전용)
///
/// 열람 기록을 목록에서 어떻게 할지 — 서버 `reads` 파라미터
///
/// 관리자가 남의 기록·대화를 들여다본 줄이다. 한 일이 아니라 지켜본 일이라
/// 기본으로 빼고 따로 본다. **남기는 것 자체는 그대로다** (개인정보처리방침 §8-1).
enum AuditReads {
  exclude('exclude'),
  only('only'),
  include('include');

  const AuditReads(this.wire);

  final String wire;
}

/// **MASTER · ADMIN 만** 볼 수 있다. 접속 기록과 같은 게이트다.
class AuditLogApi {
  AuditLogApi._();

  static final _client = ApiClient.instance;

  /// 최신순. [limit] 은 서버가 1~500 으로 제한한다
  static Future<List<AuditLog>> list({
    String? employeeId,
    String? route,
    bool failedOnly = false,
    int limit = 200,
  }) async {
    final rows = await _client.getList(
      '/audit-logs',
      query: {
        'employeeId': ?employeeId,
        'route': ?route,
        if (failedOnly) 'failedOnly': 'true',
        'limit': '$limit',
      },
    );
    return [
      for (final row in rows)
        AuditLog.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 번호 페이지 한 장 — [total] 전체 건수 · [failed] 그중 막힌 시도
  ///
  /// 90일치가 쌓이면 한 번에 다 받을 수 없어서 목록은 이 길로 받는다.
  /// 두 건수는 막힘 여부 필터와 무관한 전체값이라 탭 라벨에 그대로 쓴다.
  /// [before] 는 장을 넘기는 동안 고정하는 기준선이다 — 안 주면 조회가 만든
  /// 새 로그 때문에 같은 줄이 두 장에 걸쳐 나온다.
  ///
  /// [reads] 는 관리자 열람 기록(`활동 기록 열람` 등)을 어떻게 할지다.
  /// **기본은 빼는 것** — 안 빼면 목록 맨 위가 본인 열람으로 채워진다.
  static Future<({List<AuditLog> items, int total, int failed, int read})>
  page({
    bool failedOnly = false,
    AuditReads reads = AuditReads.exclude,
    int limit = 100,
    int offset = 0,
    DateTime? before,
  }) async {
    final result = await _client.getLogPage(
      '/audit-logs',
      query: {
        if (failedOnly) 'failedOnly': 'true',
        'reads': reads.wire,
        'limit': '$limit',
        'offset': '$offset',
        'before': ?before?.toUtc().toIso8601String(),
      },
    );
    return (
      items: [
        for (final row in result.items)
          AuditLog.fromJson((row as Map).cast<String, dynamic>()),
      ],
      total: result.total,
      failed: result.failed,
      read: result.read,
    );
  }
}
