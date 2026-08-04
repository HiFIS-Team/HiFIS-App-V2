import 'api_client.dart';

/// 응답 지표 한 장 (서버 `ApiMetricsOut`)
///
/// **모든 요청**을 재서 분 단위로 모은 것을 합친 값이다. 백분위는 버킷
/// 히스토그램에서 보간해 낸 근사치라 실제와 몇 % 차이가 날 수 있다
/// (원본을 다 들고 있어야 정확한데 그러면 하루 수만 줄이 쌓인다).
class ApiMetrics {
  ApiMetrics({
    required this.minutes,
    required this.requests,
    required this.rpm,
    required this.errorRate,
    required this.clientErrorRate,
    required this.avgMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.slowest,
    required this.timeline,
  });

  factory ApiMetrics.fromJson(Map<String, dynamic> json) => ApiMetrics(
    minutes: json['minutes'] as int,
    requests: json['requests'] as int,
    rpm: (json['rpm'] as num).toDouble(),
    errorRate: (json['errorRate'] as num).toDouble(),
    clientErrorRate: (json['clientErrorRate'] as num).toDouble(),
    avgMs: json['avgMs'] as int,
    p50Ms: json['p50Ms'] as int,
    p95Ms: json['p95Ms'] as int,
    p99Ms: json['p99Ms'] as int,
    maxMs: json['maxMs'] as int,
    slowest: [
      for (final row in (json['slowest'] as List<dynamic>? ?? const []))
        SlowRoute.fromJson((row as Map).cast<String, dynamic>()),
    ],
    timeline: [
      for (final row in (json['timeline'] as List<dynamic>? ?? const []))
        MetricPoint.fromJson((row as Map).cast<String, dynamic>()),
    ],
  );

  /// 본 기간 (분)
  final int minutes;
  final int requests;

  /// 분당 요청 수
  final double rpm;

  /// 5xx 비율 (%) — 서버가 터진 것
  final double errorRate;

  /// 4xx 비율 (%) — 권한 없음·잘못된 입력. 정상 동작일 수도 있다
  final double clientErrorRate;

  final int avgMs;
  final int p50Ms;
  final int p95Ms;
  final int p99Ms;
  final int maxMs;

  final List<SlowRoute> slowest;
  final List<MetricPoint> timeline;
}

/// 느린 주소 한 줄
class SlowRoute {
  SlowRoute({
    required this.method,
    required this.route,
    required this.count,
    required this.avgMs,
    required this.p95Ms,
    required this.maxMs,
    required this.errors,
  });

  factory SlowRoute.fromJson(Map<String, dynamic> json) => SlowRoute(
    method: json['method'] as String,
    route: json['route'] as String,
    count: json['count'] as int,
    avgMs: json['avgMs'] as int,
    p95Ms: json['p95Ms'] as int,
    maxMs: json['maxMs'] as int,
    errors: json['errors'] as int,
  );

  final String method;
  final String route;
  final int count;
  final int avgMs;
  final int p95Ms;
  final int maxMs;
  final int errors;
}

/// 분 하나 — 화면의 꺾은선이 쓴다
class MetricPoint {
  MetricPoint({
    required this.minute,
    required this.count,
    required this.avgMs,
    required this.errors,
  });

  factory MetricPoint.fromJson(Map<String, dynamic> json) => MetricPoint(
    minute: DateTime.parse(json['minute'] as String).toLocal(),
    count: json['count'] as int,
    avgMs: json['avgMs'] as int,
    errors: json['errors'] as int,
  );

  final DateTime minute;
  final int count;
  final int avgMs;
  final int errors;
}

/// 이상행동 종류 — 서버 `AnomalyKind`
enum AnomalyKind {
  bruteForce('BRUTE_FORCE', '로그인 반복 실패'),
  forbiddenBurst('FORBIDDEN_BURST', '권한 없는 요청'),
  newDevice('NEW_DEVICE', '새로운 곳 로그인'),
  bulkDelete('BULK_DELETE', '대량 삭제'),
  readBurst('READ_BURST', '열람 급증'),
  unknown('UNKNOWN', '이상 징후');

  const AnomalyKind(this.wire, this.label);

  final String wire;
  final String label;

  static AnomalyKind parse(String? value) => AnomalyKind.values.firstWhere(
    (k) => k.wire == value,
    orElse: () => AnomalyKind.unknown,
  );
}

/// 찾아낸 이상행동 한 건 (서버 `AnomalyOut`)
class Anomaly {
  Anomaly({
    required this.id,
    required this.kind,
    required this.subject,
    required this.detail,
    required this.count,
    required this.createdAt,
    this.employeeId,
    this.ip,
    this.userAgent,
    this.resolvedAt,
  });

  factory Anomaly.fromJson(Map<String, dynamic> json) => Anomaly(
    id: json['id'] as String,
    kind: AnomalyKind.parse(json['kind'] as String?),
    subject: json['subject'] as String,
    detail: json['detail'] as String,
    count: json['count'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    employeeId: json['employeeId'] as String?,
    ip: json['ip'] as String?,
    userAgent: json['userAgent'] as String?,
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.parse(json['resolvedAt'] as String).toLocal(),
  );

  final String id;
  final AnomalyKind kind;

  /// 화면에 그대로 찍는 대상 — 이름이거나 이메일·IP다 (계정이 없을 수 있어서)
  final String subject;
  final String detail;
  final int count;
  final DateTime createdAt;
  final String? employeeId;
  final String? ip;
  final String? userAgent;

  /// 대표가 '확인했다'를 누른 시각 — 안 눌렀으면 null
  final DateTime? resolvedAt;

  bool get open => resolvedAt == null;
}

/// 성능 지표·이상행동 — **MASTER · ADMIN 만** (확인 처리는 MASTER 만)
class MonitoringApi {
  MonitoringApi._();

  static final _client = ApiClient.instance;

  static Future<ApiMetrics> metrics({int minutes = 60}) async {
    final data = await _client.get(
      '/metrics/summary',
      query: {'minutes': '$minutes'},
    );
    return ApiMetrics.fromJson(data);
  }

  /// 번호 페이지 한 장 — [total] 전체 · [failed] 아직 확인 안 한 건수
  static Future<({List<Anomaly> items, int total, int failed})> anomalies({
    bool unresolvedOnly = false,
    int limit = 100,
    int offset = 0,
    DateTime? before,
  }) async {
    final result = await _client.getLogPage(
      '/anomalies',
      query: {
        if (unresolvedOnly) 'unresolvedOnly': 'true',
        'limit': '$limit',
        'offset': '$offset',
        'before': ?before?.toUtc().toIso8601String(),
      },
    );
    return (
      items: [
        for (final row in result.items)
          Anomaly.fromJson((row as Map).cast<String, dynamic>()),
      ],
      total: result.total,
      failed: result.failed,
    );
  }

  /// 확인했다 표시 — **MASTER 만** (ADMIN 은 403)
  static Future<void> resolve(String id) =>
      _client.post('/anomalies/$id/resolve');

  /// 화면이 캡처됐다고 알린다 — **권한 없이 전 직원이 부른다**
  ///
  /// 서버는 따로 저장하지 않는다. 쓰기 요청이라 활동 로그에 그대로 남고,
  /// 짧은 시간에 여러 번이면 이상 징후로 올라간다.
  static Future<void> reportCapture({
    required String platform,
    String kind = 'screenshot',
  }) => _client.post(
    '/security/capture',
    body: {'platform': platform, 'kind': kind},
  );
}
