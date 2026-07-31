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

/// 고용 형태 — 무엇을 떼는지가 사람마다 다르다
///
/// 4대보험 가입자, 3.3%만 떼는 프리랜서, 주 15시간 미만이라 고용보험도
/// 안 드는 아르바이트가 한 지점에 섞여 있다. 그래서 앱이 정하지 않고
/// 신청서에 본인이 적어 낸다.
enum _EmployType {
  regular('정규직'),
  parttime('아르바이트'),
  freelance('프리랜서');

  const _EmployType(this.label);

  final String label;
}

/// 본인이 가입 여부를 신고하는 보험
///
/// 산재보험은 전액 회사 부담이라 급여에서 떼지 않아 여기 없다.
enum _Insurance {
  pension('국민연금'),
  health('건강보험'),
  employment('고용보험');

  const _Insurance(this.label);

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

/// 회사가 정해 주는 값 — 신청서에서 못 바꾼다
class _CompanyTerms {
  const _CompanyTerms({
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

const _companyBase = _CompanyTerms(
  base: 2400000,
  sessionRate: 15000,
  newBonus: 50000,
  reBonus: 20000,
);

/// 한 달치 급여 신청서 (목업)
///
/// 실적(세션·등록 건수)과 단가는 회사가 집계해 채워 주고, 고용 형태와
/// 가입 보험은 본인이 적어 낸다. 대표가 승인하면 그대로 지급된다.
///
/// 금액 계산은 목업용이다. 실제로는 서버가 계산한 지급·공제 항목을
/// 받아 그대로 보여주면 되고, 화면은 손대지 않아도 된다.
class _Payslip {
  _Payslip({
    required this.month,
    required this.sessions,
    required this.newSignups,
    required this.reSignups,
    required this.type,
    required this.insurances,
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

  /// 신청서에 적어 낸 조건
  _EmployType type;
  Set<_Insurance> insurances;

  _PayStatus status;
  DateTime? submittedAt;
  DateTime? decidedAt;

  /// 본인이 남긴 특이사항
  String? note;

  /// 대표가 남긴 의견 (반려 사유 등)
  String? comment;

  bool get submitted => status != _PayStatus.draft;

  String get insuranceLabel => type == _EmployType.freelance
      ? '4대보험 대상 아님'
      : insurances.isEmpty
      ? '보험 미가입'
      : insurances.map((i) => i.label).join(', ');

  /// 지급 항목
  List<_PayItem> get pays => [
    _PayItem('기본급', _companyBase.base),
    _PayItem(
      'PT 세션 수당',
      sessions * _companyBase.sessionRate,
      note: '$sessions회 × ${_amount(_companyBase.sessionRate)}',
    ),
    _PayItem(
      '신규 등록',
      newSignups * _companyBase.newBonus,
      note: '$newSignups건 × ${_amount(_companyBase.newBonus)}',
    ),
    _PayItem(
      '재등록',
      reSignups * _companyBase.reBonus,
      note: '$reSignups건 × ${_amount(_companyBase.reBonus)}',
    ),
  ];

  /// 공제 항목 — 신청서에 가입했다고 적어 낸 4대보험만 뗀다.
  /// 소득세는 회사가 따로 처리하므로 여기서 다루지 않는다.
  List<_PayItem> get deductions {
    // 프리랜서는 4대보험 대상이 아니라 뗄 게 없다
    if (type == _EmployType.freelance) return const [];

    final pay = gross;
    int cut(num value) => (value ~/ 10) * 10;

    final items = <_PayItem>[];
    if (insurances.contains(_Insurance.pension)) {
      items.add(_PayItem('국민연금', cut(pay * 0.045), note: '4.5%'));
    }
    if (insurances.contains(_Insurance.health)) {
      final health = cut(pay * 0.03545);
      items
        ..add(_PayItem('건강보험', health, note: '3.545%'))
        ..add(_PayItem('장기요양', cut(health * 0.1295), note: '건강보험의 12.95%'));
    }
    if (insurances.contains(_Insurance.employment)) {
      items.add(_PayItem('고용보험', cut(pay * 0.009), note: '0.9%'));
    }
    return items;
  }

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
        type: _EmployType.regular,
        insurances: {
          _Insurance.pension,
          _Insurance.health,
          _Insurance.employment,
        },
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
