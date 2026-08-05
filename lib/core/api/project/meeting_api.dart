import '../client/api_client.dart';
import '../notice/reaction_api.dart';

export '../notice/reaction_api.dart' show ReactionAgg, ReactionApi, ReactionTarget;

/// 회의록 공개 범위 (서버 `MeetingScope`)
enum MeetingScope {
  /// 전사 회의
  company('COMPANY'),

  /// 프로젝트 회의 — `projectId` 와 짝이다
  project('PROJECT'),

  /// 몇 사람끼리 한 회의
  people('PEOPLE');

  const MeetingScope(this.wire);

  final String wire;

  static MeetingScope parse(String? value) => MeetingScope.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => MeetingScope.company,
  );
}

/// 회의록 (서버 `MeetingOut`)
class Meeting {
  Meeting({
    required this.id,
    required this.title,
    required this.blocks,
    required this.scope,
    required this.attendeeIds,
    required this.authorId,
    required this.meetingAt,
    required this.createdAt,
    required this.reactions,
    this.projectId,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    blocks: json['blocks'] as List<dynamic>? ?? const [],
    scope: MeetingScope.parse(json['scope'] as String?),
    attendeeIds: [
      for (final id in (json['attendeeIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
    projectId: json['projectId'] as String?,
    authorId: json['authorId'] as String,
    meetingAt: DateTime.parse(json['meetingAt'] as String).toLocal(),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    reactions: reactionsFromJson(json['reactions']),
  );

  final String id;
  final String title;

  /// 본문 — **마크다운이 아니라 블록 트리다.**
  /// 앱은 `rich_blocks.dart` 로 마크다운과 옮겨 담는다
  final List<dynamic> blocks;

  final MeetingScope scope;

  /// 참석자 uuid — 이름은 `StaffDirectory` 에서 찾는다
  final List<String> attendeeIds;

  /// 묶인 프로젝트 — `scope` 가 project 일 때 쓴다
  final String? projectId;

  final String authorId;

  /// 회의를 한 날 (앱 목록이 이 날짜로 정렬한다)
  final DateTime meetingAt;

  final DateTime createdAt;

  /// 이모지별 누른 사람 — 목록 응답에 같이 실려 온다
  final List<ReactionAgg> reactions;
}

/// `/meetings` — 회의록
///
/// 작성은 전 직원, 수정·삭제는 **작성자 본인 또는 관리자·점장**이다
/// (서버 `_get_owned`). 앱도 같은 기준으로 편집 버튼을 감춘다.
class MeetingApi {
  MeetingApi._();

  static final _client = ApiClient.instance;

  /// 회의 날짜 최신순. [q] 는 제목만 훑는다
  static Future<List<Meeting>> list({MeetingScope? scope, String? q}) async {
    final rows = await _client.getList(
      '/meetings',
      query: {'scope': ?scope?.wire, 'q': ?q},
    );
    return [
      for (final row in rows)
        Meeting.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<Meeting> create({
    required String title,
    required List<dynamic> blocks,
    required DateTime meetingAt,
    MeetingScope scope = MeetingScope.company,
    List<String> attendeeIds = const [],
    String? projectId,
  }) async {
    final data = await _client.post(
      '/meetings',
      body: {
        'title': title,
        'blocks': blocks,
        'scope': scope.wire,
        'attendeeIds': attendeeIds,
        'projectId': ?projectId,
        'meetingAt': meetingAt.toUtc().toIso8601String(),
      },
    );
    return Meeting.fromJson(data!);
  }

  /// 고치기 — 넘긴 값만 바뀐다
  static Future<Meeting> update(
    String id, {
    String? title,
    List<dynamic>? blocks,
    MeetingScope? scope,
    List<String>? attendeeIds,
    String? projectId,
    DateTime? meetingAt,
  }) async {
    final data = await _client.patch(
      '/meetings/$id',
      body: {
        'title': ?title,
        'blocks': ?blocks,
        'scope': ?scope?.wire,
        'attendeeIds': ?attendeeIds,
        'projectId': ?projectId,
        'meetingAt': ?meetingAt?.toUtc().toIso8601String(),
      },
    );
    return Meeting.fromJson(data!);
  }

  /// 지우기 — 달려 있던 이모지 반응도 같이 지워진다
  static Future<void> delete(String id) => _client.delete('/meetings/$id');
}
