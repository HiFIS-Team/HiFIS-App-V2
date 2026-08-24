import '../client/api_client.dart';
import '../notice/reaction_api.dart';

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
  overdue('OVERDUE'),

  /// 이름·설명·색을 이렇게 바꾸겠다 — **담당자만 올린다**
  edit('EDIT'),

  /// 프로젝트를 지우겠다 — **담당자만 올린다**
  delete('DELETE'),

  /// 참여 인원을 **더하겠다** — 담당자만 올린다 (2026-08-19)
  ///
  /// 빼는 길은 없다 — 할 일에 붙은 담당이 붕 뜨기 때문이다 (서버 주석 참고).
  members('MEMBERS');

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

/// 상세 타임라인 한 줄의 종류 (서버 `ProjectActivityKind`)
///
/// [comment] 만 사람이 쓴 글이고 나머지는 서버가 자동으로 쌓는 활동 기록이다.
/// 서버가 VARCHAR 로 들고 있어 종류가 늘 수 있으므로 모르는 값은 [other] 로
/// 떨어뜨린다 — 댓글이 아니라 시스템 기록으로 그려진다.
enum ProjectActivityKind {
  comment('COMMENT'),
  created('CREATED'),
  progress('PROGRESS'),
  todo('TODO'),
  due('DUE'),
  assignee('ASSIGNEE'),
  other('');

  const ProjectActivityKind(this.wire);

  final String wire;

  static ProjectActivityKind parse(String? value) =>
      ProjectActivityKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => ProjectActivityKind.other,
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
    required this.ownerId,
    required this.status,
    required this.createdById,
    required this.createdAt,
    this.color,
    this.extensionReason,
    this.completedAt,
    this.reactions = const [],
    this.commentCount = 0,
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
    ownerId: json['ownerId'] as String? ?? json['createdById'] as String,
    color: json['color'] as String?,
    extensionReason: json['extensionReason'] as String?,
    status: ProjectStatus.parse(json['status'] as String?),
    completedAt: _time(json['completedAt']),
    reactions: reactionsFromJson(json['reactions']),
    commentCount: json['commentCount'] as int? ?? 0,
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

  /// 프로젝트를 맡은 사람 — **만든 사람과 다를 수 있다** (대표가 만들어 맡긴다).
  /// 서버가 안 정한 옛 프로젝트에는 만든 사람을 채워서 준다
  final String ownerId;

  /// 만들 때 고른 색 (`#RRGGBB`).
  /// **null 이면 앱이 id 에서 만들어 쓴다** — 색 필드가 생기기 전에 올린 것들이다
  final String? color;

  /// 마지막으로 승인된 연장 사유
  final String? extensionReason;

  final ProjectStatus status;

  /// 완료한 시각 — **null 이면 아직 완료가 아니다** (2026-08-19).
  ///
  /// 예전에는 `progress == 100` 이 곧 완료였다. 이제 할 일을 다 체크해도
  /// **담당자가 완료를 눌러야** 채워진다 (`POST /projects/{id}/complete`).
  final DateTime? completedAt;

  /// 하트 집계 · 댓글 수 (2026-08-19) — 상세 오른쪽 세로 줄이 쓴다.
  /// 공지·회의록과 **같은 위젯**이라 같은 이름으로 받는다
  final List<ReactionAgg> reactions;
  final int commentCount;

  final String createdById;
  final DateTime createdAt;
}

/// 체크리스트 한 줄 (서버 `ProjectTodoOut`)
/// 프로젝트 달성 점수 한 건 (서버 `ProjectAwardOut`)
///
/// 완료하면 **담당자(PM)에게 10점 · 참여 멤버에게 5점**이 자동으로 붙고,
/// 그 위에서 MASTER 가 올리거나 깎는다 (2026-08-20).
/// 여기서 매긴 값이 그 사람의 **최종 점수**다 (더해지지 않는다).
class ProjectAward {
  ProjectAward({
    required this.id,
    required this.projectId,
    required this.employeeId,
    required this.points,
    required this.createdAt,
    this.comment,
    this.createdById,
  });

  factory ProjectAward.fromJson(Map<String, dynamic> json) => ProjectAward(
    id: json['id'] as String,
    projectId: json['projectId'] as String? ?? '',
    employeeId: json['employeeId'] as String? ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
    comment: json['comment'] as String?,
    createdById: json['createdById'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String projectId;
  final String employeeId;

  /// -100 ~ 100
  final int points;

  /// 점수 사유 — 부여할 때 필수다
  final String? comment;

  /// **null 이면 완료로 자동으로 붙은 점수**다 (사람이 매기면 그 사람 id)
  final String? createdById;

  final DateTime createdAt;

  /// 사람이 매긴 점수인지 — 완료 자동 점수와 갈라 보여준다
  bool get byPerson => createdById != null;
}

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

/// 상세 타임라인 한 줄 (서버 `ProjectActivityOut`)
///
/// 댓글과 시스템 활동이 **한 테이블에 같이 쌓여** 최신순으로 온다.
/// 가르는 건 [kind] 하나다.
class ProjectActivity {
  ProjectActivity({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.actorId,
    this.body,
  });

  factory ProjectActivity.fromJson(Map<String, dynamic> json) =>
      ProjectActivity(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        actorId: json['actorId'] as String?,
        kind: ProjectActivityKind.parse(json['kind'] as String?),
        body: json['body'] as String?,
        createdAt: _time(json['createdAt'])!,
        updatedAt: _time(json['updatedAt']) ?? _time(json['createdAt'])!,
      );

  final String id;
  final String projectId;

  /// 한 사람 — **null 이면 서버가 남긴 것**이다
  final String? actorId;

  final ProjectActivityKind kind;

  /// 댓글 본문 또는 활동 메시지 (`완료: 포스터 시안` 처럼 서버가 문장을 만들어 준다)
  final String? body;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComment => kind == ProjectActivityKind.comment;
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
    this.payload,
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
    // 수정·삭제 신청에는 기한이 없다
    newDue: _time(json['newDue']),
    // 서버는 `payload`(수정)와 `members`(인원 추가)를 갈라 보내는데, 앱은
    // 한 칸으로 받는다 — 한 번에 한 종류만 오므로 섞일 일이 없다.
    payload:
        (json['members'] as Map?)?.cast<String, dynamic>() ??
        (json['payload'] as Map?)?.cast<String, dynamic>(),
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

  /// 신청한 새 마감일 — 수정·삭제 신청에는 없다
  final DateTime? newDue;

  /// 수정 신청이 담은 '이렇게 바꾸겠다' (`title` · `purpose` · `color`).
  /// 승인 전에는 프로젝트에 안 쓰인다 — 결재하는 쪽이 무엇을 승인하는지
  /// 보려면 여기 들고 있어야 한다
  final Map<String, dynamic>? payload;
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

  /// 프로젝트를 만든다 — **체크리스트도 같이 보낸다**
  ///
  /// [todos] 는 `{content, assigneeId?, sort}` 목록이다. 예전에는 만든 뒤
  /// 할 일마다 `addTodo` 를 따로 불렀는데, 그 라우트가 **이 프로젝트 사람만**
  /// 통과시켜서 대표·관리자가 남에게 맡기는 프로젝트를 만들 때 403 이 났다.
  /// 한 요청으로 보내면 서버가 한 트랜잭션에 넣는다.
  static Future<Project> create({
    required String title,
    required DateTime due,
    String purpose = '',
    String steps = '',
    DateTime? startAt,
    List<String> assigneeIds = const [],
    String? ownerId,
    String? color,
    List<Map<String, dynamic>> todos = const [],
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
        // 안 주면 서버가 만든 사람을 담당으로 넣는다
        'ownerId': ?ownerId,
        'color': ?color,
        'todos': todos,
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
    String? ownerId,
    String? color,
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
        'ownerId': ?ownerId,
        'color': ?color,
      },
    );
    return Project.fromJson(data!);
  }

  static Future<void> delete(String id) => _client.delete('/projects/$id');

  /// 완료로 찍는다 — **담당자만** (2026-08-19)
  ///
  /// 할 일이 하나 이상 있고 **전부 체크돼야** 통과한다 (`TODOS_LEFT`).
  /// 예전에는 마지막 칸을 체크하는 순간 저절로 완료였다 — 그 한 번에 점수까지
  /// 붙어서 잘못 눌러도 되돌릴 사람이 대표뿐이었다.
  static Future<Project> complete(String id) async {
    final data = await _client.post('/projects/$id/complete');
    return Project.fromJson(data!);
  }

  /// 완료를 되돌린다 — **MASTER 만**. 자동으로 준 점수는 회수된다
  static Future<Project> reopen(String id) async {
    final data = await _client.post('/projects/$id/reopen');
    return Project.fromJson(data!);
  }

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

  // ── 상세 타임라인 (활동 기록 + 댓글) ──

  /// 최신순. 댓글과 시스템 활동이 섞여서 온다
  static Future<List<ProjectActivity>> activities(String projectId) async {
    final rows = await _client.getList('/projects/$projectId/activities');
    return [
      for (final row in rows)
        ProjectActivity.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  // 프로젝트 댓글 세 개는 걷어냈다 (2026-08-19) — 저장이 `comments` 로
  // 옮겨 가면서 공지·회의록과 같은 `CommentApi` 를 쓴다.

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
  /// 결재를 올린다 — 기한 연장 · 누락 사유 · 수정 · 삭제 네 종류가 같은 통로다
  ///
  /// 종류마다 채우는 칸이 다르다 (서버가 422 로 거른다).
  ///
  /// | 종류 | 채울 것 |
  /// |---|---|
  /// | `extension` · `overdue` | [newDue] |
  /// | `edit` | [payload] (`title` · `purpose` · `color` 중 하나 이상) |
  /// | `delete` | 없음 |
  /// | `members` | [addIds] (넣을 사람 uuid, 하나 이상) |
  static Future<ProjectRequest> requestChange(
    String projectId, {
    required ProjectRequestType type,
    required String reason,
    DateTime? newDue,
    Map<String, String>? payload,
    List<String>? addIds,
  }) async {
    final data = await _client.post(
      '/projects/$projectId/requests',
      body: {
        'type': type.wire,
        if (newDue != null) 'newDue': newDue.toUtc().toIso8601String(),
        'payload': ?payload,
        // 서버는 인원 추가만 이 칸으로 받는다 (`payload` 와 따로다)
        if (addIds != null) 'members': {'addIds': addIds},
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

  /// 프로젝트 달성 점수 목록 — 완료 자동 점수와 MASTER 가 매긴 것이 섞여 온다
  static Future<List<ProjectAward>> awards(String projectId) async {
    final rows = await _client.getList('/projects/$projectId/awards');
    return [
      for (final row in rows)
        ProjectAward.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 프로젝트 점수 매기기 (MASTER 전용) — 사유가 필수다.
  ///
  /// [employeeId] 를 안 주면 **담당자 전원**에게 같은 점수가 간다.
  /// 서버가 한 트랜잭션으로 처리해서 몇 명만 매겨진 상태가 안 남는다.
  /// 다시 매기면 **덮어쓴다** (더해지지 않는다).
  static Future<List<ProjectAward>> award(
    String projectId, {
    required int points,
    required String comment,
    String? employeeId,
  }) async {
    final rows = await _client.postList(
      '/projects/$projectId/award',
      body: {'employeeId': ?employeeId, 'points': points, 'comment': comment},
    );
    return [
      for (final row in rows)
        ProjectAward.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
