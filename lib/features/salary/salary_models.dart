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

/// 급여 조건 변경 신청 상태
enum _RequestStatus {
  pending('승인 대기'),
  approved('승인 완료'),
  rejected('반려');

  const _RequestStatus(this.label);

  final String label;

  Color get color => switch (this) {
    _RequestStatus.pending => AppColors.warning,
    _RequestStatus.approved => AppColors.success,
    _RequestStatus.rejected => AppColors.error,
  };
}

/// 급여 조건 신청 (목업)
///
/// 기본급·세션 단가처럼 회사가 정하는 값은 [_companyBase]에 있고,
/// 고용 형태와 보험 가입 여부는 본인이 신고한다. 대표가 승인해야
/// 그달 급여부터 적용된다.
class _PayRequest {
  _PayRequest({
    required this.requestedAt,
    required this.type,
    required this.insurances,
    required this.effectiveFrom,
    this.reason,
    this.status = _RequestStatus.pending,
    this.decidedAt,
    this.comment,
  });

  final DateTime requestedAt;
  final _EmployType type;
  final Set<_Insurance> insurances;

  /// 적용을 시작할 달
  final DateTime effectiveFrom;

  /// 본인이 적은 사유
  final String? reason;

  _RequestStatus status;
  DateTime? decidedAt;

  /// 대표가 남긴 의견 (반려 사유 등)
  String? comment;

  String get insuranceLabel =>
      insurances.isEmpty ? '보험 미가입' : insurances.map((i) => i.label).join(', ');
}

/// 회사가 정해 주는 값 — 본인이 못 바꾼다
class _CompanyTerms {
  const _CompanyTerms({
    required this.base,
    required this.sessionRate,
    required this.newBonus,
    required this.reBonus,
    required this.meal,
  });

  final int base;
  final int sessionRate;
  final int newBonus;
  final int reBonus;
  final int meal;
}

const _companyBase = _CompanyTerms(
  base: 2400000,
  sessionRate: 15000,
  newBonus: 50000,
  reBonus: 20000,
  meal: 100000,
);

/// 급여 조건 신청 내역 (최신순)
final _requests = <_PayRequest>[
  _PayRequest(
    requestedAt: DateTime(2026, 2, 24),
    type: _EmployType.regular,
    insurances: {_Insurance.pension, _Insurance.health, _Insurance.employment},
    effectiveFrom: DateTime(2026, 3),
    reason: '4대보험 가입 신고',
    status: _RequestStatus.approved,
    decidedAt: DateTime(2026, 2, 26),
  ),
  _PayRequest(
    requestedAt: DateTime(2025, 11, 12),
    type: _EmployType.parttime,
    insurances: {},
    effectiveFrom: DateTime(2025, 12),
    reason: '주 3일 근무로 전환 요청',
    status: _RequestStatus.rejected,
    decidedAt: DateTime(2025, 11, 14),
    comment: '근무표상 주 20시간이라 아르바이트 조건에 맞지 않아요. 정규직으로 유지합니다.',
  ),
];

/// 지금 적용 중인 조건 — 승인된 신청 중 가장 최근 것
_PayRequest get _appliedRequest => _requests.firstWhere(
  (r) => r.status == _RequestStatus.approved,
  orElse: () => _PayRequest(
    requestedAt: DateTime(2023, 3, 2),
    type: _EmployType.regular,
    insurances: {_Insurance.pension, _Insurance.health, _Insurance.employment},
    effectiveFrom: DateTime(2023, 3),
    status: _RequestStatus.approved,
  ),
);

/// 대표 승인을 기다리는 신청 (없으면 null)
_PayRequest? get _pendingRequest {
  for (final request in _requests) {
    if (request.status == _RequestStatus.pending) return request;
  }
  return null;
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
        // 승인된 조건 그대로 — 회사가 정한 값 + 본인이 신고한 보험
        type: _appliedRequest.type,
        insurances: _appliedRequest.insurances,
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
  required _EmployType type,
  required Set<_Insurance> insurances,
}) {
  final base = _companyBase.base;
  final sessionRate = _companyBase.sessionRate;
  final newBonus = _companyBase.newBonus;
  final reBonus = _companyBase.reBonus;
  final meal = _companyBase.meal;

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

  // 프리랜서는 사업소득 3.3% 원천징수로 끝난다
  if (type == _EmployType.freelance) {
    return _Payslip(
      month: month,
      type: type,
      pays: pays,
      deductions: [
        _PayItem('사업소득세', cut(taxable * 0.03), note: '3%'),
        _PayItem('지방소득세', cut(taxable * 0.003), note: '0.3%'),
      ],
      sessions: sessions,
      status: status,
    );
  }

  // 나머지는 본인이 신고해 승인받은 보험만 뗀다
  final deductions = <_PayItem>[];
  if (insurances.contains(_Insurance.pension)) {
    deductions.add(_PayItem('국민연금', cut(taxable * 0.045), note: '4.5%'));
  }
  if (insurances.contains(_Insurance.health)) {
    final health = cut(taxable * 0.03545);
    deductions
      ..add(_PayItem('건강보험', health, note: '3.545%'))
      ..add(_PayItem('장기요양', cut(health * 0.1295), note: '건강보험의 12.95%'));
  }
  if (insurances.contains(_Insurance.employment)) {
    deductions.add(_PayItem('고용보험', cut(taxable * 0.009), note: '0.9%'));
  }

  final incomeTax = cut(
    taxable * (type == _EmployType.regular ? 0.031 : 0.006),
  );
  deductions
    ..add(_PayItem('소득세', incomeTax))
    ..add(_PayItem('지방소득세', cut(incomeTax * 0.1), note: '소득세의 10%'));

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
