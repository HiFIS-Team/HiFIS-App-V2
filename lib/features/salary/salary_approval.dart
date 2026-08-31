part of 'salary_screen.dart';

// ---------------------------------------------------------------------------
// 결재 — 급여 신청을 받아 승인·반려·지급 처리한다
//
// 서버 권한을 그대로 따른다:
//   조회   MASTER · ADMIN   (ADMIN 은 지켜보는 자리라 버튼이 없다)
//   처리   MASTER
// 눌러도 403 이 날 버튼은 아예 안 보여준다.
// ---------------------------------------------------------------------------

/// 결재 탭을 볼 수 있는 사람 — **MASTER · ADMIN**
///
/// **MANAGER 는 뺐다 (2026-08-14).** 점장도 본인 급여를 신청하는 쪽이지
/// 결재하는 쪽이 아니다. 결재가 대표 전용이 되면서 점장에게는 누를 수 없는
/// 목록만 남았는데, 거기에 **남의 급여 금액**이 그대로 적혀 있었다.
///
/// 이 값은 이제 [_isPayBoss] 와 같다. 그래서 아래 `_canSeeApproval &&
/// !_isPayBoss` 로 만들던 `내 급여 / 결재` **탭 줄이 아무에게도 안 뜬다** —
/// 대표·관리자는 화면 전체가 결재 화면이라 원래 탭이 없었고, 점장은
/// 이제 직원과 같은 화면이다.
bool get _canSeeApproval => _isPayBoss;

/// 실제로 승인·반려·지급을 누를 수 있는 사람 — **MASTER 만**
/// (ADMIN·MANAGER 는 결재함이 보이되 버튼이 없다)
bool get _canDecide => myRole.canApprove;

/// 급여 화면을 **관리 화면으로** 보는 사람 (MASTER · ADMIN)
///
/// 이 사람들 자리에서는 '급여 신청서 작성' 칸이 결재함으로 바뀐다.
/// MANAGER 는 본인도 급여를 신청해서 예전 화면 그대로다 (근태와 같은 기준).
bool get _isPayBoss => myRole.boss;

/// 그 탭이 비었을 때 할 말
String _boxEmptyText(PayslipStatus status) => switch (status) {
  PayslipStatus.draft => '아직 안 낸 사람이 없어요',
  PayslipStatus.submitted => '들어온 급여 신청이 없어요',
  PayslipStatus.rejected => '반려한 급여가 없어요',
  _ => '지급을 기다리는 급여가 없어요',
};

/// 그 상태를 가리키는 색 — 금액 배지에 입힌다
Color _boxColor(PayslipStatus status) => switch (status) {
  PayslipStatus.draft => AppColors.gray400,
  PayslipStatus.submitted => AppColors.primary,
  PayslipStatus.rejected => AppColors.error,
  _ => AppColors.success,
};

/// 한 탭의 사람 목록 — **사람마다 카드 하나**
///
/// 조직도·동료 평가·내 업무 명단과 같은 틀이다 (2026-08-31 요청). 같은 사람을
/// 보는 자리인데 화면마다 줄 모양이 다르면 안 된다 — PC 는 공용 [PersonCard],
/// 폰은 그 카드와 같은 결의 줄이다.
class _PayrollBoxList extends StatelessWidget {
  _PayrollBoxList({
    required this.payslips,
    required this.status,
    required this.onOpen,
  });

  final List<Payslip> payslips;

  /// 이 탭이 담는 상태 — 빈 문구와 배지 색이 여기서 나온다
  final PayslipStatus status;

  final ValueChanged<Payslip> onOpen;

  @override
  Widget build(BuildContext context) {
    if (payslips.isEmpty) {
      return EmptyCard(icon: CupertinoIcons.tray, text: _boxEmptyText(status));
    }
    // PC 는 폭이 남아서 두 칸으로 세운다 (내 업무 명단과 같은 규칙)
    final columns = isDesktop ? 2 : 1;
    final cards = [
      for (final payslip in payslips)
        _PayrollPersonCard(
          payslip: payslip,
          color: _boxColor(status),
          onTap: () => onOpen(payslip),
        ),
    ];
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var row = 0; row * columns < cards.length; row++) ...[
          if (row > 0) SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) SizedBox(width: 12),
                  Expanded(
                    child: switch (row * columns + col) {
                      final i when i < cards.length => cards[i],
                      // 마지막 줄이 덜 찼으면 빈 자리로 둔다
                      _ => SizedBox.shrink(),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 사람 한 명 — 아바타 · 이름 · 직급, 오른쪽에 실수령액
class _PayrollPersonCard extends StatelessWidget {
  _PayrollPersonCard({
    required this.payslip,
    required this.color,
    required this.onTap,
  });

  final Payslip payslip;
  final Color color;
  final VoidCallback onTap;

  Employee? get _person => StaffDirectory.instance.byId(payslip.employeeId);
  String get _name => _person?.name ?? '알 수 없음';

  /// 이름 아래 한 줄 — 직급과 어느 달 것인지
  String get _subtitle {
    final rank = _person?.rank.label ?? '';
    final month = '${_monthOf(payslip)}월 급여';
    return rank.isEmpty ? month : '$rank · $month';
  }

  @override
  Widget build(BuildContext context) {
    final badge = _AmountBadge(
      amount: payslip.net,
      color: color,
      // 본인이 고쳐서 낸 건은 열기 전에 표가 나야 한다
      adjusted: payslip.adjusted,
    );

    if (isDesktop) {
      return PersonCard(
        name: _name,
        subtitle: _subtitle,
        color: _person?.color,
        avatarUrl: _person?.avatarImageUrl,
        trailing: badge,
        onTap: onTap,
      );
    }

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Avatar(name: _name, size: 40, imageUrl: _person?.avatarImageUrl),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            badge,
          ],
        ),
      ),
    );
  }
}

/// 오른쪽 금액 배지 — 내 업무 명단의 `3/5` 배지와 같은 모양
class _AmountBadge extends StatelessWidget {
  _AmountBadge({
    required this.amount,
    required this.color,
    this.adjusted = false,
  });

  final int amount;
  final Color color;

  /// 본인이 커미션을 고쳐서 낸 건인가
  final bool adjusted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _won(amount),
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
      if (adjusted) ...[
        SizedBox(height: 4),
        Text(
          '금액 수정',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
          ),
        ),
      ],
    ],
  );
}

int _monthOf(Payslip payslip) => int.parse(payslip.yearMonth.substring(5));

/// 신청 한 건을 열어 보는 화면 — **그 사람 급여 화면 그대로**
///
/// 목록에서 이름을 누르면 밀려 들어온다. 요약·추이·지급 카드는 본인이
/// 보는 것과 **같은 위젯**이다 (두 화면이 갈리면 안 된다 — 2026-08-31 요청).
/// 처리 버튼은 화면 아래에 붙는다 — iOS 는 네이티브 리퀴드 글래스다.
///
/// 명세서는 전역 [_payslips] 에 담긴다. 이 화면이 떠 있는 동안은 그 사람
/// 것이고, 닫으면 부른 쪽이 다시 채운다.
class _PayslipReview extends StatefulWidget {
  _PayslipReview({required this.payslip});

  final Payslip payslip;

  @override
  State<_PayslipReview> createState() => _PayslipReviewState();
}

class _PayslipReviewState extends State<_PayslipReview> {
  /// 지금 보고 있는 명세서 — 처리하면 서버가 돌려준 것으로 갈린다
  late Payslip _payslip = widget.payslip;

  bool _ready = false;

  /// 처리하는 중 — 두 번 눌러 두 번 보내지 않게 잠근다
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadPayslips(
        employeeId: _payslip.employeeId,
        month: _payslip.yearMonth,
      );
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _ready = true);
  }

  String get _name =>
      StaffDirectory.instance.byId(_payslip.employeeId)?.name ?? '알 수 없음';

  /// 처리 한 번 — **화면을 바로 바꾸고** 목록은 닫을 때 맞춘다
  Future<void> _run(Future<Payslip> Function() action, String done) async {
    if (_busy) return;
    _busy = true;
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _payslip = updated;
        for (final row in _payslips) {
          if (row.source?.id == updated.id) row.source = updated;
        }
      });
      AppToast.show(context, done);
      // 승인은 '지급 처리' 가 남아서 화면에 머문다. 지급·반려는 끝이라 닫는다
      if (updated.status != PayslipStatus.approved) Navigator.pop(context);
    } catch (error) {
      _busy = false;
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  void _approve() => _run(() => PayrollApi.approve(_payslip.id), '승인했어요');

  Future<void> _reject() async {
    final reason = await askRejectReason(context, hint: '예) 추가 근무 시간이 기록과 달라요');
    if (reason == null || !mounted) return;
    await _run(() => PayrollApi.reject(_payslip.id, reason), '반려했어요');
  }

  void _pay() => _run(() => PayrollApi.pay(_payslip.id), '지급 처리했어요');

  /// 아래에 붙는 처리 버튼 — 서버가 MASTER 에게만 열어 준다
  Widget? _actions() {
    if (!_canDecide) return null;
    if (_payslip.status == PayslipStatus.approved) {
      return GlassBottomButton(label: '지급 처리', onPressed: _pay);
    }
    return BottomActionBar(
      children: [
        Expanded(
          child: BottomActionButton(
            id: 'pay-reject',
            label: '반려',
            filled: false,
            tinted: false,
            onPressed: _reject,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: BottomActionButton(
            id: 'pay-approve',
            label: '승인',
            onPressed: _approve,
          ),
        ),
      ],
    );
  }

  /// 본인 화면과 같은 카드들 — 위젯을 새로 만들지 않는다
  List<Widget> _cards() {
    final current = _payslips.isEmpty ? null : _payslips.first;
    if (current == null) return const [];
    return [
      _SummaryCard(payslip: current),
      if (_payslip.adjusted) ...[
        SizedBox(height: 12),
        _AdjustedNotice(payslip: _payslip),
      ],
      if ((_payslip.note ?? '').isNotEmpty) ...[
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppDecorations.card(),
          child: Text(
            '특이사항 · ${_payslip.note}',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
        ),
      ],
      SizedBox(height: 12),
      _TrendCard(),
      SizedBox(height: 12),
      _PayCard(payslip: current),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = '$_name · ${_monthOf(_payslip)}월 급여';
    final cards = _ready ? _cards() : const <Widget>[];
    final actions = _actions();

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: title,
        bottomBar: actions,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            actions == null ? 32 : GlassBottomButton.inset(context),
          ),
          children: _ready
              ? cards
              : [SizedBox(height: 120, child: Center(child: DelayedSpinner()))],
        ),
      );
    }

    return Container(
      width: dialogWidth(context, 620),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.title3),
          SizedBox(height: 14),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _ready
                  ? cards
                  : [
                      SizedBox(
                        height: 120,
                        child: Center(child: DelayedSpinner()),
                      ),
                    ],
            ),
          ),
          if (actions != null) ...[SizedBox(height: 16), actions],
        ],
      ),
    );
  }
}

/// 결재함 한 덩어리 — 대기 · 지급 대기 · 처리 내역
class _ApprovalTab extends StatefulWidget {
  _ApprovalTab();

  @override
  State<_ApprovalTab> createState() => _ApprovalTabState();
}

class _ApprovalTabState extends State<_ApprovalTab> {
  bool _loading = true;

  /// 결재를 기다리는 것 (제출됨)
  List<Payslip> _waiting = const [];

  /// 승인했지만 아직 입금 전
  List<Payslip> _toPay = const [];

  /// 지급·반려까지 끝난 것
  List<Payslip> _done = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 대기함과 처리함을 같이 띄운다
      final inbox = PayrollApi.box('inbox');
      final decided = PayrollApi.box('decided');
      final waiting = await inbox;
      final handled = await decided;
      if (!mounted) return;
      setState(() {
        _waiting = waiting;
        // 승인만 된 건 아직 돈이 안 나갔다 — 지급 처리가 남은 자리다
        _toPay = [
          for (final p in handled)
            if (p.status == PayslipStatus.approved) p,
        ];
        _done = [
          for (final p in handled)
            if (p.status != PayslipStatus.approved) p,
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _approve(Payslip payslip) async {
    await _run(() => PayrollApi.approve(payslip.id), '승인했어요');
  }

  Future<void> _reject(Payslip payslip) async {
    final reason = await askRejectReason(context, hint: '예) 추가 근무 시간이 기록과 달라요');
    if (reason == null || !mounted) return;
    await _run(() => PayrollApi.reject(payslip.id, reason), '반려했어요');
  }

  Future<void> _pay(Payslip payslip) async {
    await _run(() => PayrollApi.pay(payslip.id), '지급 처리했어요');
  }

  /// 서버에 보내는 중 — 목록을 다시 받을 때까지 버튼이 남아 있어서
  /// 안 잠그면 같은 결재가 두 번 나간다
  bool _busy = false;

  /// 처리하고 목록을 다시 받는다 — 함이 셋이라 한 건만 옮기면 어긋나기 쉽다
  Future<void> _run(Future<Payslip> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SkeletonGroup(
        child: SkeletonCard(
          padding: EdgeInsets.all(20),
          children: [SkeletonRows(rows: 5, trailing: 84)],
        ),
      );
    }

    if (_waiting.isEmpty && _toPay.isEmpty && _done.isEmpty) {
      return EmptyCard(icon: CupertinoIcons.tray, text: '들어온 급여 신청이 없어요');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_waiting.isNotEmpty) ...[
          _ApprovalGroup(
            title: '승인 대기',
            count: _waiting.length,
            children: [
              for (final payslip in _waiting)
                _ApprovalRow(
                  payslip: payslip,
                  busy: _busy,
                  onApprove: _canDecide ? () => _approve(payslip) : null,
                  onReject: _canDecide ? () => _reject(payslip) : null,
                ),
            ],
          ),
          SizedBox(height: 12),
        ],
        if (_toPay.isNotEmpty) ...[
          _ApprovalGroup(
            title: '지급 대기',
            count: _toPay.length,
            children: [
              for (final payslip in _toPay)
                _ApprovalRow(
                  payslip: payslip,
                  busy: _busy,
                  onPay: _canDecide ? () => _pay(payslip) : null,
                ),
            ],
          ),
          SizedBox(height: 12),
        ],
        if (_done.isNotEmpty)
          _ApprovalGroup(
            title: '처리 내역',
            count: _done.length,
            children: [
              for (final payslip in _done) _ApprovalRow(payslip: payslip),
            ],
          ),
      ],
    );
  }
}

/// 사유를 받아 온다 — 반려는 이유 없이 보내면 신청자가 뭘 고칠지 모른다

/// 함 하나 — 제목 · 건수 · 줄들
class _ApprovalGroup extends StatelessWidget {
  _ApprovalGroup({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '$count',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 4),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 승인·반려·지급 버튼 — 전자결재 화면과 같은 모양으로 맞춘다
/// 줄 안에 들어가는 '지급 처리' — [DecideButtons] 의 승인 쪽과 같은 모양
///
/// 지급은 승인·반려처럼 짝이 없는 한 개짜리라 공용 위젯에 안 든다.
/// 대신 채움·모서리·여백을 그쪽 승인 버튼에 맞춘다.
///
/// **글자는 `지급 처리` 다** (`지급 완료` 가 아니다). 완료는 그 일이 끝난
/// **상태**를 부르는 말이라 알약이 쓰고, 버튼은 지금부터 할 일을 적는다.
class _PayInlineButton extends StatelessWidget {
  _PayInlineButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '지급 처리',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 신청 한 건 — 누가 · 몇 월 · 얼마 · 언제 나갈 돈인지
class _ApprovalRow extends StatelessWidget {
  _ApprovalRow({
    required this.payslip,
    this.busy = false,
    this.onApprove,
    this.onReject,
    this.onPay,
  });

  final Payslip payslip;

  /// null 이면 버튼을 안 그린다 (ADMIN 이거나 그 단계가 아닌 것)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPay;

  /// 이 화면이 서버에 보내는 중 — 버튼이 안 눌린다
  final bool busy;

  String get _name =>
      StaffDirectory.instance.byId(payslip.employeeId)?.name ?? '알 수 없음';

  @override
  Widget build(BuildContext context) {
    final status = _PayStatus.of(payslip.status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: _name, size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_monthLabel(payslip.month)} · '
                      '${_dayLabel(payslip.payday)} 지급',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _won(payslip.net),
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  _StatusTag(status: status),
                ],
              ),
            ],
          ),
          if (payslip.adjusted) ...[
            SizedBox(height: 10),
            _AdjustedNotice(payslip: payslip),
          ],
          if ((payslip.note ?? '').isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(payslip.note!, style: AppTextStyles.caption),
            ),
          ],
          if ((payslip.rejectReason ?? '').isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '반려 사유 · ${payslip.rejectReason}',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (onApprove != null || onReject != null || onPay != null) ...[
            SizedBox(height: 12),
            // 프로젝트·전자결재와 **같은 위젯**을 쓴다. 예전에는 이 파일 안에
            // 똑같이 생긴 `_DecideButton` 을 따로 두고 있어서, 위 목록 카드
            // (`DecideButtons`)와 모서리·여백이 미묘하게 갈렸다.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onApprove != null && onReject != null)
                  DecideButtons(
                    busy: busy,
                    onApprove: onApprove!,
                    onReject: onReject!,
                  ),
                if (onPay != null) _PayInlineButton(onTap: onPay!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 본인이 커미션을 고쳐서 낸 명세서에만 붙는 줄 — 안 고쳤으면 안 뜬다
///
/// 고친 값으로 덮어써 버리면 **무엇을 승인하는지 모른 채 결재**하게 된다.
/// 자동 집계가 빠뜨린 수업을 바로잡으라고 연 자리라, 원래 값을 같이 보여준다.
class _AdjustedNotice extends StatelessWidget {
  _AdjustedNotice({required this.payslip});

  final Payslip payslip;

  int get _auto =>
      (payslip.incentiveNewAuto ?? 0) + (payslip.incentiveRenewalAuto ?? 0);
  int get _asked => payslip.incentiveNew + payslip.incentiveRenewal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // 특이사항 칸과 같은 회색 면이다 — 색을 새로 만들지 않는다
      // (`AppColors` 머리말: 여기 없는 색을 화면에서 만들지 않는다)
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'PT 커미션을 고쳐서 신청했어요 · 자동 계산 ${_won(_auto)} → 신청 ${_won(_asked)}',
        style: AppTextStyles.caption,
      ),
    );
  }
}
