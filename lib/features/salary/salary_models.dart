part of 'salary_screen.dart';

/// 급여 신청서 상태
///
/// 본인이 제출하고 대표가 승인해야 지급된다.
/// 미제출 → 승인 대기 → 승인 완료 → 지급 완료 (반려되면 다시 제출)
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
}

/// 명세서 한 줄 — 이름, 계산 근거, 금액
class _PayItem {
  const _PayItem(this.label, this.amount, {this.note});

  final String label;
  final int amount;

  /// '62회 × 15,000' 처럼 왜 이 금액인지
  final String? note;
}

/// 내 커미션 조건 (목업)
///
/// 기본급과 단가는 사람마다 다르고 대표와 협의해 정해진다.
/// 앱에서는 못 바꾸고, 계약된 값을 받아 총액을 계산하는 데만 쓴다.
class _Commission {
  const _Commission({
    required this.base,
    required this.sessionRate,
    required this.newBonus,
    required this.reBonus,
  });

  final int base;
  final int sessionRate;
  final int newBonus;
  final int reBonus;
}

/// 로그인한 사람의 커미션 — 실제 연동 때 서버에서 받아 온다
const _myCommission = _Commission(
  base: 2400000,
  sessionRate: 15000,
  newBonus: 50000,
  reBonus: 20000,
);

/// 한 달치 급여 신청서 (목업)
///
/// 실적(세션·등록 건수)은 회사가 집계해 채워 주고, 앱은 커미션을 곱해
/// **총 지급액**까지만 계산한다. 세금·보험처럼 빠져나가는 돈은 사람마다
/// 조건이 달라 회사가 따로 처리하므로 여기서 다루지 않는다.
class _Payslip {
  _Payslip({
    required this.month,
    required this.sessions,
    required this.newSignups,
    required this.reSignups,
    required this.status,
    this.submittedAt,
    this.decidedAt,
  });

  /// 근무한 달 (1일로 맞춰 둔다)
  final DateTime month;

  /// 회사가 집계한 실적 — 본인이 못 고친다
  final int sessions;
  final int newSignups;
  final int reSignups;

  _PayStatus status;
  DateTime? submittedAt;
  DateTime? decidedAt;

  /// 본인이 남긴 특이사항
  String? note;

  /// 대표가 남긴 의견 (반려 사유 등)
  String? comment;

  bool get submitted => status != _PayStatus.draft;

  /// 지급 항목
  List<_PayItem> get pays => [
    _PayItem('기본급', _myCommission.base),
    _PayItem(
      'PT 세션 수당',
      sessions * _myCommission.sessionRate,
      note: '$sessions회 × ${_amount(_myCommission.sessionRate)}',
    ),
    _PayItem(
      '신규 등록',
      newSignups * _myCommission.newBonus,
      note: '$newSignups건 × ${_amount(_myCommission.newBonus)}',
    ),
    _PayItem(
      '재등록',
      reSignups * _myCommission.reBonus,
      note: '$reSignups건 × ${_amount(_myCommission.reBonus)}',
    ),
  ];

  /// 총 지급액
  int get total => pays.fold(0, (sum, item) => sum + item.amount);

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

/// 최근 12개월 신청서 (0번이 이번 달)
final _payslips = _seedPayslips();

List<_Payslip> _seedPayslips() {
  final now = DateTime.now();

  // (세션 수, 신규 등록, 재등록) — 회사가 집계해 채워 주는 실적
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
        sessions: record[i].$1,
        newSignups: record[i].$2,
        reSignups: record[i].$3,
        // 이번 달은 아직 제출 전, 지난 달은 지급까지 끝난 상태
        status: i == 0 ? _PayStatus.draft : _PayStatus.paid,
        submittedAt: i == 0 ? null : DateTime(now.year, now.month - i + 1, 2),
        decidedAt: i == 0 ? null : DateTime(now.year, now.month - i + 1, 4),
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
