import '../client/api_client.dart';

/// 회원에게 권한 영양제 한 줄 — 서버 `supplements` 표
///
/// 칸 이름은 트레이너가 쓰던 표 그대로다 —
/// `영양제(name) / 얼마나?(dose) / 언제?(timing) / 왜?(reason) / 기억하기(note)`.
class Supplement {
  const Supplement({
    required this.id,
    required this.memberId,
    required this.name,
    this.dose = '',
    this.timing = '',
    this.reason = '',
    this.note = '',
    this.sortOrder = 0,
    this.authorId,
  });

  final String id;
  final String memberId;
  final String name;
  final String dose;
  final String timing;
  final String reason;
  final String note;
  final int sortOrder;
  final String? authorId;

  factory Supplement.fromJson(Map<String, dynamic> json) => Supplement(
    id: json['id'] as String,
    memberId: json['memberId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    dose: json['dose'] as String? ?? '',
    timing: json['timing'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    note: json['note'] as String? ?? '',
    sortOrder: json['sortOrder'] as int? ?? 0,
    authorId: json['authorId'] as String?,
  );

  /// 목록 한 줄에 이름 밑으로 붙는 말 — 빈 칸은 건너뛴다
  String get summary =>
      [if (dose.isNotEmpty) dose, if (timing.isNotEmpty) timing].join(' · ');
}

class SupplementApi {
  SupplementApi._();

  static final _client = ApiClient.instance;

  static Future<List<Supplement>> list(String memberId) async {
    final rows = await _client.getList(
      '/supplements',
      query: {'memberId': memberId},
    );
    return [
      for (final row in rows)
        Supplement.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<Supplement> create({
    required String memberId,
    required String name,
    String dose = '',
    String timing = '',
    String reason = '',
    String note = '',
  }) async {
    final data = await _client.post(
      '/supplements',
      body: {
        'memberId': memberId,
        'name': name,
        'dose': dose,
        'timing': timing,
        'reason': reason,
        'note': note,
      },
    );
    return Supplement.fromJson(data!);
  }

  static Future<Supplement> update(
    String id, {
    required String name,
    required String dose,
    required String timing,
    required String reason,
    required String note,
  }) async {
    final data = await _client.patch(
      '/supplements/$id',
      body: {
        'name': name,
        'dose': dose,
        'timing': timing,
        'reason': reason,
        'note': note,
      },
    );
    return Supplement.fromJson(data!);
  }

  static Future<void> remove(String id) => _client.delete('/supplements/$id');
}
