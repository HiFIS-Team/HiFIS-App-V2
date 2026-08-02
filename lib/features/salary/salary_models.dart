part of 'salary_screen.dart';

/// 급여 신청서 상태
///
/// 본인이 제출하고 대표가 승인해야 지급된다.
/// 미제출 → 승인 대기 → 승인 완료 → 지급 완료 (반려되면 다시 제출)
///
/// '지급 완료'는 대표가 실제로 입금한 뒤 직접 처리한다 — 지급일이 지났다고
/// 자동으로 넘어가지 않는다 (이체 확인 없이 찍으면 오표기가 된다).
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
    PayslipStatus.paid => _PayStatus.paid,
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
/// [source]가 null이면 아직 산출 전인 달이다 (목록 응답에서 빠져 있다).
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

  /// 실제로 입금된 시각 — 대표가 지급 처리해야 찍힌다
  DateTime? get paidAt => source?.paidAt;

  /// 대표가 남긴 반려 사유
  String? get comment => source?.rejectReason;

  /// 본인이 남긴 특이사항
  ///
  /// 신청서에서 고친 값이 제출 전까지 여기 머물다가 제출할 때 서버로 간다.
  /// 제출 뒤에는 서버가 돌려준 값으로 덮는다.
  String? note;

  bool get submitted => status != _PayStatus.draft;

  /// 지급 항목 — 서버가 계산한 값을 그대로 늘어놓는다
  ///
  /// **세션 수당 줄은 없다.** 커미션 모델에서는 세션 급여가 곧 신규·재등록
  /// 커미션이다 — 세션 싸인 한 건마다 회차 단가(`등록가 ÷ 총 회차`)에 요율이
  /// 붙고, 그 합이 아래 두 줄이다. 따로 '세션 수당'을 두면 이중 계산이 된다.
  ///
  /// 같은 이유로 '몇 회 × 얼마' 로 못 묶는다. 회차 단가가 회원 등록가마다
  /// 달라서 단일 정액이 아니다. 그래서 **금액 합계 + 횟수**로만 보여준다.
  ///
  /// 아직 산출 안 된 달도 **항목은 0원으로 늘어놓는다.** 빈 목록을 주면
  /// 카드에 제목과 '총 지급액 0원' 만 남아서 화면이 고장 난 것처럼 보인다
  /// (실제로 그렇게 보였다). 무엇을 받는 자리인지는 금액이 0이어도 알려 준다.
  List<_PayItem> get pays {
    final payslip = source;
    if (payslip == null) {
      return const [
        _PayItem('기본급', 0),
        _PayItem('PT 커미션 · 신규', 0),
        _PayItem('PT 커미션 · 재등록', 0),
      ];
    }
    return [
      _PayItem('기본급', payslip.baseSalary),
      _PayItem(
        'PT 커미션 · 신규',
        payslip.incentiveNew,
        note: newSessions == 0 ? null : '워크인 $newSessions회',
      ),
      _PayItem(
        'PT 커미션 · 재등록',
        payslip.incentiveRenewal,
        // 서버가 재등록과 지인소개를 같은 요율로 한 통에 담는다
        note: renewalSessions == 0 ? null : '소개 포함 $renewalSessions회',
      ),
      if (payslip.otherAllowances != 0)
        _PayItem('기타 수당', payslip.otherAllowances),
    ];
  }

  /// 커미션이 왜 이 금액인지 — 카드 맨 아래 한 줄
  String? get payNote =>
      source == null ? null : '이번 달 세션 $sessions회 · 회차마다 등록 단가가 달라 합계로 보여드려요';

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

  /// 이번 달 세션 싸인 수 — 금액이 아니라 참고용 숫자다
  int get sessions => source?.basis.sessionSigns ?? 0;

  /// 커미션이 붙은 세션 수 — `newSales`·`renewalSales` 는 등록 건이 아니라
  /// **세션 한 건씩**이다 (서버가 `{회차} · {워크인|재등록|지인소개}` 로 담는다).
  int get newSessions => source?.basis.newSales.length ?? 0;
  int get renewalSessions => source?.basis.renewalSales.length ?? 0;

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
/// 범위로 한 번에 받아오므로 늘려도 요청 수는 그대로다.
const _monthsToLoad = 6;

/// 최근 명세서 (0번이 이번 달) — 서버에서 받아 채운다
final _payslips = <_Payslip>[];

Future<void> _loadPayslips() async {
  final now = DateTime.now();
  final months = [
    for (var i = 0; i < _monthsToLoad; i++) DateTime(now.year, now.month - i),
  ];

  // 명세서 범위와 신청 창을 같이 띄워 둔다 (신청 창은 이번 달만 필요하다)
  final listing = PayrollApi.list(
    from: yearMonthKey(months.last),
    to: yearMonthKey(months.first),
  );
  final windowRequest = PayrollApi.window(yearMonthKey(months.first));

  // 산출 안 된 달은 응답에서 빠져 있다 — 달을 키로 짝지어 빈 자리를 남긴다
  final sources = {
    for (final payslip in await listing) payslip.yearMonth: payslip,
  };
  final window = await windowRequest;

  _payslips
    ..clear()
    ..addAll([
      for (var i = 0; i < months.length; i++)
        _Payslip(
          month: months[i],
          source: sources[yearMonthKey(months[i])],
          window: i == 0 ? window : null,
        )..note = sources[yearMonthKey(months[i])]?.note,
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
