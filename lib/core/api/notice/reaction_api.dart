import '../client/api_client.dart';

/// 이모지 반응이 붙을 수 있는 것 (서버 `ReactionTargetType`)
enum ReactionTarget {
  notice('NOTICE'),
  meeting('MEETING'),
  message('MESSAGE'),
  project('PROJECT');

  const ReactionTarget(this.wire);

  final String wire;
}

/// 이모지 하나에 누른 사람들 (서버 `ReactionAgg`)
///
/// 사람별로 한 줄씩 오는 게 아니라 **이모지별로 묶여서** 온다.
/// 같은 사람이 같은 이모지를 두 번 누르면 빠진다 (토글).
class ReactionAgg {
  ReactionAgg({required this.emoji, required this.employeeIds});

  factory ReactionAgg.fromJson(Map<String, dynamic> json) => ReactionAgg(
    emoji: json['emoji'] as String,
    employeeIds: [
      for (final id in (json['employeeIds'] as List<dynamic>? ?? const []))
        id as String,
    ],
  );

  final String emoji;
  final List<String> employeeIds;

  int get count => employeeIds.length;

  bool minePressed(String? myId) => myId != null && employeeIds.contains(myId);
}

/// `/reactions` — 공지·회의록·사내톡 공통 이모지 토글
class ReactionApi {
  ReactionApi._();

  static final _client = ApiClient.instance;

  /// 누르기/취소 — 이미 누른 이모지면 빠진다.
  /// 토글 뒤의 **최신 집계 전체**가 돌아오므로 그대로 갈아끼우면 된다.
  static Future<List<ReactionAgg>> toggle({
    required ReactionTarget target,
    required String targetId,
    required String emoji,
  }) async {
    final data = await _client.post(
      '/reactions',
      body: {'targetType': target.wire, 'targetId': targetId, 'emoji': emoji},
    );
    return [
      for (final row in (data?['reactions'] as List<dynamic>? ?? const []))
        ReactionAgg.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}

/// 목록 응답에 실려 오는 반응 집계를 읽는다 (`NoticeOut.reactions` 등)
List<ReactionAgg> reactionsFromJson(dynamic value) => [
  for (final row in (value as List<dynamic>? ?? const []))
    ReactionAgg.fromJson((row as Map).cast<String, dynamic>()),
];
