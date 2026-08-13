import '../client/api_client.dart';

/// 급여 명세서 상태 — 서버 `PayslipStatus`
enum PayslipStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  paid('PAID'),
  rejected('REJECTED');

  const PayslipStatus(this.wire);

  final String wire;

  static PayslipStatus parse(String? value) => PayslipStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => PayslipStatus.draft,
  );
}

/// 공제 한 줄 (4대 보험·세금 등)
class DeductionLine {
  DeductionLine({required this.label, required this.amount});

  factory DeductionLine.fromJson(Map<String, dynamic> json) => DeductionLine(
    label: json['label'] as String,
    amount: json['amount'] as int,
  );

  final String label;
  final int amount;
}

/// 매출 한 건 — 어떤 회원이 무슨 상품을 얼마에 등록했는지
class SaleItem {
  SaleItem({required this.memberName, required this.pkg, required this.amount});

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    memberName: json['memberName'] as String,
    pkg: json['pkg'] as String,
    amount: json['amount'] as int,
  );

  final String memberName;

  /// 상품명 (회원권·PT 패키지 등)
  final String pkg;
  final int amount;
}

/// 이 금액이 나온 근거 — 신규·재등록 매출과 세션 싸인 수
class PayslipBasis {
  PayslipBasis({
    required this.newSales,
    required this.renewalSales,
    required this.sessionSigns,
    this.hourly = false,
  });

  factory PayslipBasis.fromJson(Map<String, dynamic> json) => PayslipBasis(
    newSales: [
      for (final row in (json['newSales'] as List<dynamic>? ?? const []))
        SaleItem.fromJson((row as Map).cast<String, dynamic>()),
    ],
    renewalSales: [
      for (final row in (json['renewalSales'] as List<dynamic>? ?? const []))
        SaleItem.fromJson((row as Map).cast<String, dynamic>()),
    ],
    sessionSigns: json['sessionSigns'] as int? ?? 0,
    hourly: json['hourly'] != null,
  );

  final List<SaleItem> newSales;
  final List<SaleItem> renewalSales;
  final int sessionSigns;

  /// 시급으로 계산된 명세서인가 — **알바(PART_TIME) 것만** 이 자리가 채워진다
  ///
  /// 사람의 지금 고용 형태가 아니라 **그 명세서를 뽑을 때** 무엇이었는지다.
  /// 알바로 일하다 정규직이 돼도 지난 달 명세서는 시급 그대로 남아야 한다.
  final bool hourly;
}

/// 한 달치 급여 명세서 (서버 `PayslipOut`)
///
/// 금액은 전부 서버가 계산한다. 직군 정책·인센티브 요율이 서버에 있고
/// 앱이 따로 곱하면 실지급액과 어긋난다.
class Payslip {
  Payslip({
    required this.id,
    required this.employeeId,
    required this.yearMonth,
    required this.baseSalary,
    required this.incentiveNew,
    required this.incentiveRenewal,
    required this.otherAllowances,
    this.incentiveNewAuto,
    this.incentiveRenewalAuto,
    required this.gross,
    required this.deductions,
    required this.totalDeduction,
    required this.net,
    required this.basis,
    required this.status,
    required this.payday,
    this.note,
    this.rejectReason,
    this.submittedAt,
    this.decidedAt,
    this.paidAt,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) => Payslip(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String? ?? '',
    yearMonth: json['yearMonth'] as String,
    baseSalary: json['baseSalary'] as int,
    incentiveNew: json['incentiveNew'] as int,
    incentiveRenewal: json['incentiveRenewal'] as int,
    incentiveNewAuto: json['incentiveNewAuto'] as int?,
    incentiveRenewalAuto: json['incentiveRenewalAuto'] as int?,
    otherAllowances: json['otherAllowances'] as int,
    gross: json['gross'] as int,
    deductions: [
      for (final row in (json['deductions'] as List<dynamic>? ?? const []))
        DeductionLine.fromJson((row as Map).cast<String, dynamic>()),
    ],
    totalDeduction: json['totalDeduction'] as int,
    net: json['net'] as int,
    basis: PayslipBasis.fromJson(
      (json['basis'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    status: PayslipStatus.parse(json['status'] as String?),
    payday: DateTime.parse(json['payday'] as String),
    note: json['note'] as String?,
    rejectReason: json['rejectReason'] as String?,
    submittedAt: _localTime(json['submittedAt'] as String?),
    decidedAt: _localTime(json['decidedAt'] as String?),
    paidAt: _localTime(json['paidAt'] as String?),
  );

  final String id;

  /// 이 명세서의 주인 — 결재함에서 누구 건지 가릴 때 쓴다
  final String employeeId;

  /// `2026-07`
  final String yearMonth;

  final int baseSalary;
  final int incentiveNew;
  final int incentiveRenewal;

  /// 서버가 계산한 원래 커미션 — 위 두 값과 다르면 **본인이 고쳐서 신청한 것**이다
  ///
  /// 이 기능이 생기기 전 명세서는 null 이라 '고쳤는지'를 알 수 없다.
  final int? incentiveNewAuto;
  final int? incentiveRenewalAuto;

  /// 본인이 커미션을 고쳐서 낸 명세서인가 — 결재 화면이 차이를 보여준다
  bool get adjusted =>
      (incentiveNewAuto != null && incentiveNewAuto != incentiveNew) ||
      (incentiveRenewalAuto != null &&
          incentiveRenewalAuto != incentiveRenewal);

  final int otherAllowances;

  /// 세전 총액
  final int gross;

  final List<DeductionLine> deductions;
  final int totalDeduction;

  /// 실수령액
  final int net;

  final PayslipBasis basis;
  final PayslipStatus status;

  /// 지급 예정일 — 서버가 정한다 (지금은 그 달 말일)
  final DateTime payday;

  /// 본인이 신청할 때 남긴 특이사항 — 대표가 결재할 때 참고한다
  final String? note;

  final String? rejectReason;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  /// 실제로 입금된 시각 — 대표가 지급 처리해야 찍힌다
  final DateTime? paidAt;

  /// 해당 월의 첫날 — 화면이 날짜로 다루기 편하게
  DateTime get month {
    final parts = yearMonth.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// 급여 신청 창 — 지급일 당일에만 열린다
class PaydayWindow {
  PaydayWindow({
    required this.yearMonth,
    required this.payday,
    required this.isOpen,
  });

  factory PaydayWindow.fromJson(Map<String, dynamic> json) => PaydayWindow(
    yearMonth: json['yearMonth'] as String,
    payday: DateTime.parse(json['payday'] as String),
    isOpen: json['isOpen'] as bool,
  );

  final String yearMonth;

  /// 지급일
  final DateTime payday;

  /// 오늘 신청할 수 있는지
  final bool isOpen;
}

/// 진행 중인 주기에 **지금까지 쌓인 PT 커미션** — 기본급·공제는 없다
///
/// 명세서는 지급일에 나오지만 그 전까지 얼마 쌓였는지 볼 길이 없었다.
/// 세션 싸인을 찍을 때마다 오르고, 주기가 넘어가면 0부터 다시 센다.
///
/// **급여 주기는 달력 월이 아니다** — 지점·직군마다 지급일이 달라서
/// 화순·FC 는 `1일~말일`, 동광주·첨단 트레이너는 `전월 10일~당월 9일` 이다.
/// [yearMonth] 는 이 주기가 나중에 만들 명세서의 달이다.
class Accrued {
  Accrued({
    required this.yearMonth,
    required this.periodStart,
    required this.periodEnd,
    required this.payday,
    required this.incentiveNew,
    required this.incentiveRenewal,
    required this.total,
    required this.sessionSigns,
    required this.newSessions,
    required this.renewalSessions,
    required this.canAdjust,
  });

  factory Accrued.fromJson(Map<String, dynamic> json) => Accrued(
    yearMonth: json['yearMonth'] as String,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    payday: DateTime.parse(json['payday'] as String),
    incentiveNew: json['incentiveNew'] as int,
    incentiveRenewal: json['incentiveRenewal'] as int,
    total: json['total'] as int,
    sessionSigns: json['sessionSigns'] as int,
    newSessions: json['newSessions'] as int,
    renewalSessions: json['renewalSessions'] as int,
    canAdjust: json['canAdjust'] as bool? ?? false,
  );

  /// 이 주기가 만들 명세서의 달 (`2026-09`)
  final String yearMonth;

  final DateTime periodStart;

  /// **이 날 전날까지**가 이번 주기다 (끝은 안 포함)
  final DateTime periodEnd;

  final DateTime payday;
  final int incentiveNew;
  final int incentiveRenewal;

  /// 둘의 합 — 기본급은 안 들어간다
  final int total;

  final int sessionSigns;
  final int newSessions;
  final int renewalSessions;

  /// 신청할 때 본인이 커미션을 고칠 수 있는 사람인가
  ///
  /// **서버가 정한다.** 앱이 직군으로 따로 판정하면 요율이 바뀔 때 어긋나서,
  /// 못 고치는 사람에게 입력칸이 열리고 제출에서 400 이 난다.
  final bool canAdjust;
}

DateTime? _localTime(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();

/// `2026-07`
String yearMonthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

class PayrollApi {
  PayrollApi._();

  static final _client = ApiClient.instance;

  /// 내 명세서 목록 (최신순) — `from`·`to` 는 `2026-07` 형식, 양끝 포함
  ///
  /// 산출 안 된 달은 아예 빠져서 온다. 요청한 개수만큼 오지 않는 게 정상이다.
  static Future<List<Payslip>> list({String? from, String? to}) async {
    final rows = await _client.getList(
      '/payslips/me/list',
      query: {'from': ?from, 'to': ?to},
    );
    return [
      for (final row in rows)
        Payslip.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// **남의** 명세서 범위 — 결재하는 사람이 신청자 화면을 그대로 볼 때 쓴다
  ///
  /// 본인 것은 [list] 를 쓴다 (권한 없이 되는 길이라 그쪽이 싸다).
  /// 이 길은 `GET /payslips` 라 **ADMIN·MANAGER 이상**만 된다.
  static Future<List<Payslip>> listOf(
    String employeeId, {
    String? from,
    String? to,
  }) async {
    final rows = await _client.getList(
      '/payslips',
      query: {'employeeId': employeeId, 'from': ?from, 'to': ?to},
    );
    return [
      for (final row in rows)
        Payslip.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 신청 가능 여부와 지급일
  static Future<PaydayWindow> window(String yearMonth) async {
    final data = await _client.get(
      '/payslips/me/window',
      query: {'yearMonth': yearMonth},
    );
    return PaydayWindow.fromJson(data);
  }

  /// 진행 중인 주기에 지금까지 쌓인 PT 커미션 (본인 것만)
  static Future<Accrued> accrued() async {
    final data = await _client.get('/payslips/me/accrued');
    return Accrued.fromJson(data);
  }

  /// 급여 신청 — 지급일 당일에만 된다 (아니면 403 NOT_PAYDAY)
  ///
  /// [incentiveNew]·[incentiveRenewal] 을 주면 **본인이 고친 커미션**으로 낸다
  /// (자동 집계가 빠뜨린 수업을 바로잡는 자리다). 안 주면 서버 계산값 그대로다.
  /// 기본급은 못 고치고, 알바·FC 가 보내면 `400 NO_INCENTIVE` 다.
  static Future<Payslip> submit(
    String yearMonth, {
    String? note,
    int? incentiveNew,
    int? incentiveRenewal,
  }) async {
    final data = await _client.post(
      '/payslips/me/submit',
      body: {
        'yearMonth': yearMonth,
        'note': ?note,
        'incentiveNew': ?incentiveNew,
        'incentiveRenewal': ?incentiveRenewal,
      },
    );
    return Payslip.fromJson(data!);
  }

  /// 제출 철회 — 승인 대기 중일 때만 된다 (승인·지급 뒤에는 400 NOT_SUBMITTED)
  ///
  /// 특이사항은 서버가 남겨 둬서 다시 신청할 때 그대로 쓸 수 있다.
  static Future<Payslip> cancel(String yearMonth) async {
    final data = await _client.post(
      '/payslips/me/cancel',
      query: {'yearMonth': yearMonth},
    );
    return Payslip.fromJson(data!);
  }

  // ---------------------------------------------------------------------
  // 결재하는 쪽 — **MASTER · MANAGER 만** 처리할 수 있다
  //
  // 조회는 ADMIN 도 된다 (지켜보는 자리라 목록은 보이고 버튼은 없다).
  // MANAGER 는 서버가 자기 지점으로만 좁혀 준다.
  // ---------------------------------------------------------------------

  /// 결재함 — [box] 는 `inbox`(대기 중) · `decided`(처리한 것)
  static Future<List<Payslip>> box(
    String box, {
    String? yearMonth,
    String? branchId,
  }) async {
    final rows = await _client.getList(
      '/payslips',
      query: {'box': box, 'yearMonth': ?yearMonth, 'branchId': ?branchId},
    );
    return [
      for (final row in rows)
        Payslip.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 승인 — 제출된 것만 된다. **본인 명세서는 못 한다** (403 SELF_DECIDE)
  static Future<Payslip> approve(String id) async {
    final data = await _client.post('/payslips/$id/approve');
    return Payslip.fromJson(data!);
  }

  /// 반려 — 사유가 필수다. 신청자에게 알림으로 그대로 간다
  static Future<Payslip> reject(String id, String reason) async {
    final data = await _client.post(
      '/payslips/$id/reject',
      body: {'reason': reason},
    );
    return Payslip.fromJson(data!);
  }

  /// 지급 처리 — 승인된 것만 된다 (400 NOT_APPROVED)
  ///
  /// 날짜가 됐다고 서버가 자동으로 찍지 않는다. 실제로 입금됐는지는
  /// 이체를 확인한 사람만 아니까 여기서 눌러야 `paidAt` 이 남는다.
  static Future<Payslip> pay(String id) async {
    final data = await _client.post('/payslips/$id/pay');
    return Payslip.fromJson(data!);
  }
}
