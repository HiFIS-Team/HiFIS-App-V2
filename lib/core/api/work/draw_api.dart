import '../client/api_client.dart';

/// 달마다 도는 추첨 한 건 (서버 `DrawOut`)
///
/// 전달에 친절도 설문을 낸 회원 중 **세 명**을 뽑아 매장 TV 가 게임으로 굴려
/// 보여준다. 여기서 더 받는 것은 **찍어 둔 게임 영상**이다 — 인스타에
/// 올리려고 서버가 매월 1일 새벽에 구워 둔다.
class MonthDraw {
  MonthDraw({
    required this.period,
    required this.game,
    required this.branchId,
    required this.branchName,
    required this.winners,
    required this.entryCount,
    this.videoUrl,
    this.videoAt,
  });

  factory MonthDraw.fromJson(Map<String, dynamic> json) => MonthDraw(
    period: json['period'] as String,
    game: json['game'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    branchName: json['branchName'] as String? ?? '',
    winners: [
      for (final w in (json['winners'] as List? ?? []))
        DrawWinner.fromJson((w as Map).cast<String, dynamic>()),
    ],
    entryCount: json['entryCount'] as int? ?? 0,
    videoUrl: json['videoUrl'] as String?,
    videoAt: json['videoAt'] == null
        ? null
        : DateTime.parse(json['videoAt'] as String).toLocal(),
  );

  /// 이벤트가 열린 달 `YYYY-MM` — 대상은 **그 전달** 설문이다
  final String period;

  /// 그달 TV 가 튼 게임 — `RACE` · `HOOPS` · `SOCCER` · `CURLING` · `CLAW` · `SUMO`
  final String game;
  final String branchId;
  final String branchName;

  /// 앞에서부터 1·2·3등. 참가자가 셋보다 적으면 그만큼만
  final List<DrawWinner> winners;

  /// 그달 참가자 수 — '몇 명 중에서' 를 보여주는 값
  final int entryCount;

  /// 찍어 둔 게임 영상 — **아직 안 구웠으면 null**
  ///
  /// 매월 1일 새벽에 서버가 굽는다. 그 사이거나 굽다 실패했으면 비어 있다.
  final String? videoUrl;
  final DateTime? videoAt;

  bool get hasVideo => (videoUrl ?? '').isNotEmpty;

  /// `2026-09` → `9월`
  String get monthLabel => '${int.parse(period.substring(5))}월';

  /// 그달 게임 이름 — 화면에 그대로 쓴다
  String get gameLabel => switch (game) {
    'RACE' => '구슬 레이스',
    'HOOPS' => '농구',
    'SOCCER' => '축구',
    'CURLING' => '컬링',
    'CLAW' => '뽑기',
    'SUMO' => '밀어내기',
    'PINBALL' => '핀볼',
    _ => '추첨 게임',
  };
}

/// 당첨자 한 명 — 이름은 서버가 `김○후` 로 가려서 준다
class DrawWinner {
  DrawWinner({required this.rank, required this.name});

  factory DrawWinner.fromJson(Map<String, dynamic> json) => DrawWinner(
    rank: json['rank'] as int? ?? 0,
    name: json['name'] as String? ?? '',
  );

  final int rank;
  final String name;
}

class DrawApi {
  static final _client = ApiClient.instance;

  /// 볼 수 있는 추첨 — **최근 달부터.**
  ///
  /// 직원·점장은 자기 지점만, MASTER·ADMIN 은 [branchId] 를 안 주면 전 지점이
  /// 같이 온다 (서버 `branch_filter` — 업무 화면 지점 고르개와 같은 규칙).
  static Future<List<MonthDraw>> list({
    String? branchId,
    String? period,
  }) async {
    final data = await _client.getList(
      '/draws',
      query: {'branchId': ?branchId, 'period': ?period},
    );
    return [
      for (final row in data)
        MonthDraw.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 영상 내려받기 — [MonthDraw.videoUrl] 의 서명된 주소를 그대로 넘긴다
  ///
  /// 주소에 붙은 서명은 7일이면 만료된다. 목록을 받을 때 갓 서명된 것이라
  /// 화면을 열어 두고 그만큼 지나는 일은 없지만, 그렇게 됐으면 화면을
  /// 다시 열면 새 서명이 온다.
  static Future<List<int>> video(String signedUrl) =>
      _client.getBytes(signedUrl);
}
