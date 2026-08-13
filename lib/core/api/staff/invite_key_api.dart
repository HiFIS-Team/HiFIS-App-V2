import '../../data/employee.dart';
import '../client/api_client.dart';

/// 초대키 상태 — 서버 `InviteStatus`
enum InviteStatus {
  unused('UNUSED', '사용 전'),
  used('USED', '사용됨'),
  expired('EXPIRED', '만료');

  const InviteStatus(this.wire, this.label);

  final String wire;
  final String label;

  static InviteStatus parse(String? value) => InviteStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => InviteStatus.unused,
  );
}

/// 초대키 한 장 (서버 `InviteKeyOut`)
///
/// **가입할 때의 지점·직군·권한·고용 형태가 이 키에 박혀 있다.** 회원가입은 키에
/// 적힌 값을 그대로 쓰므로(`branch_id=key.branch_id`), 사람을 어느 지점으로
/// 받을지는 키를 발급할 때 정해진다.
class InviteKey {
  InviteKey({
    required this.id,
    required this.code,
    required this.branchId,
    required this.role,
    required this.rank,
    required this.employmentType,
    required this.status,
    required this.issuedById,
    required this.expiresAt,
    required this.createdAt,
    this.team,
  });

  factory InviteKey.fromJson(Map<String, dynamic> json) => InviteKey(
    id: json['id'] as String,
    code: json['code'] as String,
    branchId: json['branchId'] as String,
    role: Role.parse(json['role'] as String?),
    rank: Rank.parse(json['rank'] as String?),
    employmentType: EmploymentType.parse(json['employmentType'] as String?),
    status: InviteStatus.parse(json['status'] as String?),
    issuedById: json['issuedById'] as String,
    expiresAt: _time(json['expiresAt']),
    createdAt: _time(json['createdAt']),
    team: json['team'] as String?,
  );

  final String id;

  /// 가입 화면에 넣는 코드 (`HIFIS-XXXXXXXX`)
  final String code;

  final String branchId;
  final Role role;
  final Rank rank;

  /// 이 키로 들어오면 정규직인가 알바인가
  ///
  /// 들어온 뒤 정규직으로 올리거나 퇴사시키는 건 인사 정보 변경(MASTER) 쪽이다.
  final EmploymentType employmentType;

  final InviteStatus status;
  final String issuedById;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? team;

  /// 아직 쓸 수 있는 키인가 — 서버 상태와 만료 시각을 같이 본다
  ///
  /// 서버가 `status` 를 즉시 갱신하지 않을 수 있어서 시각도 확인한다.
  bool get usable =>
      status == InviteStatus.unused && expiresAt.isAfter(DateTime.now());
}

DateTime _time(dynamic value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime(2000);

/// `/invite-keys` — 신규 입사자를 받는 초대키
///
/// **MASTER·ADMIN·MANAGER 만 부를 수 있다** (MEMBER 는 403).
/// 서버가 권한 상승도 막는다 — 본인보다 높은 권한의 키는 발급되지 않는다
/// (점장이 ADMIN 키를 만들 수 없다).
class InviteKeyApi {
  InviteKeyApi._();

  static final _client = ApiClient.instance;

  static Future<List<InviteKey>> list() async {
    final rows = await _client.getList('/invite-keys');
    return [
      for (final row in rows)
        InviteKey.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 키 발급
  ///
  /// [code] 를 비우면 서버가 `HIFIS-XXXXXXXX` 를 만들고,
  /// [expiresAt] 을 비우면 **14일** 뒤로 잡는다.
  static Future<InviteKey> create({
    required String branchId,
    required Role role,
    required Rank rank,
    EmploymentType employmentType = EmploymentType.fullTime,
    String? team,
    String? code,
    DateTime? expiresAt,
  }) async {
    final row = await _client.post(
      '/invite-keys',
      body: {
        'branchId': branchId,
        'role': role.wire,
        'rank': rank.wire,
        'employmentType': employmentType.wire,
        'team': ?team,
        'code': ?code,
        'expiresAt': ?expiresAt?.toUtc().toIso8601String(),
      },
    );
    return InviteKey.fromJson(row!);
  }

  static Future<void> delete(String id) => _client.delete('/invite-keys/$id');
}
