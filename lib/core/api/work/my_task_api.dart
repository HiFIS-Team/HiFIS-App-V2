import '../client/api_client.dart';

export '../client/period.dart' show dateKey;

/// 내 업무 수정·삭제 결재 종류 (서버 `MyTaskRequestType`)
enum MyTaskRequestType {
  edit('EDIT', '수정'),
  delete('DELETE', '삭제');

  const MyTaskRequestType(this.wire, this.label);

  final String wire;
  final String label;

  static MyTaskRequestType parse(String? value) => MyTaskRequestType.values
      .firstWhere((t) => t.wire == value, orElse: () => MyTaskRequestType.edit);
}

/// 결재 상태 (서버 `ProjectRequestStatus` 와 같은 값)
enum MyTaskRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const MyTaskRequestStatus(this.wire);

  final String wire;

  static MyTaskRequestStatus parse(String? value) =>
      MyTaskRequestStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => MyTaskRequestStatus.pending,
      );
}

/// 내 업무 수정·삭제 결재 (서버 `MyTaskRequestOut`)
class MyTaskRequest {
  MyTaskRequest({
    required this.id,
    required this.myTaskId,
    required this.type,
    required this.reason,
    required this.status,
    required this.requestedById,
    required this.createdAt,
    this.payload,
    this.rejectReason,
    this.requesterName,
    this.taskContent,
  });

  factory MyTaskRequest.fromJson(Map<String, dynamic> json) => MyTaskRequest(
    id: json['id'] as String,
    myTaskId: json['myTaskId'] as String,
    type: MyTaskRequestType.parse(json['type'] as String?),
    reason: json['reason'] as String? ?? '',
    status: MyTaskRequestStatus.parse(json['status'] as String?),
    requestedById: json['requestedById'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
    rejectReason: json['rejectReason'] as String?,
    requesterName: json['requesterName'] as String?,
    taskContent: json['taskContent'] as String?,
  );

  final String id;
  final String myTaskId;
  final MyTaskRequestType type;

  /// 고치겠다는 값 — 수정일 때만 `{"content": ..., "weekdays": [...]}`
  ///
  /// **둘 다 늘 실려 온다.** 요일만 고쳐도 서버가 지금 내용을 같이 담아 줘서,
  /// 결재하는 쪽이 바뀐 칸만이 아니라 **최종 모습**을 본다.
  final Map<String, dynamic>? payload;

  final String reason;
  final MyTaskRequestStatus status;
  final String requestedById;
  final String? rejectReason;
  final DateTime createdAt;

  /// 결재 화면이 '누가 무엇을' 을 그릴 수 있게 서버가 붙여 준다
  final String? requesterName;
  final String? taskContent;

  /// 고치겠다는 내용 — 수정이 아니면 빈 문자열
  String get newContent => (payload?['content'] as String?) ?? '';

  /// 고치겠다는 요일 — 안 실려 있으면 매일 (요일이 생기기 전 결재)
  List<int> get newWeekdays => parseWeekdays(payload?['weekdays']);
}

/// 매일 — 요일을 안 고르면 이 값이다 (서버 `EVERY_DAY` 와 같다)
const everyWeekday = [1, 2, 3, 4, 5, 6, 7];

/// 서버가 준 요일을 추려서 **차례대로** 담는다 (ISO 1=월 … 7=일)
///
/// 비어 있거나 없으면 매일로 본다 — 하나도 안 걸린 업무는 영영 안 뜬다.
List<int> parseWeekdays(Object? raw) {
  if (raw is! List) return const [...everyWeekday];
  final days = {
    for (final d in raw)
      if (d is int && d >= 1 && d <= 7) d,
  }.toList()..sort();
  return days.isEmpty ? const [...everyWeekday] : days;
}

/// 요일이 매일인가 — 목록 줄에 표시를 붙일지 정한다
bool isEveryWeekday(List<int> days) => days.length == 7;

/// `금` · `월·수·금` — **매일이면 빈 문자열**이다 (붙일 것이 없다)
String weekdayLabel(List<int> days) {
  if (isEveryWeekday(days)) return '';
  const names = ['월', '화', '수', '목', '금', '토', '일'];
  return [for (final d in days) names[d - 1]].join('·');
}

/// 내 업무 한 줄 (서버 `MyTaskOut`)
///
/// 공통 업무(환경정비 칩)와 달리 **하루에 한 번만** 체크한다.
class MyTask {
  MyTask({
    required this.id,
    required this.employeeId,
    required this.content,
    required this.weekdays,
    required this.sort,
    required this.checked,
    required this.createdAt,
    this.pendingRequest,
  });

  factory MyTask.fromJson(Map<String, dynamic> json) => MyTask(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    content: json['content'] as String,
    weekdays: parseWeekdays(json['weekdays']),
    sort: json['sort'] as int? ?? 0,
    checked: json['checked'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    pendingRequest: json['pendingRequest'] == null
        ? null
        : MyTaskRequest.fromJson(
            (json['pendingRequest'] as Map).cast<String, dynamic>(),
          ),
  );

  final String id;
  final String employeeId;
  final String content;

  /// 돌아오는 요일 (ISO 1=월 … 7=일) — 그날 목록에는 **걸린 것만** 온다
  ///
  /// 금요일에만 하는 대청소가 월~목에도 서서 안 누른 나흘이 누락으로 잡히던
  /// 자리다 (2026-08-20). 기존 업무는 전부 매일이다.
  final List<int> weekdays;

  final int sort;

  /// 오늘 했는가
  final bool checked;

  /// 결재를 기다리는 수정·삭제 — 있으면 그동안 손댈 수 없다
  final MyTaskRequest? pendingRequest;

  final DateTime createdAt;
}

/// 하루치 내 업무 (서버 `MyTaskDayOut`)
class MyTaskDay {
  MyTaskDay({
    required this.date,
    required this.tasks,
    required this.total,
    required this.done,
    required this.complete,
  });

  factory MyTaskDay.fromJson(Map<String, dynamic> json) => MyTaskDay(
    date: DateTime.parse(json['date'] as String),
    tasks: [
      for (final row in (json['tasks'] as List? ?? const []))
        MyTask.fromJson((row as Map).cast<String, dynamic>()),
    ],
    total: json['total'] as int? ?? 0,
    done: json['done'] as int? ?? 0,
    complete: json['complete'] as bool? ?? false,
  );

  final DateTime date;
  final List<MyTask> tasks;
  final int total;
  final int done;

  /// 다 했는가 — **항목이 하나도 없으면 false** (할 일을 안 정한 것이다)
  final bool complete;

  /// 아직 안 한 것이 있는가 — 이 상태로 퇴근하면 서버가 알림을 보낸다
  bool get missing => total > 0 && done < total;
}

/// 대표·관리자가 보는 사람 한 줄 (서버 `MyTaskRosterRow`)
class MyTaskRosterRow {
  MyTaskRosterRow({
    required this.employeeId,
    required this.name,
    required this.total,
    required this.done,
    required this.complete,
  });

  factory MyTaskRosterRow.fromJson(Map<String, dynamic> json) =>
      MyTaskRosterRow(
        employeeId: json['employeeId'] as String,
        name: json['name'] as String,
        total: json['total'] as int? ?? 0,
        done: json['done'] as int? ?? 0,
        complete: json['complete'] as bool? ?? false,
      );

  final String employeeId;

  /// 서버가 이름을 그대로 준다 — 명단을 못 받은 화면에서도 빈칸이 안 된다
  final String name;

  final int total;
  final int done;
  final bool complete;

  /// 아직 안 한 것이 있는가 — 업무를 안 정한 사람은 여기 안 든다
  bool get missing => total > 0 && done < total;
}

/// `/my-tasks` — 내 업무
class MyTaskApi {
  MyTaskApi._();

  static final _client = ApiClient.instance;

  /// 하루치 목록 — [date] 를 비우면 오늘
  ///
  /// [employeeId] 는 **대표·관리자만** 쓴다 (남의 것 보기). 그 밖이 넣으면
  /// 서버가 조용히 본인 것을 준다.
  static Future<MyTaskDay> day({String? date, String? employeeId}) async {
    final data = await _client.get(
      '/my-tasks',
      query: {'date': ?date, 'employeeId': ?employeeId},
    );
    return MyTaskDay.fromJson(data);
  }

  /// 오늘 누가 몇 개 중 몇 개를 했나 — **대표·관리자만** (그 밖에는 403)
  static Future<List<MyTaskRosterRow>> roster({
    String? date,
    String? branchId,
  }) async {
    final rows = await _client.getList(
      '/my-tasks/roster',
      query: {'date': ?date, 'branchId': ?branchId},
    );
    return [
      for (final row in rows)
        MyTaskRosterRow.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 추가 — **결재 없이 바로 들어간다.** 여러 개를 한 번에 보낸다.
  ///
  /// 줄마다 따로 부르면 중간에 끊겼을 때 반만 들어간 채로 화면이 닫힌다.
  /// 서버가 한 트랜잭션으로 만든다.
  ///
  /// [weekdays] 는 **이 묶음 전체에 걸린다** — 한 번에 적은 줄들은 같은
  /// 자리에서 같이 정한 것이라 요일도 같다. 안 주면 매일이다.
  static Future<List<MyTask>> create(
    List<String> contents, {
    List<int>? weekdays,
  }) async {
    final rows = await _client.postList(
      '/my-tasks',
      body: {'contents': contents, 'weekdays': ?weekdays},
    );
    return [
      for (final row in rows)
        MyTask.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 오늘 했다고 표시 (멱등)
  static Future<void> check(String id) =>
      _client.post('/my-tasks/$id/check').then((_) {});

  /// 체크 해제 — 오늘 것만
  static Future<void> uncheck(String id) =>
      _client.delete('/my-tasks/$id/check').then((_) {});

  /// 수정·삭제 신청 — 승인 전에는 항목이 안 바뀐다
  ///
  /// **내용·요일 중 하나만 보내도 된다.** 안 보낸 칸은 서버가 지금 값을
  /// 그대로 채워서, 결재하는 쪽이 최종 모습을 본다. 둘 다 그대로면 400.
  static Future<MyTaskRequest> request(
    String id, {
    required MyTaskRequestType type,
    required String reason,
    String? content,
    List<int>? weekdays,
  }) async {
    final data = await _client.post(
      '/my-tasks/$id/requests',
      body: {
        'type': type.wire,
        'reason': reason,
        if (type == MyTaskRequestType.edit)
          'payload': {'content': ?content, 'weekdays': ?weekdays},
      },
    );
    return MyTaskRequest.fromJson(data!);
  }

  /// 결재 목록 — MASTER 는 전원 것, 그 밖은 본인이 올린 것만
  static Future<List<MyTaskRequest>> requests({
    MyTaskRequestStatus? status,
  }) async {
    final rows = await _client.getList(
      '/my-task-requests',
      query: {'status': ?status?.wire},
    );
    return [
      for (final row in rows)
        MyTaskRequest.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<MyTaskRequest> approve(String requestId) async {
    final data = await _client.post('/my-task-requests/$requestId/approve');
    return MyTaskRequest.fromJson(data!);
  }

  static Future<MyTaskRequest> reject(String requestId, String reason) async {
    final data = await _client.post(
      '/my-task-requests/$requestId/reject',
      query: {'reason': reason},
    );
    return MyTaskRequest.fromJson(data!);
  }
}
