import '../client/api_client.dart';

/// 한 사람의 한 달 목표 (서버 `MonthlyGoalOut`)
class MonthlyGoal {
  MonthlyGoal({
    required this.employeeId,
    required this.yearMonth,
    required this.items,
    required this.achieved,
    required this.createdAt,
  });

  factory MonthlyGoal.fromJson(Map<String, dynamic> json) => MonthlyGoal(
    employeeId: json['employeeId'] as String,
    yearMonth: json['yearMonth'] as String,
    items: [for (final item in json['items'] as List) item as String],
    achieved: {for (final i in json['achieved'] as List) i as int},
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String employeeId;

  /// `YYYY-MM`
  final String yearMonth;
  final List<String> items;

  /// 이룬 목표의 번호 (0부터) — 본인이 체크한다
  final Set<int> achieved;
  final DateTime createdAt;

  /// 달성률 0~1
  double get rate => items.isEmpty ? 0 : achieved.length / items.length;

  MonthlyGoal copyWith({Set<int>? achieved}) => MonthlyGoal(
    employeeId: employeeId,
    yearMonth: yearMonth,
    items: items,
    achieved: achieved ?? this.achieved,
    createdAt: createdAt,
  );
}

/// 이번 달 내 목표 (서버 `MyGoalOut`)
class MyGoal {
  MyGoal({
    required this.yearMonth,
    required this.writes,
    required this.due,
    this.goal,
  });

  factory MyGoal.fromJson(Map<String, dynamic> json) => MyGoal(
    yearMonth: json['yearMonth'] as String,
    writes: json['writes'] as bool,
    due: json['due'] as bool,
    goal: json['goal'] == null
        ? null
        : MonthlyGoal.fromJson((json['goal'] as Map).cast<String, dynamic>()),
  );

  final String yearMonth;

  /// 적는 사람인가 — MANAGER·MEMBER 만
  final bool writes;

  /// 재촉할 때인가 — 첫 월요일이 지났고 아직 안 냈다 (모달이 본다)
  final bool due;

  /// 이번 달에 낸 것 — 내면 잠긴다
  final MonthlyGoal? goal;
}

/// 이달의 목표 (2026-09-28 대표 요청) — 첫 월요일 푸시는 서버 잡이 보낸다
class GoalApi {
  GoalApi._();

  /// 최소 몇 개 — 서버 `GOAL_MIN_ITEMS` 와 같아야 한다
  static const minItems = 2;

  /// 최대 몇 개 — 서버 `GOAL_MAX_ITEMS`
  static const maxItems = 10;

  /// 한 줄 글자 수 — 서버 `GOAL_MAX_LEN`
  static const maxLength = 200;

  static Future<MyGoal> me() async =>
      MyGoal.fromJson(await ApiClient.instance.get('/goals/me'));

  /// 내가 낸 목표 전부 — 최신 달이 먼저 (지난 달 것을 다시 본다)
  static Future<List<MonthlyGoal>> mine() async {
    final rows = await ApiClient.instance.getList('/goals/me/list');
    return [
      for (final row in rows)
        MonthlyGoal.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 이번 달 목표 내기 — **한 번 내면 못 고친다** (두 번째는 409)
  static Future<MonthlyGoal> submit(List<String> items) async {
    final json = await ApiClient.instance.post(
      '/goals/me',
      body: {'items': items},
    );
    return MonthlyGoal.fromJson(json!);
  }

  /// 목표 한 줄을 이뤘다·못 이뤘다로 — 본인만, 그 달과 다음 달까지
  static Future<MonthlyGoal> check(
    String yearMonth,
    int index, {
    required bool done,
  }) async {
    final json = await ApiClient.instance.post(
      '/goals/me/check',
      body: {'yearMonth': yearMonth, 'index': index, 'done': done},
    );
    return MonthlyGoal.fromJson(json!);
  }

  /// 한 직원이 낸 목표 전부 — MASTER·ADMIN 만
  static Future<List<MonthlyGoal>> ofEmployee(String employeeId) async {
    final rows = await ApiClient.instance.getList(
      '/goals/employees/$employeeId',
    );
    return [
      for (final row in rows)
        MonthlyGoal.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 그 달 전 직원 목표 — MASTER·ADMIN 만
  static Future<List<MonthlyGoal>> list(String yearMonth) async {
    final rows = await ApiClient.instance.getList(
      '/goals',
      query: {'yearMonth': yearMonth},
    );
    return [
      for (final row in rows)
        MonthlyGoal.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }
}
