part of 'salary_screen.dart';

/// 지급 상태
enum _PayStatus {
  scheduled('지급 예정'),
  paid('지급 완료');

  const _PayStatus(this.label);

  final String label;

  Color get color =>
      this == _PayStatus.paid ? AppColors.success : AppColors.primary;
}

/// 고용 형태 — 무엇을 떼는지가 사람마다 다르다
///
/// 4대보험 가입자, 3.3%만 떼는 프리랜서, 주 15시간 미만이라 고용보험만
/// 드는 아르바이트가 한 지점에 섞여 있다. 그래서 화면은 공제를 계산하지
/// 않고, 계약에 맞게 정해진 항목을 그대로 받아 보여준다.
enum _EmployType {
  regular('정규직'),
  parttime('아르바이트'),
  freelance('프리랜서');

  const _EmployType(this.label);

  final String label;
}

/// 명세서 한 줄 — 이름, 계산 근거, 금액
class _PayItem {
  const _PayItem(this.label, this.amount, {this.note});

  final String label;
  final int amount;

  /// '62회 × 15,000' 처럼 왜 이 금액인지
  final String? note;
}

/// 한 달치 급여 명세 (목업)
///
/// 앱은 금액을 계산하지 않는다. 계약 조건(고용 형태·수당 단가·공제 항목)은
/// 회사가 정하고 서버가 계산해서 내려주는 값이며, 여기서는 그 결과를
/// 그대로 담아 보여주기만 한다. 실제 연동 때는 [pays]·[deductions]를
/// 응답으로 채우면 화면은 그대로 동작한다.
class _Payslip {
  const _Payslip({
    required this.month,
    required this.type,
    required this.pays,
    required this.deductions,
    required this.sessions,
    required this.status,
  });

  /// 근무한 달 (1일로 맞춰 둔다)
  final DateTime month;

  /// 이 명세에 적용된 고용 형태
  final _EmployType type;

  /// 지급 항목 · 공제 항목 (없으면 빈 목록)
  final List<_PayItem> pays;
  final List<_PayItem> deductions;

  /// 목록에서 실적을 같이 보여주려고 들고 있는다
  final int sessions;

  final _PayStatus status;

  int get gross => pays.fold(0, (sum, item) => sum + item.amount);
  int get deduction => deductions.fold(0, (sum, item) => sum + item.amount);
  int get net => gross - deduction;

  /// 지급일 — 다음 달 10일
  DateTime get payDay => DateTime(month.year, month.month + 1, 10);

  /// 지급일까지 남은 날 (지난 날짜면 0)
  int get daysLeft {
    final now = DateTime.now();
    final days = payDay
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return days < 0 ? 0 : days;
  }
}

/// 최근 12개월 명세 (0번이 이번 달)
final _payslips = _seedPayslips();

List<_Payslip> _seedPayslips() {
  final now = DateTime.now();

  // (세션 수, 신규 등록, 재등록) — 달마다 실적이 다르게
  const record = [
    (62, 3, 5),
    (58, 2, 4),
    (65, 4, 3),
    (54, 1, 6),
    (60, 3, 4),
    (49, 2, 2),
    (57, 3, 5),
    (63, 5, 4),
    (51, 2, 3),
    (55, 1, 5),
    (59, 4, 4),
    (47, 2, 2),
  ];

  return [
    for (var i = 0; i < record.length; i++)
      _payslipOf(
        month: DateTime(now.year, now.month - i),
        sessions: record[i].$1,
        newSignups: record[i].$2,
        reSignups: record[i].$3,
        // 이번 달은 아직 정산 전
        status: i == 0 ? _PayStatus.scheduled : _PayStatus.paid,
      ),
  ];
}

/// 목업용 명세 만들기
///
/// 실제로는 서버가 하는 일이다. 여기 있는 단가와 요율은 흔한 값을
/// 가져다 쓴 것일 뿐, 실제 계약·세액과는 다르다.
_Payslip _payslipOf({
  required DateTime month,
  required int sessions,
  required int newSignups,
  required int reSignups,
  required _PayStatus status,
  _EmployType type = _EmployType.regular,
}) {
  const base = 2400000;
  const sessionRate = 15000;
  const newBonus = 50000;
  const reBonus = 20000;
  const meal = 100000;

  final pays = [
    _PayItem('기본급', base),
    _PayItem(
      'PT 세션 수당',
      sessions * sessionRate,
      note: '$sessions회 × ${_amount(sessionRate)}',
    ),
    _PayItem(
      '신규 등록',
      newSignups * newBonus,
      note: '$newSignups건 × ${_amount(newBonus)}',
    ),
    _PayItem(
      '재등록',
      reSignups * reBonus,
      note: '$reSignups건 × ${_amount(reBonus)}',
    ),
    _PayItem('식대', meal, note: '비과세'),
  ];

  final gross = pays.fold(0, (sum, item) => sum + item.amount);

  // 식대는 비과세라 과세 대상에서 뺀다
  final taxable = gross - meal;
  int cut(num value) => (value ~/ 10) * 10;

  final deductions = switch (type) {
    // 4대보험 + 근로소득세
    _EmployType.regular => () {
      final health = cut(taxable * 0.03545);
      final incomeTax = cut(taxable * 0.031);
      return [
        _PayItem('국민연금', cut(taxable * 0.045), note: '4.5%'),
        _PayItem('건강보험', health, note: '3.545%'),
        _PayItem('장기요양', cut(health * 0.1295), note: '건강보험의 12.95%'),
        _PayItem('고용보험', cut(taxable * 0.009), note: '0.9%'),
        _PayItem('소득세', incomeTax),
        _PayItem('지방소득세', cut(incomeTax * 0.1), note: '소득세의 10%'),
      ];
    }(),
    // 주 15시간 미만이면 고용보험도 안 든다 — 소득세만
    _EmployType.parttime => [
      _PayItem('소득세', cut(taxable * 0.006)),
      _PayItem('지방소득세', cut(taxable * 0.0006), note: '소득세의 10%'),
    ],
    // 사업소득 3.3% 원천징수
    _EmployType.freelance => [
      _PayItem('사업소득세', cut(taxable * 0.03), note: '3%'),
      _PayItem('지방소득세', cut(taxable * 0.003), note: '0.3%'),
    ],
  };

  return _Payslip(
    month: month,
    type: type,
    pays: pays,
    deductions: deductions,
    sessions: sessions,
    status: status,
  );
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
