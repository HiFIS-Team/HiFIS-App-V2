import 'package:dio/dio.dart';

import '../client/api_client.dart';

/// 일지 종류 — 서버 `WorkoutKind`
///
/// PT 는 **결제한 회차 안에서만** 쓴다(회차 번호가 붙는다). 개인 운동은 회원이
/// 혼자 한 것이라 회차와 상관없이 몇 개든 쓴다.
enum WorkoutKind {
  pt('PT', 'PT 운동일지', '회차 추가'),
  personal('PERSONAL', '개인 운동', '개인 운동 추가');

  const WorkoutKind(this.wire, this.label, this.addLabel);

  final String wire;
  final String label;

  /// 목록 아래 버튼 글자
  final String addLabel;

  static WorkoutKind parse(String? value) => WorkoutKind.values.firstWhere(
    (k) => k.wire == value,
    orElse: () => WorkoutKind.personal,
  );
}

/// 자료 종류 — 서버 `WorkoutMediaKind`
enum WorkoutMediaKind {
  image('IMAGE'),
  video('VIDEO');

  const WorkoutMediaKind(this.wire);

  final String wire;

  static WorkoutMediaKind parse(String? value) =>
      value == 'VIDEO' ? WorkoutMediaKind.video : WorkoutMediaKind.image;
}

/// 웨이트 표 한 줄 — 운동부위 / 운동명 / 무게·횟수 / 세트수
///
/// 숫자가 아니라 **글자로 담는다.** 맨몸·밴드처럼 무게가 없는 운동이 많고,
/// "20kg x 12" 처럼 한 칸에 적는 게 트레이너가 쓰던 방식이다.
class WeightRow {
  const WeightRow({
    this.part = '',
    this.name = '',
    this.load = '',
    this.sets = '',
  });

  factory WeightRow.fromJson(Map<String, dynamic> json) => WeightRow(
    part: json['part'] as String? ?? '',
    name: json['name'] as String? ?? '',
    load: json['load'] as String? ?? '',
    sets: json['sets'] as String? ?? '',
  );

  final String part;
  final String name;
  final String load;
  final String sets;

  bool get isEmpty =>
      part.isEmpty && name.isEmpty && load.isEmpty && sets.isEmpty;

  Map<String, dynamic> toJson() => {
    'part': part,
    'name': name,
    'load': load,
    'sets': sets,
  };
}

/// 유산소 표 한 줄 — 운동명 / 시간
class CardioRow {
  const CardioRow({this.name = '', this.duration = ''});

  factory CardioRow.fromJson(Map<String, dynamic> json) => CardioRow(
    name: json['name'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
  );

  final String name;
  final String duration;

  bool get isEmpty => name.isEmpty && duration.isEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'duration': duration};
}

/// 올린 파일 하나
class MediaItem {
  const MediaItem({required this.url, required this.kind});

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    url: json['url'] as String,
    kind: WorkoutMediaKind.parse(json['kind'] as String?),
  );

  /// 서버가 준 주소 — 올릴 때는 `/uploads/..`, 받아 볼 때는 서명된 `/files/..`
  final String url;
  final WorkoutMediaKind kind;

  bool get isVideo => kind == WorkoutMediaKind.video;

  /// 띄울 수 있는 전체 주소
  String get fullUrl => fileUrl(url);

  Map<String, dynamic> toJson() => {'url': url, 'kind': kind.wire};
}

/// 자료 묶음 — 한 번에 올린 것들과 그에 대한 피드백 한 덩어리
///
/// **묶음으로 두는 이유** — 영상 하나 올리고 그 밑에 한마디, 다시 사진 셋을
/// 올리고 또 한마디를 쓰는 식이라 자료와 말이 붙어 다닌다.
class MediaGroup {
  const MediaGroup({this.items = const [], this.feedback = ''});

  factory MediaGroup.fromJson(Map<String, dynamic> json) => MediaGroup(
    items: [
      for (final row in (json['items'] as List? ?? const []))
        MediaItem.fromJson((row as Map).cast<String, dynamic>()),
    ],
    feedback: json['feedback'] as String? ?? '',
  );

  final List<MediaItem> items;
  final String feedback;

  bool get isEmpty => items.isEmpty && feedback.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'feedback': feedback,
  };
}

/// 운동일지 한 장 (서버 `WorkoutLogOut`)
class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.memberId,
    required this.kind,
    required this.title,
    required this.performedOn,
    this.authorId,
    this.sessionNo,
    this.weights = const [],
    this.cardio = const [],
    this.media = const [],
    this.trainerFeedback,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    memberId: json['memberId'] as String,
    kind: WorkoutKind.parse(json['kind'] as String?),
    sessionNo: json['sessionNo'] as int?,
    title: json['title'] as String? ?? '',
    performedOn: DateTime.parse(json['performedOn'] as String),
    authorId: json['authorId'] as String?,
    weights: [
      for (final row in (json['weights'] as List? ?? const []))
        WeightRow.fromJson((row as Map).cast<String, dynamic>()),
    ],
    cardio: [
      for (final row in (json['cardio'] as List? ?? const []))
        CardioRow.fromJson((row as Map).cast<String, dynamic>()),
    ],
    media: [
      for (final row in (json['media'] as List? ?? const []))
        MediaGroup.fromJson((row as Map).cast<String, dynamic>()),
    ],
    trainerFeedback: json['trainerFeedback'] as String?,
  );

  final String id;
  final String memberId;
  final WorkoutKind kind;

  /// 몇 회차인가 — PT 만 붙는다
  final int? sessionNo;

  /// 그날 뭘 했나 — "가슴, 삼두"
  final String title;

  /// 수업한 날 — 적은 날이 아니다 (시각은 안 쓴다)
  final DateTime performedOn;

  /// 쓴 사람 — **비어 있으면 회원이 자기 주소에서 직접 쓴 것**이다
  final String? authorId;

  final List<WeightRow> weights;
  final List<CardioRow> cardio;
  final List<MediaGroup> media;

  /// 개인 운동에 트레이너가 다는 총평
  final String? trainerFeedback;

  /// 목록·상단에 뜨는 줄 — `1회차(가슴, 삼두)` / `개인 운동 일지(하체)`
  String get heading {
    final part = title.trim().isEmpty ? '' : '($title)';
    return sessionNo == null ? '개인 운동 일지$part' : '$sessionNo회차$part';
  }

  int get exerciseCount => weights.length + cardio.length;

  int get photoCount {
    var count = 0;
    for (final group in media) {
      count += group.items.length;
    }
    return count;
  }
}

/// `/workouts` — 운동일지
///
/// 읽기는 그 회원을 볼 수 있으면 되고, **쓰기는 담당 트레이너와 점장·관리자만**
/// 된다 (서버가 막는다 — `NOT_MY_MEMBER`).
class WorkoutApi {
  WorkoutApi._();

  static final _client = ApiClient.instance;

  static Future<List<WorkoutLog>> list(
    String memberId, {
    WorkoutKind? kind,
  }) async {
    final rows = await _client.getList(
      '/workouts',
      query: {'memberId': memberId, 'kind': ?kind?.wire},
    );
    return [
      for (final row in rows)
        WorkoutLog.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 자료 올리기 — 돌려받은 것을 [create]·[update] 의 묶음에 실어 보낸다
  ///
  /// 사진은 10MB, 영상은 100MB 까지다. 종류는 **서버가 확장자로 정해** 준다.
  static Future<MediaItem> uploadMedia(String path, {String? filename}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final data = await _client.post('/workouts/media', body: form);
    return MediaItem.fromJson(data!);
  }

  /// 일지 만들기 — PT 는 [sessionNo] 를 안 주면 **서버가 다음 회차를 매긴다**
  ///
  /// 앱에서 세어 보내면 두 대가 동시에 저장했을 때 같은 회차가 두 번 생긴다.
  static Future<WorkoutLog> create({
    required String memberId,
    required WorkoutKind kind,
    required String title,
    required DateTime performedOn,
    int? sessionNo,
    List<WeightRow> weights = const [],
    List<CardioRow> cardio = const [],
    List<MediaGroup> media = const [],
    String? trainerFeedback,
  }) async {
    final data = await _client.post(
      '/workouts',
      body: {
        'memberId': memberId,
        'kind': kind.wire,
        'sessionNo': ?sessionNo,
        'title': title,
        'performedOn': dateOnly(performedOn),
        'weights': [for (final row in weights) row.toJson()],
        'cardio': [for (final row in cardio) row.toJson()],
        'media': [for (final group in media) group.toJson()],
        'trainerFeedback': ?trainerFeedback,
      },
    );
    return WorkoutLog.fromJson(data!);
  }

  /// 일지 고치기 — **회차와 종류는 못 바꾼다** (회차가 겹치거나 빈다)
  static Future<WorkoutLog> update(
    String id, {
    required String title,
    required DateTime performedOn,
    required List<WeightRow> weights,
    required List<CardioRow> cardio,
    required List<MediaGroup> media,
    String? trainerFeedback,
  }) async {
    final data = await _client.patch(
      '/workouts/$id',
      body: {
        'title': title,
        'performedOn': dateOnly(performedOn),
        'weights': [for (final row in weights) row.toJson()],
        'cardio': [for (final row in cardio) row.toJson()],
        'media': [for (final group in media) group.toJson()],
        'trainerFeedback': trainerFeedback ?? '',
      },
    );
    return WorkoutLog.fromJson(data!);
  }

  static Future<void> remove(String id) => _client.delete('/workouts/$id');
}

/// `2026-08-30` — 서버의 날짜 칸은 시각이 없다
String dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
