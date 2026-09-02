import 'package:dio/dio.dart';

import '../client/api_client.dart';

export '../client/period.dart' show dateKey, periodKey;

/// 환경정비 항목 (서버 `EnvItemOut`)
///
/// 지점마다 항목과 배점을 따로 갖는다. 지점에 항목이 하나도 없으면
/// 서버가 조회할 때 기본 22개를 자동으로 심는다.
class EnvItem {
  EnvItem({
    required this.id,
    required this.branchId,
    required this.name,
    required this.points,
    required this.editable,
    required this.sortOrder,
  });

  factory EnvItem.fromJson(Map<String, dynamic> json) => EnvItem(
    id: json['id'] as String,
    branchId: json['branchId'] as String,
    name: json['name'] as String,
    points: json['points'] as int,
    editable: json['editable'] as bool? ?? true,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );

  final String id;
  final String branchId;
  final String name;

  /// 한 번 할 때마다 쌓이는 환경정비 점수
  final int points;

  /// 점장이 이름·배점을 고칠 수 있는 항목인지 (기본 항목은 잠겨 있다)
  final bool editable;

  /// 화면에 세우는 순서 — **서버가 정한다**
  ///
  /// 배점 순으로 오면 매일 여러 번 누르는 세탁(1점)이 맨 아래로 가고
  /// 어쩌다 하는 현수막(10점)이 맨 위에 온다. 그래서 서버가 하루 일하는
  /// 흐름대로 번호를 매겨 준다 (빨래·청소 → 관리 → 홍보 → 기타).
  final int sortOrder;
}

/// 환경정비 수행 기록 (서버 `EnvTaskLogOut`)
///
/// 항목 이름과 배점을 **찍은 시점 값으로 복사**해 둔다. 나중에 항목 배점이
/// 바뀌어도 예전 기록은 그때 점수 그대로 남는다.
class EnvTaskLog {
  EnvTaskLog({
    required this.id,
    required this.employeeId,
    required this.branchId,
    required this.envItemId,
    required this.itemName,
    required this.points,
    required this.createdAt,
    this.note,
    this.photoUrl,
    this.place,
    this.link,
    this.bonusPoints = 0,
    this.bonusReason,
    this.bonusById,
    this.bonusAt,
  });

  factory EnvTaskLog.fromJson(Map<String, dynamic> json) => EnvTaskLog(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    branchId: json['branchId'] as String,
    envItemId: json['envItemId'] as String,
    itemName: json['itemName'] as String,
    points: json['points'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    note: json['note'] as String?,
    photoUrl: json['photoUrl'] as String?,
    place: json['place'] as String?,
    link: json['link'] as String?,
    bonusPoints: json['bonusPoints'] as int? ?? 0,
    bonusReason: json['bonusReason'] as String?,
    bonusById: json['bonusById'] as String?,
    bonusAt: json['bonusAt'] == null
        ? null
        : DateTime.parse(json['bonusAt'] as String).toLocal(),
  );

  final String id;
  final String employeeId;
  final String branchId;
  final String envItemId;

  /// 수행 당시 항목 이름
  final String itemName;

  /// 수행 당시 배점 — **가산점은 안 들어 있다** ([totalPoints] 를 쓸 것)
  final int points;

  final DateTime createdAt;
  final String? note;

  /// 수행 사진 — **현수막·족자·전단지만 채워진다** (그 셋은 사진 없이 못 남긴다)
  final String? photoUrl;

  /// 어디에 했는지 — 사진과 짝이다 (현수막을 어디에 걸었나·전단지를 어디에 돌렸나)
  final String? place;

  /// 글 주소 — **블로그만 채워진다** (2026-08-28)
  final String? link;

  /// 대표가 얹은 가산점 — 기본 배점 **위에** 더한다
  final int bonusPoints;

  /// 왜 얹었나 (대표가 적는다)
  final String? bonusReason;

  final String? bonusById;
  final DateTime? bonusAt;

  /// 점수 원장에 실제로 쌓인 값 — **화면은 이걸 보여준다**
  ///
  /// 바닥을 0 으로 막는 것까지 서버와 같아야 한다. 안 맞추면 크게 깎았을 때
  /// 원장은 0 인데 화면에는 음수가 뜬다.
  int get totalPoints {
    final total = points + bonusPoints;
    return total < 0 ? 0 : total;
  }

  /// 대표가 손을 댄 기록인가
  bool get awarded => bonusAt != null;
}

/// `/env-items` `/env-logs` — 환경정비
///
/// 목록은 지점 스코프다. 직원·점장은 본인 지점만 본다.
class EnvApi {
  EnvApi._();

  static final _client = ApiClient.instance;

  /// 항목과 배점 — 배점이 높은 순으로 온다
  static Future<List<EnvItem>> items({String? branchId}) async {
    final rows = await _client.getList(
      '/env-items',
      query: {'branchId': ?branchId},
    );
    return [
      for (final row in rows)
        EnvItem.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 수행 기록 (최신순)
  ///
  /// [date] 는 `2026-07-31`, [period] 는 `2026-07`. 서버가 **한국 시간 기준**으로
  /// 자른다. 둘 다 안 주면 지점의 전체 기록이 오니 화면 용도에 맞게 준다.
  static Future<List<EnvTaskLog>> logs({
    String? branchId,
    String? employeeId,
    String? date,
    String? period,
  }) async {
    final rows = await _client.getList(
      '/env-logs',
      query: {
        'branchId': ?branchId,
        'employeeId': ?employeeId,
        'date': ?date,
        'period': ?period,
      },
    );
    return [
      for (final row in rows)
        EnvTaskLog.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 수행 기록 남기기 — 항목 배점만큼 환경정비 점수가 쌓인다
  static Future<EnvTaskLog> createLog(
    String envItemId, {
    String? note,
    String? photoUrl,
    String? place,
    String? link,
  }) async {
    final data = await _client.post(
      '/env-logs',
      body: {
        'envItemId': envItemId,
        'note': ?note,
        'photoUrl': ?photoUrl,
        'place': ?place,
        'link': ?link,
      },
    );
    return EnvTaskLog.fromJson(data!);
  }

  /// 가산점 얹기 — **MASTER 만, 블로그만** (2026-08-28)
  ///
  /// 배점을 10 → 3 으로 내린 대신 대표가 글을 보고 얹는다.
  /// 다시 부르면 **갈아끼운다** (더해지지 않는다). 0 을 주면 걷는다.
  static Future<EnvTaskLog> award(
    String logId, {
    required int points,
    required String comment,
  }) async {
    final data = await _client.post(
      '/env-logs/$logId/award',
      body: {'points': points, 'comment': comment},
    );
    return EnvTaskLog.fromJson(data!);
  }

  /// 수행 사진 올리기 — 돌려받은 주소를 [createLog] 의 `photoUrl` 에 넘긴다
  ///
  /// **기록 만들기와 두 번에 나뉘어 있다.** `/env-logs` 는 JSON 을 받는데 파일을
  /// 실으려면 multipart 로 바꿔야 하고, 그러면 사진이 필요 없는 나머지 21개
  /// 항목까지 다 같이 바뀐다. 사진을 받는 건 현수막·족자·전단지뿐이라 그 항목만
  /// 한 번 더 부른다.
  static Future<String> uploadPhoto(String path, {String? filename}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final data = await _client.post('/env-logs/photo', body: form);
    return data!['url'] as String;
  }

  /// 수행 취소 — 쌓였던 점수도 같이 회수된다
  ///
  /// 본인 기록만 지울 수 있다 (점장·대표는 남의 것도 된다).
  static Future<void> deleteLog(String logId) =>
      _client.delete('/env-logs/$logId');
}
