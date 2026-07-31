import 'api_client.dart';

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
  );

  final List<SaleItem> newSales;
  final List<SaleItem> renewalSales;
  final int sessionSigns;
}

/// 한 달치 급여 명세서 (서버 `PayslipOut`)
///
/// 금액은 전부 서버가 계산한다. 직급 정책·인센티브 요율이 서버에 있고
/// 앱이 따로 곱하면 실지급액과 어긋난다.
class Payslip {
  Payslip({
    required this.id,
    required this.yearMonth,
    required this.baseSalary,
    required this.incentiveNew,
    required this.incentiveRenewal,
    required this.otherAllowances,
    required this.gross,
    required this.deductions,
    required this.totalDeduction,
    required this.net,
    required this.basis,
    required this.status,
    this.note,
    this.rejectReason,
    this.submittedAt,
    this.decidedAt,
    this.paidAt,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) => Payslip(
    id: json['id'] as String,
    yearMonth: json['yearMonth'] as String,
    baseSalary: json['baseSalary'] as int,
    incentiveNew: json['incentiveNew'] as int,
    incentiveRenewal: json['incentiveRenewal'] as int,
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
    note: json['note'] as String?,
    rejectReason: json['rejectReason'] as String?,
    submittedAt: _localTime(json['submittedAt'] as String?),
    decidedAt: _localTime(json['decidedAt'] as String?),
    paidAt: _localTime(json['paidAt'] as String?),
  );

  final String id;

  /// `2026-07`
  final String yearMonth;

  final int baseSalary;
  final int incentiveNew;
  final int incentiveRenewal;
  final int otherAllowances;

  /// 세전 총액
  final int gross;

  final List<DeductionLine> deductions;
  final int totalDeduction;

  /// 실수령액
  final int net;

  final PayslipBasis basis;
  final PayslipStatus status;

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

  /// 신청 가능 여부와 지급일
  static Future<PaydayWindow> window(String yearMonth) async {
    final data = await _client.get(
      '/payslips/me/window',
      query: {'yearMonth': yearMonth},
    );
    return PaydayWindow.fromJson(data);
  }

  /// 급여 신청 — 지급일 당일에만 된다 (아니면 403 NOT_PAYDAY)
  static Future<Payslip> submit(String yearMonth, {String? note}) async {
    final data = await _client.post(
      '/payslips/me/submit',
      body: {'yearMonth': yearMonth, 'note': ?note},
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
}
