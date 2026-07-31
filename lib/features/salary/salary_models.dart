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

/// 한 달치 급여 명세 (목업)
///
/// 기본급에 PT 세션 수당과 등록 인센티브를 더하고, 4대보험·소득세를 뺀다.
/// 요율은 2026년 기준을 대략 따른 값이라 실제 정산과는 다를 수 있다.
/// 실제 연동 때는 계산 결과를 서버에서 받아 그대로 보여주면 된다.
class _Payslip {
  const _Payslip({
    required this.month,
    required this.base,
    required this.sessions,
    required this.newSignups,
    required this.reSignups,
    required this.status,
  });

  /// 근무한 달 (1일로 맞춰 둔다)
  final DateTime month;

  /// 기본급
  final int base;

  /// 진행한 PT 세션 수
  final int sessions;

  /// 신규 등록 · 재등록 건수
  final int newSignups;
  final int reSignups;

  final _PayStatus status;

  /// 세션 단가 · 등록 인센티브 단가 · 식대(비과세)
  static const sessionRate = 15000;
  static const newBonus = 50000;
  static const reBonus = 20000;
  static const meal = 100000;

  int get sessionPay => sessions * sessionRate;
  int get newPay => newSignups * newBonus;
  int get rePay => reSignups * reBonus;

  /// 지급 합계
  int get gross => base + sessionPay + newPay + rePay + meal;

  /// 과세 대상 (식대는 비과세)
  int get taxable => gross - meal;

  int get pension => _round(taxable * 0.045);
  int get health => _round(taxable * 0.03545);
  int get care => _round(health * 0.1295);
  int get employment => _round(taxable * 0.009);

  /// 소득세는 간이세액표를 따르지만, 목업이라 단순 요율로 잡는다
  int get incomeTax => _round(taxable * 0.031);
  int get localTax => _round(incomeTax * 0.1);

  /// 공제 합계
  int get deduction =>
      pension + health + care + employment + incomeTax + localTax;

  /// 실수령액
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

  /// 10원 단위 절사 — 급여 명세에서 흔한 처리
  static int _round(num value) => (value ~/ 10) * 10;
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
      _Payslip(
        month: DateTime(now.year, now.month - i),
        base: 2400000,
        sessions: record[i].$1,
        newSignups: record[i].$2,
        reSignups: record[i].$3,
        // 이번 달은 아직 정산 전
        status: i == 0 ? _PayStatus.scheduled : _PayStatus.paid,
      ),
  ];
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
