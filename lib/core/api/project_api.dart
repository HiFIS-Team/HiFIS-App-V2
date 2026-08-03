import 'api_client.dart';

/// 프로젝트가 놓인 자리 (서버 `ProjectStatus`) — **서버가 파생시킨다**
///
/// ```
/// progress >= 100  → done
/// due < 지금       → missed
/// progress > 0     → inProgress
/// 그 외            → waiting
/// ```
enum ProjectStatus {
  waiting('WAITING'),
  inProgress('IN_PROGRESS'),
  done('DONE'),
  missed('MISSED');

  const ProjectStatus(this.wire);

  final String wire;

  static ProjectStatus parse(String? value) => ProjectStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => ProjectStatus.waiting,
  );
}

/// 기한 변경 요청 종류 (서버 `ProjectRequestType`)
enum ProjectRequestType {
  /// 마감 전에 미리 미루겠다는 신청
  extension('EXTENSION'),

  /// 마감이 지난 뒤 왜 늦었고 언제까지 끝내겠다는 사유
  overdue('OVERDUE');

  const ProjectRequestType(this.wire);

  final String wire;

  static ProjectRequestType parse(String? value) =>
      ProjectRequestType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ProjectRequestType.extension,
      );
}

/// 기한 변경 요청의 결재 상태 (서버 `ProjectRequestStatus`)
enum ProjectRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const ProjectRequestStatus(this.wire);

  final String wire;

  static ProjectRequestStatus parse(String? value) =>
      ProjectRequestStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ProjectRequestStatus.pending,
      );
}

/// 프로젝트 (서버 `ProjectOut`)
class Project {
  Project({
    required this.id,
    required this.title,
    required this.purpose,
    required this.steps,
    required this.startAt,
    required this.due,
    required this.progress,
    required this.todoCount,
    required this.doneCount,
    required this.assigneeIds,
    required this.status,
    required this.createdById,
    required this.createdAt,
    this.extensionReason,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    title: json['title'] as String,
    purpose: json['purpose'] as String? ?? '',
    steps: json['steps'] as String? ?? '',
    startAt: _time(json['startAt']) ?? _time(json['createdAt'])!,
    due: _time(json['due'])!,
    progress: json['progress'] as int? ?? 0,
    todoCount: json['todoCount'] as int? ?? 0,
    doneCount: json['doneCount'] as int? ?? 0,
    assigneeIds: [
      for (final id in (json['assigneeIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
    extensionReason: json['extensionReason'] as String?,
    status: ProjectStatus.parse(json['status'] as String?),
    createdById: json['createdById'] as String,
    createdAt: _time(json['createdAt'])!,
  );

  final String id;
  final String title;

  /// 무엇을 위한 프로젝트인지 (앱의 '설명')
  final String purpose;

  /// 진행 방법 — 줄바꿈으로 나눈 자유 텍스트. 체크리스트와는 다른 것이다
  final String steps;

  final DateTime startAt;

  /// 마감일 — 기한 연장이 승인되면 서버가 늘려 준다
  final DateTime due;

  /// 0~100. **체크리스트가 있으면 서버가 완료 비율로 계산한다** (없으면 수동값)
  final int progress;

  final int todoCount;
  final int doneCount;

  final List<String> assigneeIds;

  /// 마지막으로 승인된 연장 사유
  final String? extensionReason;

  final ProjectStatus status;
  final String createdById;
  final DateTime createdAt;
}

/// 체크리스트 한 줄 (서버 `ProjectTodoOut`)
class ProjectTodo {
  ProjectTodo({
    required this.id,
    required this.projectId,
    required this.content,
    required this.done,
    required this.sort,
    this.assigneeId,
  });

  factory ProjectTodo.fromJson(Map<String, dynamic> json) => ProjectTodo(
    id: json['id'] as String,
    projectId: json['projectId'] as String,
    content: json['content'] as String,
    assigneeId: json['assigneeId'] as String?,
    done: json['done'] as bool? ?? false,
    sort: json['sort'] as int? ?? 0,
  );

  final String id;
  final String projectId;
  final String content;

  /// 맡은 사람 — 안 정했으면 null
  final String? assigneeId;

  final bool done;

  /// 표시 순서 — 같으면 만든 순서로 온다
  final int sort;
}

/// 기한 변경 요청 (서버 `ProjectRequestOut`)
///
/// 승인은 **대표(MASTER)만** 한다. 승인되면 서버가 프로젝트 마감일을 바꾼다.
class ProjectRequest {
  ProjectRequest({
    required this.id,
    required this.projectId,
    required this.type,
    required this.newDue,
    required this.reason,
    required this.status,
    required this.requestedById,
    required this.createdAt,
    this.decidedById,
    this.decidedAt,
    this.rejectReason,
  });

  factory ProjectRequest.fromJson(Map<String, dynamic> json) => ProjectRequest(
    id: json['id'] as String,
    projectId: json['projectId'] as String,
    type: ProjectRequestType.parse(json['type'] as String?),
    newDue: _time(json['newDue'])!,
    reason: json['reason'] as String? ?? '',
    status: ProjectRequestStatus.parse(json['status'] as String?),
    requestedById: json['requestedById'] as String,
    decidedById: json['decidedById'] as String?,
    decidedAt: _time(json['decidedAt']),
    rejectReason: json['rejectReason'] as String?,
    createdAt: _time(json['createdAt'])!,
  );

  final String id;
  final String projectId;
  final ProjectRequestType type;

  /// 신청한 새 마감일
  final DateTime newDue;
  final String reason;
  final ProjectRequestStatus status;
  final String requestedById;
  final String? decidedById;
  final DateTime? decidedAt;
  final String? rejectReason;
  final DateTime createdAt;
}

DateTime? _time(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

/// `/projects` — 프로젝트·체크리스트·기한 변경 요청
///
/// 체크리스트를 건드릴 수 있는 사람은 **관리자·작성자·담당자**다
/// (서버 `_can_touch`). 그 외에는 403 이라 앱도 같은 기준으로 막는다.
class ProjectApi {
  ProjectApi._();

  static final _client = ApiClient.instance;

  /// 목록 (최신순). [status] 는 서버가 파생 상태를 계산한 뒤 거른다
  static Future<List<Project>> list({
    ProjectStatus? status,
    String? assigneeId,
    String? q,
  }) async {
    final rows = await _client.getList(
      '/projects',
      query: {'status': ?status?.wire, 'assigneeId': ?assigneeId, 'q': ?q},
    );
    return [
      for (final row in rows)
        Project.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<Project> create({
    required String title,
    required DateTime due,
    String purpose = '',
    String steps = '',
    DateTime? startAt,
    List<String> assigneeIds = const [],
  }) async {
    final data = await _client.post(
      '/projects',
      body: {
        'title': title,
        'purpose': purpose,
        'steps': steps,
        'startAt': ?startAt?.toUtc().toIso8601String(),
        'due': due.toUtc().toIso8601String(),
        'assigneeIds': assigneeIds,
      },
    );
    return Project.fromJson(data!);
  }

  /// 고치기 — 넘긴 값만 바뀐다.
  /// **진행률은 여기서 보내지 않는다** — 체크리스트가 있으면 서버가 덮어쓴다.
  static Future<Project> update(
    String id, {
    String? title,
    String? purpose,
    String? steps,
    DateTime? startAt,
    DateTime? due,
    List<String>? assigneeIds,
  }) async {
    final data = await _client.patch(
      '/projects/$id',
      body: {
        'title': ?title,
        'purpose': ?purpose,
        'steps': ?steps,
        'startAt': ?startAt?.toUtc().toIso8601String(),
        'due': ?due?.toUtc().toIso8601String(),
        'assigneeIds': ?assigneeIds,
      },
    );
    return Project.fromJson(data!);
  }

  static Future<void> delete(String id) => _client.delete('/projects/$id');

  // ── 체크리스트 ──

  /// [sort] 순, 같으면 만든 순
  static Future<List<ProjectTodo>> todos(String projectId) async {
    final rows = await _client.getList('/projects/$projectId/todos');
    return [
      for (final row in rows)
        ProjectTodo.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<ProjectTodo> addTodo(
    String projectId, {
    required String content,
    String? assigneeId,
    int sort = 0,
  }) async {
    final data = await _client.post(
      '/projects/$projectId/todos',
      body: {'content': content, 'assigneeId': ?assigneeId, 'sort': sort},
    );
    return ProjectTodo.fromJson(data!);
  }

  /// 완료 토글·내용 수정 — 어느 쪽이든 서버가 진행률을 다시 계산한다
  static Future<ProjectTodo> updateTodo(
    String projectId,
    String todoId, {
    String? content,
    String? assigneeId,
    bool? done,
    int? sort,
  }) async {
    final data = await _client.patch(
      '/projects/$projectId/todos/$todoId',
      body: {
        'content': ?content,
        'assigneeId': ?assigneeId,
        'done': ?done,
        'sort': ?sort,
      },
    );
    return ProjectTodo.fromJson(data!);
  }

  static Future<void> deleteTodo(String projectId, String todoId) =>
      _client.delete('/projects/$projectId/todos/$todoId');

  // ── 기한 변경 요청 ──

  /// 결재 대기 목록 등 — 프로젝트를 안 가리면 전체가 온다
  static Future<List<ProjectRequest>> requests({
    String? projectId,
    ProjectRequestStatus? status,
  }) async {
    final rows = await _client.getList(
      '/projects/requests',
      query: {'projectId': ?projectId, 'status': ?status?.wire},
    );
    return [
      for (final row in rows)
        ProjectRequest.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 기한 연장·누락 사유 올리기 — 대표 승인 전까지 마감일은 그대로다
  static Future<ProjectRequest> requestChange(
    String projectId, {
    required ProjectRequestType type,
    required DateTime newDue,
    required String reason,
  }) async {
    final data = await _client.post(
      '/projects/$projectId/requests',
      body: {
        'type': type.wire,
        'newDue': newDue.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
    return ProjectRequest.fromJson(data!);
  }

  /// 승인 (MASTER 전용) — 프로젝트 마감일이 새 날짜로 바뀐다
  static Future<ProjectRequest> approve(String requestId) async {
    final data = await _client.post('/projects/requests/$requestId/approve');
    return ProjectRequest.fromJson(data!);
  }

  /// 반려 (MASTER 전용) — 사유가 필수다
  static Future<ProjectRequest> reject(
    String requestId, {
    required String reason,
  }) async {
    final data = await _client.post(
      '/projects/requests/$requestId/reject',
      body: {'reason': reason},
    );
    return ProjectRequest.fromJson(data!);
  }
}
