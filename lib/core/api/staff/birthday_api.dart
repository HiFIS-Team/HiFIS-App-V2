import '../client/api_client.dart';

/// 오늘 생일인 사람 한 명 (서버 `BirthdayTodayOut`) — 축하 모달이 쓴다
class BirthdayToday {
  BirthdayToday({required this.id, required this.name, required this.cheered});

  factory BirthdayToday.fromJson(Map<String, dynamic> json) => BirthdayToday(
    id: json['id'] as String,
    name: json['name'] as String,
    cheered: json['cheered'] as bool,
  );

  final String id;
  final String name;

  /// 내가 이미 축하를 보냈나 — 다른 기기에서 보냈으면 모달을 안 띄운다
  final bool cheered;
}

/// 생일 축하 (2026-09-27 대표 요청) — 전날·당일 푸시는 서버 잡이 보낸다
class BirthdayApi {
  BirthdayApi._();

  /// 오늘 생일인 사람 — **나는 빠져 있다** (서버가 뺀다)
  static Future<List<BirthdayToday>> today() async {
    final rows = await ApiClient.instance.getList('/birthdays/today');
    return [
      for (final row in rows)
        BirthdayToday.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 축하 이모지 보내기 — 생일자에게 푸시가 간다. 두 번째부터는 서버가 무시한다
  static Future<void> cheer(String employeeId) =>
      ApiClient.instance.post('/birthdays/$employeeId/cheer');
}
