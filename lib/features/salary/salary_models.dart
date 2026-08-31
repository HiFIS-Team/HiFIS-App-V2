part of 'salary_screen.dart';

/// 급여 신청서 상태
///
/// 본인이 제출하고 대표가 승인해야 지급된다.
/// 미제출 → 승인 대기 → 승인 완료 → 지급 완료 (반려되면 다시 제출)
///
/// '지급 완료'는 대표가 실제로 입금한 뒤 직접 처리한다 — 지급일이 지났다고
/// 자동으로 넘어가지 않는다 (이체 확인 없이 찍으면 오표기가 된다).
///
/// **이름은 월차·전자결재와 같이 쓴다** (`대기` · `승인` · `반려`).
/// 예전에는 여기만 `승인 대기` · `승인 완료` 라 같은 알약인데 급여에서만
/// 글자가 길었다. `지급 완료` 만 두 마디로 남는데, 이 단계가 급여에만
/// 있어서 `지급` 한 마디로는 대기인지 끝난 건지 안 갈린다.
enum _PayStatus {
  draft('미제출'),
  pending('대기'),
  approved('승인'),
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

/// 신청서에서 본인이 고칠 수 있는 줄 — 기본급은 여기 없다
///
/// 자동 집계가 빠뜨린 수업(대타·기록 누락)을 신청할 때 바로잡으라고 연 자리다.
enum _Adjustable { incentiveNew, incentiveRenewal }

/// 명세서 한 줄 — 이름, 계산 근거, 금액
class _PayItem {
  const _PayItem(this.label, this.amount, {this.note, this.adjust});

  final String label;
  final int amount;

  /// '62회 × 15,000' 처럼 왜 이 금액인지
  final String? note;

  /// 신청서에서 고칠 수 있는 줄이면 어느 값인지 — null 이면 못 고친다
  final _Adjustable? adjust;
}

/// 한 달치 급여 명세서
///
/// 금액은 전부 서버가 계산한다. 직군 정책·인센티브 요율이 서버에 있어서
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

  /// 신청서에서 본인이 고친 커미션 — null 이면 서버 계산값 그대로 낸다
  ///
  /// 폼이 여기 담아 두면 [_SalaryScreenState._submit] 이 서버로 보낸다
  /// (특이사항 [note] 와 같은 방식이다).
  int? adjustNew;
  int? adjustRenewal;

  /// 서버가 계산한 원래 커미션 — 신청서 입력칸의 시작값이자 비교 기준
  ///
  /// 확정 명세서는 `incentiveNewAuto`(고치기 전 값), 아직 없는 달은 진행 중
  /// 누계를 쓴다. 이 기능 전에 만들어진 명세서는 `auto` 가 없어 지금 값이 곧 원래 값이다.
  int get autoNew =>
      source?.incentiveNewAuto ??
      source?.incentiveNew ??
      _live?.incentiveNew ??
      0;
  int get autoRenewal =>
      source?.incentiveRenewalAuto ??
      source?.incentiveRenewal ??
      _live?.incentiveRenewal ??
      0;

  /// 기본급 — 신청서에서 못 고친다 (직군 정책에서 나온다)
  int get baseSalary => source?.baseSalary ?? 0;

  /// 본인이 커미션을 고쳐서 낸 명세서인가 — 결재 화면이 차이를 보여준다
  bool get adjusted => source?.adjusted ?? false;

  /// 신청서에서 커미션을 고칠 수 있는 사람인가 — **서버가 정한다**
  ///
  /// 알바(시급제)와 커미션 요율이 0인 직군(FC)은 고칠 자리가 없다.
  /// 앱이 직군으로 따로 판정하면 요율이 바뀔 때 어긋나서, 못 고치는 사람에게
  /// 칸이 열리고 제출에서 400 이 난다.
  bool get canAdjust => _accrued?.canAdjust ?? false;

  /// 진행 중인 주기라면 지금까지 쌓인 커미션 — 아니면 null
  ///
  /// 명세서가 아직 없는 달(`source == null`) 중에서 **이번 주기 하나**만 해당한다.
  Accrued? get _live =>
      source == null && _accrued?.yearMonth == key ? _accrued : null;

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
  ///
  /// **진행 중인 주기는 커미션 두 줄이 실시간으로 오른다** — 세션 싸인을
  /// 찍을 때마다 서버가 다시 세어 준다. 기본급은 지급일에 확정되므로
  /// 그때까지 0 이다 (미리 더해 두면 아직 안 정해진 금액을 약속하는 셈이다).
  List<_PayItem> get pays {
    final payslip = source;
    if (payslip == null) {
      final live = _live;
      return [
        const _PayItem('기본급', 0),
        _PayItem(
          'PT 커미션 · 신규',
          live?.incentiveNew ?? 0,
          note: (live?.newSessions ?? 0) == 0
              ? null
              : '워크인 ${live!.newSessions}회',
          adjust: _Adjustable.incentiveNew,
        ),
        _PayItem(
          'PT 커미션 · 재등록',
          live?.incentiveRenewal ?? 0,
          note: _renewalNote(live?.renewalSessions ?? 0, downgraded),
          adjust: _Adjustable.incentiveRenewal,
        ),
      ];
    }
    return [
      _PayItem('기본급', payslip.baseSalary),
      _PayItem(
        'PT 커미션 · 신규',
        payslip.incentiveNew,
        note: newSessions == 0 ? null : '워크인 $newSessions회',
        adjust: _Adjustable.incentiveNew,
      ),
      _PayItem(
        'PT 커미션 · 재등록',
        payslip.incentiveRenewal,
        // 서버가 재등록과 지인소개를 같은 요율로 한 통에 담는다
        note: _renewalNote(renewalSessions, downgraded),
        adjust: _Adjustable.incentiveRenewal,
      ),
      if (payslip.otherAllowances != 0)
        _PayItem('기타 수당', payslip.otherAllowances),
    ];
  }

  /// 재등록 요율이 **워크인 요율로 내려갔나** (트레이너만, 2026-08-31)
  ///
  /// 확정된 달은 명세서 근거에서, 진행 중인 주기는 실시간 값에서 읽는다.
  bool get downgraded =>
      source?.basis.renewalDowngraded ?? _live?.renewalDowngraded ?? false;

  /// 재등록 줄 밑 한 마디 — 내려갔으면 **왜 낮은지**를 같이 적는다
  ///
  /// 안 적으면 트레이너가 "왜 50% 가 아니지" 를 알 길이 없어서, 급여를 받고
  /// 나서야 물어보게 된다 (2026-08-31 대표 요청).
  static String? _renewalNote(int sessions, bool downgraded) {
    final count = sessions == 0 ? null : '소개 포함 $sessions회';
    if (!downgraded) return count;
    const why = '300만 미만이라 40% 적용';
    return count == null ? why : '$count · $why';
  }

  /// 커미션이 왜 이 금액인지 — 카드 맨 아래 한 줄
  ///
  /// **늘 문장을 돌려준다.** 산출 안 된 달은 [hasPayNote] 가 false 라 안 보이는데,
  /// 안 보일 때도 같은 문장으로 자리를 잡아야 카드 높이가 안 흔들린다
  /// (짧은 빈칸으로 채우면 두 줄로 접히는 문장과 높이가 어긋난다).
  String get payNote => '이번 달 세션 $sessions회 · 회차마다 등록 단가가 달라 합계로 보여드려요';

  /// 각주를 보여줄 달인가 — 산출된 달과 진행 중인 주기
  bool get hasPayNote => source != null || _live != null;

  /// 공제 항목 (4대 보험·세금) — 서버가 직군·공제 방식에 따라 계산한다
  List<_PayItem> get deductions => [
    for (final line in source?.deductions ?? const <DeductionLine>[])
      _PayItem(line.label, line.amount),
  ];

  /// 세전 총액 — 진행 중인 주기는 **지금까지 쌓인 커미션**이다 (기본급 전)
  int get total => source?.gross ?? _live?.total ?? 0;

  /// 실수령액
  int get net => source?.net ?? 0;

  int get totalDeduction => source?.totalDeduction ?? 0;

  /// 이번 달 세션 싸인 수 — 금액이 아니라 참고용 숫자다
  int get sessions => source?.basis.sessionSigns ?? _live?.sessionSigns ?? 0;

  /// 시급으로 계산된 달인가 (알바)
  ///
  /// 사람의 지금 고용 형태가 아니라 **그 명세서를 뽑을 때** 무엇이었는지를 본다.
  bool get hourly => source?.basis.hourly ?? false;

  /// 커미션이 붙은 세션 수 — `newSales`·`renewalSales` 는 등록 건이 아니라
  /// **세션 한 건씩**이다 (서버가 `{회차} · {워크인|재등록|지인소개}` 로 담는다).
  int get newSessions =>
      source?.basis.newSales.length ?? _live?.newSessions ?? 0;
  int get renewalSessions =>
      source?.basis.renewalSales.length ?? _live?.renewalSessions ?? 0;

  /// 지급일 — 서버가 알려 준다 (명세서에 실려 오고, 없으면 신청 창에서)
  ///
  /// 앱이 규칙을 따로 갖고 있으면 서버가 바뀔 때 어긋난다. 예전에 폴백이
  /// '익월 10일' 로 박혀 있었는데 서버는 **말일**이었다.
  DateTime get payDay =>
      source?.payday ??
      window?.payday ??
      DateTime(month.year, month.month + 1, 0);

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

/// 최근 명세서 (0번이 진행 중인 주기) — 서버에서 받아 채운다
final _payslips = <_Payslip>[];

/// 진행 중인 주기에 지금까지 쌓인 커미션 — 본인 화면일 때만 채워진다
Accrued? _accrued;

/// 명세서를 받아 [_payslips] 를 채운다.
///
/// [employeeId] 를 주면 **그 사람 것**을 받는다 — 대표·관리자가 결재하면서
/// 신청자 화면을 그대로 볼 때다. 안 주면 본인 것이다.
Future<void> _loadPayslips({String? employeeId}) async {
  // **달력 월이 아니라 급여 주기로 센다.** 동광주·첨단 트레이너는 지급일이
  // 익월 10일이라, 9월 15일에 진행 중인 것은 9월치가 아니라 10월치(9/10~10/9)다.
  // 서버가 알려 주는 그 달을 맨 위에 두고 거슬러 올라간다.
  // (남의 화면을 볼 때는 못 받으므로 예전처럼 이번 달부터 센다)
  _accrued = employeeId == null ? await _fetchAccrued() : null;
  final now = DateTime.now();
  final anchor = _accrued == null
      ? DateTime(now.year, now.month)
      : DateTime(
          int.parse(_accrued!.yearMonth.substring(0, 4)),
          int.parse(_accrued!.yearMonth.substring(5, 7)),
        );
  final months = [
    for (var i = 0; i < _monthsToLoad; i++)
      DateTime(anchor.year, anchor.month - i),
  ];

  // 명세서 범위와 신청 창을 같이 띄워 둔다 (신청 창은 이번 달만 필요하다)
  final listing = employeeId == null
      ? PayrollApi.list(
          from: yearMonthKey(months.last),
          to: yearMonthKey(months.first),
        )
      : PayrollApi.listOf(
          employeeId,
          from: yearMonthKey(months.last),
          to: yearMonthKey(months.first),
        );
  // 남의 화면을 볼 때는 신청 창이 필요 없다 — 내가 낼 것이 아니다
  final windowRequest = employeeId == null
      ? PayrollApi.window(yearMonthKey(months.first))
      : Future<PaydayWindow?>.value(null);

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

/// 쌓인 커미션 — 못 받아도 화면은 그대로 뜬다 (금액이 0으로 남을 뿐이다)
Future<Accrued?> _fetchAccrued() async {
  try {
    return await PayrollApi.accrued();
  } catch (_) {
    return null;
  }
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
String _dayLabel(DateTime value) => monthDayLabel(value);

/// 받아오는 동안의 뼈대 — 요약 · 신청 안내 · 추이 · 지급 내역 순서를 잡아 둔다
///
/// 탭 줄은 **권한으로 정해지는 것**이라 받아오기 전에도 있을지 없을지 안다.
/// 그래서 있을 사람에게만 자리를 비워 둔다 — 다 받아왔을 때 안 밀린다.
class _SalarySkeleton extends StatelessWidget {
  _SalarySkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: PhoneListScaffold(
      title: '급여',
      // SegmentedTabs 와 같은 높이(48)
      filter: _canSeeApproval && !_isPayBoss
          ? Skeleton(height: 48, radius: 14)
          : null,
      children: [
        // 이번 달 요약 — 큰 금액 한 줄이 주인공이다
        SkeletonCard(
          children: [
            Row(
              children: [
                Skeleton(width: 84, height: 13),
                Spacer(),
                Skeleton(width: 62, height: 24, radius: 12),
              ],
            ),
            SizedBox(height: 14),
            Skeleton(width: 190, height: 30, radius: 8),
            SizedBox(height: 12),
            Skeleton(width: 140, height: 12),
          ],
        ),
        SizedBox(height: 12),
        // 신청 안내 (대표는 결재함)
        SkeletonCard(
          children: [
            Skeleton(width: 150, height: 14),
            SizedBox(height: 12),
            Skeleton(height: 11),
            SizedBox(height: 16),
            Skeleton(height: 48, radius: 14),
          ],
        ),
        SizedBox(height: 12),
        // 최근 추이 — 막대 여섯 개
        SkeletonCard(
          children: [
            Skeleton(width: 96, height: 14),
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) SizedBox(width: 10),
                  Expanded(child: Skeleton(height: 40.0 + i * 12, radius: 6)),
                ],
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) SizedBox(width: 10),
                  Expanded(
                    child: Center(child: Skeleton(width: 22, height: 10)),
                  ),
                ],
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        // 지급 항목 — 이름과 금액이 마주 보는 줄들
        SkeletonCard(
          children: [
            Skeleton(width: 72, height: 14),
            SizedBox(height: 18),
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(height: 14),
              Row(
                children: [
                  Skeleton(width: 76, height: 12),
                  Spacer(),
                  Skeleton(width: 92, height: 12),
                ],
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
