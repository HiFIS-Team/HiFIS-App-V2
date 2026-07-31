part of 'salary_screen.dart';

/// 급여 신청서 상태
///
/// 본인이 제출하고 대표가 승인해야 지급된다.
/// 미제출 → 승인 대기 → 승인 완료 (반려되면 다시 제출)
///
/// '지급 완료'는 서버에 없다 — 실제 입금까지 추적하지 않는다
/// (backend-gap.md 20번). 남겨 두되 서버에서 오지는 않는다.
enum _PayStatus {
  draft('미제출'),
  pending('승인 대기'),
  approved('승인 완료'),
  paid('지급 완료'),
  rejected('반려');

  const _PayStatus(this.label);

  final String label;

  Color get color => switch (this) {
    _PayStatus.draft => AppColors.gray500,
    _PayStatus.pending => AppColors.warning,
    _PayStatus.approved => AppColors.primary,
    _PayStatus.paid => AppColors.success,
    _PayStatus.rejected => AppColors.error,
  };

  static _PayStatus of(PayslipStatus status) => switch (status) {
    PayslipStatus.draft => _PayStatus.draft,
    PayslipStatus.submitted => _PayStatus.pending,
    PayslipStatus.approved => _PayStatus.approved,
    PayslipStatus.rejected => _PayStatus.rejected,
  };
}

/// 명세서 한 줄 — 이름, 계산 근거, 금액
class _PayItem {
  const _PayItem(this.label, this.amount, {this.note});

  final String label;
  final int amount;

  /// '62회 × 15,000' 처럼 왜 이 금액인지
  final String? note;
}

/// 한 달치 급여 명세서
///
/// 금액은 전부 서버가 계산한다. 직급 정책·인센티브 요율이 서버에 있어서
/// 앱이 따로 곱하면 실지급액과 어긋난다.
///
/// [source]가 null이면 아직 산출 전인 달이다 (서버가 404를 준다).
class _Payslip {
  _Payslip({required this.month, required this.source, this.window});

  /// 근무한 달 (1일로 맞춰 둔다)
  final DateTime month;

  /// 서버 명세서 — 아직 안 나온 달이면 null
  Payslip? source;

  /// 신청 창 (지급일·오늘 신청 가능 여부)
  PaydayWindow? window;

  /// `2026-07`
  String get key => yearMonthKey(month);

  _PayStatus get status =>
      source == null ? _PayStatus.draft : _PayStatus.of(source!.status);

  DateTime? get submittedAt => source?.submittedAt;
  DateTime? get decidedAt => source?.decidedAt;

  /// 대표가 남긴 반려 사유
  String? get comment => source?.rejectReason;

  /// 본인이 남긴 특이사항
  ///
  /// 서버 `PayslipSubmit`이 `yearMonth`만 받아서 보낼 데가 없다
  /// (backend-gap.md 22번). 지금은 앱 안에서만 산다.
  String? note;

  bool get submitted => status != _PayStatus.draft;

  /// 지급 항목 — 서버가 계산한 값을 그대로 늘어놓는다
  List<_PayItem> get pays {
    final payslip = source;
    if (payslip == null) return const [];
    final basis = payslip.basis;
    return [
      _PayItem('기본급', payslip.baseSalary),
      _PayItem(
        '신규 등록 인센티브',
        payslip.incentiveNew,
        note: basis.newSales.isEmpty ? null : '${basis.newSales.length}건',
      ),
      _PayItem(
        '재등록 인센티브',
        payslip.incentiveRenewal,
        note: basis.renewalSales.isEmpty
            ? null
            : '${basis.renewalSales.length}건',
      ),
      if (payslip.otherAllowances != 0)
        _PayItem('기타 수당', payslip.otherAllowances),
    ];
  }

  /// 공제 항목 (4대 보험·세금) — 서버가 직급·공제 방식에 따라 계산한다
  List<_PayItem> get deductions => [
    for (final line in source?.deductions ?? const <DeductionLine>[])
      _PayItem(line.label, line.amount),
  ];

  /// 세전 총액
  int get total => source?.gross ?? 0;

  /// 실수령액
  int get net => source?.net ?? 0;

  int get totalDeduction => source?.totalDeduction ?? 0;

  /// 이번 달 세션 싸인 수
  int get sessions => source?.basis.sessionSigns ?? 0;

  int get newSignups => source?.basis.newSales.length ?? 0;
  int get reSignups => source?.basis.renewalSales.length ?? 0;

  /// 지급일 — 서버가 알려 준다 (없으면 다음 달 10일로 가정)
  DateTime get payDay =>
      window?.payday ?? DateTime(month.year, month.month + 1, 10);

  /// 오늘 신청할 수 있는지 — 서버는 지급일 당일만 받는다
  bool get canSubmit => window?.isOpen ?? false;

  /// 지급일까지 남은 날 (지난 날짜면 0)
  int get daysLeft {
    final now = DateTime.now();
    final days = payDay
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return days < 0 ? 0 : days;
  }
}

/// 최근 몇 달치를 보여줄지 — 추이 그래프와 히스토리가 이 범위를 쓴다
///
/// 본인 명세서를 한 번에 주는 엔드포인트가 없어서 달마다 따로 부른다
/// (backend-gap.md 21번). 너무 늘리면 요청이 그만큼 늘어난다.
const _monthsToLoad = 6;

/// 최근 명세서 (0번이 이번 달) — 서버에서 받아 채운다
final _payslips = <_Payslip>[];

Future<void> _loadPayslips() async {
  final now = DateTime.now();
  final months = [
    for (var i = 0; i < _monthsToLoad; i++) DateTime(now.year, now.month - i),
  ];

  // 달마다 명세서를 따로 부르되 한꺼번에 보낸다
  final sources = await Future.wait(
    months.map((month) => PayrollApi.mine(yearMonthKey(month))),
  );
  // 신청 창은 이번 달만 필요하다
  final window = await PayrollApi.window(yearMonthKey(months.first));

  _payslips
    ..clear()
    ..addAll([
      for (var i = 0; i < months.length; i++)
        _Payslip(
          month: months[i],
          source: sources[i],
          window: i == 0 ? window : null,
        ),
    ]);
}

/// 1234567 → '1,234,567'
String _amount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// '1,234,567원'
String _won(int value) => '${_amount(value)}원';

/// '2026년 7월'
String _monthLabel(DateTime value) => '${value.year}년 ${value.month}월';

/// '8월 10일'
String _dayLabel(DateTime value) => '${value.month}월 ${value.day}일';
