import '../client/api_client.dart';

/// 하루치 — 점장이 개인 업무로 적은 **이번 달 누적** 숫자
class StatDay {
  StatDay({required this.date, required this.values});

  factory StatDay.fromJson(Map<String, dynamic> json) => StatDay(
    date: DateTime.parse(json['date'] as String),
    values: {
      for (final e in (json['values'] as Map).entries)
        e.key as String: (e.value as num).toDouble(),
    },
  );

  final DateTime date;

  /// `{기존: 94, 신규: 41, 일권: 36}`
  final Map<String, double> values;
}

/// 지점 통계 (서버 `BranchStatsOut`)
class BranchStats {
  BranchStats({required this.fields, required this.days});

  factory BranchStats.fromJson(Map<String, dynamic> json) => BranchStats(
    fields: [for (final f in json['fields'] as List) f as String],
    days: [
      for (final d in json['days'] as List)
        StatDay.fromJson((d as Map).cast<String, dynamic>()),
    ],
  );

  /// 칸 이름 — 처음 나온 차례대로
  final List<String> fields;

  /// 날짜 오름차순
  final List<StatDay> days;
}

/// 점장이 적어 내는 숫자의 통계 (2026-09-30 대표 요청) — 전 직원이 본다
class BranchStatsApi {
  BranchStatsApi._();

  /// [branchId] 는 대표·관리자만 뜻이 있다 (나머지는 서버가 자기 지점으로 고정)
  static Future<BranchStats> get({String? branchId}) async =>
      BranchStats.fromJson(
        await ApiClient.instance.get(
          '/branch-stats',
          query: {'branchId': ?branchId},
        ),
      );
}
