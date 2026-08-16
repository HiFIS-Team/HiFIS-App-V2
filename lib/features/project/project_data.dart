part of 'project_screen.dart';

// ── 데이터 ──

/// 할 일 한 건 (서버 `ProjectTodo`)
class _Todo {
  _Todo({required this.text, this.id, this.assignee, this.done = false});

  /// 서버 uuid — null 이면 아직 안 올린 것 (새 프로젝트 만들 때 미리 적은 항목)
  String? id;

  String text;
  String? assignee;
  bool done;
}

/// 타임라인 한 줄 (서버 `ProjectActivity`) — 댓글이면 comment = true
class _Event {
  _Event({
    required this.author,
    required this.text,
    required this.time,
    this.id,
    this.comment = false,
  });

  /// 서버 uuid — **댓글만 갖는다**. 시스템 기록은 고치거나 지울 수 없다
  final String? id;

  final String author;
  final String text;
  final DateTime time;
  final bool comment;
}

/// 프로젝트가 놓인 단계 — 목록 탭 순서와 같다
enum _Phase {
  running('진행 중'),
  done('완료'),
  missed('누락');

  const _Phase(this.label);

  final String label;
}

/// 기한 연장 신청 한 건 (승인 전까지 마감일은 그대로다)
/// 대기 중인 결재 한 건 — 기한 연장 · 누락 사유 · 수정 · 삭제
///
/// 프로젝트당 **하나뿐이다** (서버가 그렇게 막는다). 그래서 [_Project.request]
/// 가 하나이고, 상세의 결재 카드도 한 장만 뜬다.
class _Extension {
  _Extension({
    required this.requester,
    required this.reason,
    required this.time,
    this.type = ProjectRequestType.extension,
    this.due,
    this.payload,
    this.id,
  });

  /// 서버 요청 uuid — 승인·반려할 때 쓴다
  final String? id;

  final String requester;

  /// 무엇을 결재받는 건가 — 카드 문구와 승인했을 때 벌어지는 일이 갈린다
  final ProjectRequestType type;

  /// 신청한 새 마감일 — **기한 연장·누락 사유만 있다**
  final DateTime? due;

  /// 수정 신청이 담은 '이렇게 바꾸겠다' (`title` · `purpose` · `color`)
  final Map<String, dynamic>? payload;

  final String reason;
  final DateTime time;

  /// 승인되기 전까지는 프로젝트에 안 쓰인다 — 카드에 견줘 보여줄 때 쓴다
  String? get newTitle => payload?['title'] as String?;
  String? get newPurpose => payload?['purpose'] as String?;
  String? get newColor => payload?['color'] as String?;
}

/// 프로젝트 한 건 — 진행률은 할 일에서 계산한다
class _Project {
  _Project({
    required this.name,
    required this.desc,
    required this.owner,
    required this.start,
    required this.due,
    required this.members,
    required this.todos,
    required this.events,
    this.id,
    this.colorHex,
    this.createdById,
    this.ownerId,
    this.memberIds = const [],
    this.serverProgress = 0,
    this.serverTodoCount = 0,
    this.serverDoneCount = 0,
    this.request,
  });

  /// 서버 uuid — null 이면 아직 안 올린 것
  String? id;

  String name;
  String desc;

  /// 만들 때 고른 색 (`#RRGGBB`) — 서버가 들고 있다.
  /// 색 필드가 생기기 전에 올린 프로젝트는 null 이라 [color] 가 대신 만들어 낸다
  String? colorHex;

  String owner;

  /// 만든 사람 uuid — 화면에는 안 쓰고 서버 응답을 그대로 들고만 있는다.
  /// **손댈 권한과 상관없다** ([_isMember] 는 담당자·참여 멤버만 본다)
  final String? createdById;

  /// 담당자 uuid — 이름([owner])은 동명이인에 걸려서 권한 판정에 못 쓴다
  final String? ownerId;
  DateTime start;

  /// 마감일 — 기한 연장이 승인되면 늘어난다
  DateTime due;

  final List<String> members;

  /// 참여자 uuid — 서버에 보낼 때 쓴다. [members] 와 같은 사람들이다
  List<String> memberIds;

  final List<_Todo> todos;

  /// 활동 기록·댓글 — 서버 타임라인(`GET /projects/{id}/activities`).
  /// 댓글과 시스템 활동이 한 줄기로 섞여 최신순으로 온다
  final List<_Event> events;

  /// 체크리스트를 받아왔는지 — 상세를 열 때 한 번만 받는다.
  /// 새로 만든 프로젝트는 만들면서 바로 채우므로 [_saveNewProject] 가 켠다.
  bool todosLoaded = false;

  /// 타임라인을 받아왔는지 — 체크리스트와 같이 상세를 열 때 받는다
  bool eventsLoaded = false;

  /// 상세를 받는 중인 요청 — [_loadDetail] 이 붙잡아 둔다
  Future<void>? loading;

  /// 상세에 필요한 걸 다 받았는지
  bool get detailLoaded => todosLoaded && eventsLoaded;

  /// 목록 띠·진행률 막대에 쓰는 색.
  /// 서버 값이 없거나 못 읽으면 id 에서 만들어 쓴다 — 어느 기기에서나 같은 색이 나온다
  Color get color => _hexColor(colorHex) ?? _projectColor(id ?? name);

  /// 목록에서 쓰는 서버 값. 체크리스트를 받기 전에는 이걸로 그린다
  int serverProgress;
  int serverTodoCount;
  int serverDoneCount;

  /// 결재를 기다리는 기한 연장 신청 (없으면 null)
  _Extension? request;

  int get todoCount => todosLoaded ? todos.length : serverTodoCount;

  int get doneCount =>
      todosLoaded ? todos.where((t) => t.done).length : serverDoneCount;

  /// 0~1. 체크리스트가 있으면 완료 비율, 없으면 서버가 들고 있는 수동값.
  /// **서버 `_recompute_progress` 와 같은 규칙이다.**
  double get progress =>
      todoCount == 0 ? serverProgress / 100 : doneCount / todoCount;

  /// 단계는 따로 관리하지 않고 진행률과 마감일에서 끌어낸다.
  /// 서버 `_status` 와 같은 순서로 판정하되, **서버의 `WAITING`(진행률 0)은
  /// 진행 중에 합친다** — 앱 탭이 진행 중·완료·누락 셋뿐이다.
  _Phase get phase {
    if (progress >= 1) return _Phase.done;
    if (_dday(due) < 0) return _Phase.missed;
    return _Phase.running;
  }
}

/// 올라온 프로젝트 — 서버에서 받아 온다.
/// 탭을 오가도 다시 받지 않도록 모듈 전역으로 둔다.
final _projects = <_Project>[];

/// 한 번이라도 받아왔는지 — 탭을 다시 열 때 빈 목록을 깜빡이지 않게 한다
bool _projectsLoaded = false;

/// 로그아웃 때 비운다 — **다음 사람에게 앞사람 것이 보이면 안 된다**
void resetProjectCache() {
  _projects.clear();
  _projectsLoaded = false;
}

Future<void> _loadProjects() async {
  // 결재 대기 중인 기한 변경 요청을 같이 받아 프로젝트에 붙인다
  final listing = ProjectApi.list();
  final pending = ProjectApi.requests(status: ProjectRequestStatus.pending);
  final rows = await listing;
  final requests = <String, ProjectRequest>{
    for (final request in await pending) request.projectId: request,
  };

  _projects
    ..clear()
    ..addAll([for (final row in rows) _fromServer(row, requests[row.id])]);
  _projectsLoaded = true;
}

/// 서버 프로젝트 → 화면 모델
///
/// 체크리스트와 타임라인은 여기서 안 받는다. 목록에는 개수(`todoCount`·
/// `doneCount`)만 있으면 되고, 나머지는 상세를 열 때 [_loadTodos]·
/// [_loadActivities] 로 받는다.
_Project _fromServer(Project row, ProjectRequest? request) {
  return _Project(
    id: row.id,
    name: row.title,
    desc: row.purpose,
    colorHex: row.color,
    owner: _nameOf(row.ownerId),
    createdById: row.createdById,
    ownerId: row.ownerId,
    start: row.startAt,
    due: row.due,
    members: [for (final id in row.assigneeIds) _nameOf(id)]
      ..removeWhere((name) => name.isEmpty),
    memberIds: row.assigneeIds,
    todos: [],
    events: [],
    serverProgress: row.progress,
    serverTodoCount: row.todoCount,
    serverDoneCount: row.doneCount,
    request: request == null
        ? null
        : _Extension(
            id: request.id,
            requester: _nameOf(request.requestedById),
            type: request.type,
            due: request.newDue,
            payload: request.payload,
            reason: request.reason,
            time: request.createdAt,
          ),
  );
}

/// uuid → 이름. 명단에 없으면(퇴사자 등) 빈 문자열
String _nameOf(String id) => StaffDirectory.instance.byId(id)?.name ?? '';

/// 색 필드가 생기기 전에 올린 프로젝트에 쓰는 대체 색
///
/// 카드 띠·진행률 막대가 색으로 프로젝트를 가르므로 비워 둘 수 없다.
/// id 에서 만들어서 어느 기기에서나 같은 색이 나오게 한다.
const _projectColors = [
  AppColors.primary,
  AppColors.error,
  AppColors.warning,
  AppColors.success,
  AppColors.violet,
  AppColors.teal,
  AppColors.pink,
];

Color _projectColor(String key) =>
    _projectColors[key.hashCode.abs() % _projectColors.length];

/// `#RRGGBB` → 색. 못 읽으면 null (아바타 색과 같은 규칙이다)
Color? _hexColor(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final rgb = int.tryParse(hex, radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

/// 색 → `#RRGGBB`. 서버는 이 형식으로만 받는다
/// 프로젝트를 구분하는 색 — 빨강은 D-day 배지와 헷갈려서 뺐다
///
/// **만들기 폼과 수정 창이 같이 쓴다.** 한쪽에만 있는 색이 생기면 그 색으로
/// 만든 프로젝트를 나중에 못 고친다.
const _projectPalette = [
  AppColors.primary,
  AppColors.violet,
  AppColors.teal,
  AppColors.success,
  AppColors.warning,
  Color(0xFF8B95A1),
];

String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 상세를 열 때 체크리스트를 받는다 — 한 번 받으면 다시 받지 않는다
Future<void> _loadTodos(_Project project) async {
  final id = project.id;
  if (id == null || project.todosLoaded) return;
  final rows = await ProjectApi.todos(id);
  project.todos
    ..clear()
    ..addAll([
      for (final row in rows)
        _Todo(
          id: row.id,
          text: row.content,
          assignee: row.assigneeId == null ? null : _nameOf(row.assigneeId!),
          done: row.done,
        ),
    ]);
  project.todosLoaded = true;
}

/// 상세를 열 때 타임라인을 받는다 — 한 번 받으면 다시 받지 않는다.
///
/// 화면에서 미리 끼워 넣은 줄(체크 완료·연장 신청 등)은 여기서 **서버 것으로
/// 통째로 갈린다.** 서버가 안 남기는 활동은 그때 사라진다 (backend-gap.md 3번).
Future<void> _loadActivities(_Project project) async {
  final id = project.id;
  if (id == null || project.eventsLoaded) return;
  final rows = await ProjectApi.activities(id);
  project.events
    ..clear()
    ..addAll([for (final row in rows) _eventFrom(row)]);
  project.eventsLoaded = true;
}

/// 상세에 필요한 것(체크리스트·타임라인)을 한 번에 받는다.
///
/// 이미 받았으면 바로 끝나고, **받는 중이면 그 요청에 얹힌다.**
/// 데스크톱은 빌드마다 여는 콜백이 걸려서 플래그만으로는 첫 응답이 오기 전에
/// 한 번 더 나간다 (실제 발생 — `activities` 가 두 번 찍혔다).
Future<void> _loadDetail(_Project project) {
  if (project.detailLoaded) return Future.value();
  return project.loading ??= Future.wait([
    _loadTodos(project),
    _loadActivities(project),
    // 실패한 요청은 남기지 않는다 — 붙잡아 두면 다시 열어도 영영 못 받는다
  ]).whenComplete(() => project.loading = null);
}

/// 서버 타임라인 한 줄 → 화면 모델
_Event _eventFrom(ProjectActivity row) => _Event(
  // 시스템 기록은 고치거나 지울 수 없어서 id 를 들고 있을 필요가 없다
  id: row.isComment ? row.id : null,
  author: _actorName(row.actorId),
  text: row.body ?? '',
  time: row.createdAt,
  comment: row.isComment,
);

/// 활동을 남긴 사람 — null 이면 서버가 남긴 것이다
String _actorName(String? id) {
  if (id == null) return '시스템';
  final name = _nameOf(id);
  return name.isEmpty ? '알 수 없음' : name;
}

/// 새 프로젝트를 서버에 올린다 — **요청 한 번이다**
///
/// 폼에서 미리 적어 둔 체크리스트를 같이 실어 보내면 서버가 한 트랜잭션에
/// 넣어 준다.
///
/// 예전에는 프로젝트를 먼저 만들고 할 일마다 `addTodo` 를 따로 불렀다.
/// 그런데 할 일 추가는 **이 프로젝트 사람만** 할 수 있어서(2026-08-14),
/// **대표·관리자가 남에게 맡기는 프로젝트를 만들면 거기서 403 이 났다**
/// (`이 프로젝트의 담당자만 할 수 있습니다` — 실제로 겪었다).
/// 만드는 김에 붙이는 것이지 남의 프로젝트를 손대는 것이 아니다.
///
/// 덤으로 **반쯤 만들어진 프로젝트가 안 남는다** — 예전에는 할 일 추가가
/// 중간에 실패하면 체크리스트가 모자란 프로젝트가 그대로 섰다.
Future<_Project> _saveNewProject(_Project draft) async {
  final created = await ProjectApi.create(
    title: draft.name,
    purpose: draft.desc,
    startAt: draft.start,
    due: draft.due,
    assigneeIds: [
      for (final name in draft.members)
        ?StaffDirectory.instance.byName(name)?.id,
    ],
    // 안 고르면 서버가 만든 사람을 담당으로 넣는다
    ownerId: StaffDirectory.instance.byName(draft.owner)?.id,
    color: draft.colorHex,
    todos: [
      for (var i = 0; i < draft.todos.length; i++)
        {
          'content': draft.todos[i].text,
          'assigneeId': StaffDirectory.instance
              .byName(draft.todos[i].assignee ?? '')
              ?.id,
          'sort': i,
        },
    ],
  );

  final project = _fromServer(created, null);
  // 방금 적은 것이라 다시 받을 필요가 없다
  await _loadTodos(project);
  // 타임라인은 서버가 '프로젝트를 만들었어요' 한 줄을 이미 쌓아 뒀다
  await _loadActivities(project);
  return project;
}

/// 담당자 이름 → uuid. 서버는 사람을 uuid 로만 받는다
String? _idOfMember(_Project project, String? name) {
  if (name == null || name.isEmpty) return null;
  for (final id in project.memberIds) {
    if (_nameOf(id) == name) return id;
  }
  return StaffDirectory.instance.byName(name)?.id;
}

// ── 표시용 계산 ──

/// 마감까지 남은 일수 (오늘 기준, 지났으면 음수)
int _dday(DateTime due) {
  final now = DateTime.now();
  return DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// '7.30' 형태
String _date(DateTime time) => dateLabel(time);

/// '방금 · 12분 전 · 3시간 전 · 7.28' 형태
String _relative(DateTime time) => agoLabel(time);
