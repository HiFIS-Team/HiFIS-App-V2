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
bool get _isPayBoss => myRole == Role.master || myRole == Role.admin;

/// 급여 결재 카드 — '급여 신청서 작성' 자리를 대신한다
///
/// **금액은 여기 안 적는다.** 화면 전체(8월 급여·최근 6개월·지급)가 이미
/// 이 사람 것을 그리고 있어서, 카드에 또 적으면 같은 값이 두 벌이 된다.
/// 여기서는 **누구 것을 보고 있는지**와 **처리 버튼**만 맡는다.
///
/// 여러 건이 밀려 있으면 오른쪽 끝 `1/2` 로 넘긴다 — 넘기면 화면 전체가
/// 그 사람 것으로 바뀐다.
class _PayrollDecideCard extends StatelessWidget {
  _PayrollDecideCard({
    required this.inbox,
    required this.index,
    required this.onMove,
    required this.onApprove,
    required this.onReject,
    required this.onPay,
  });

  final List<Payslip> inbox;
  final int index;

  /// -1 이면 앞 건, 1 이면 뒷 건
  final ValueChanged<int> onMove;

  final ValueChanged<Payslip> onApprove;
  final ValueChanged<Payslip> onReject;
  final ValueChanged<Payslip> onPay;

  /// 신청이 있을 때의 높이 — 다 처리하고 나면 카드가 쪼그라들어
  /// 옆 지급 카드와 어긋난다 (월차 결재에서 겪은 것과 같다)
  static const _emptyHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final target = inbox.isEmpty
        ? null
        : inbox[index.clamp(0, inbox.length - 1)];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('급여 결재', style: AppTextStyles.label),
          SizedBox(height: 16),
          if (target == null)
            SizedBox(
              height: _emptyHeight,
              child: Center(
                child: EmptyCard(
                  icon: CupertinoIcons.tray,
                  text: '들어온 급여 신청이 없어요',
                  framed: false,
                ),
              ),
            )
          else ...[
            _PayrollDecideRow(
              payslip: target,
              index: index.clamp(0, inbox.length - 1),
              total: inbox.length,
              onMove: onMove,
            ),
            // 데스크톱은 옆 지급 카드와 높이를 맞추느라 남는 자리가 생긴다
            if (isDesktop) Spacer() else SizedBox(height: 18),
            if (isDesktop) SizedBox(height: 18),
            // 서버가 처리를 MASTER 에게만 연다 — 눌러도 403 날 버튼은 안 보여준다
            if (_canDecide)
              if (target.status == PayslipStatus.approved)
                // 승인은 끝났고 실제 입금만 남은 건
                _PayButton(onTap: () => onPay(target))
              else
                DecideButtons(
                  fill: true,
                  onApprove: () => onApprove(target),
                  onReject: () => onReject(target),
                ),
          ],
        ],
      ),
    );
  }
}

/// 지급 처리 버튼 — 승인된 건에만 뜬다
class _PayButton extends StatelessWidget {
  _PayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.97,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '지급 처리',
        style: AppTextStyles.body2.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// 결재 대기 한 건 — 누구 것을 보고 있는지
class _PayrollDecideRow extends StatelessWidget {
  _PayrollDecideRow({
    required this.payslip,
    required this.index,
    required this.total,
    required this.onMove,
  });

  final Payslip payslip;
  final int index;
  final int total;

  final ValueChanged<int> onMove;

  String get _name =>
      StaffDirectory.instance.byId(payslip.employeeId)?.name ?? '알 수 없음';

  String get _month => '${int.parse(payslip.yearMonth.substring(5))}월 급여';

  /// 지금 어느 단계인가 — 승인 대기냐, 입금만 남았냐
  String get _stage =>
      payslip.status == PayslipStatus.approved ? '승인 완료 · 지급 대기' : '승인 대기';

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    '$_month · $_stage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            // 한 건뿐이면 셈이 필요 없다
            if (total > 1) ...[
              SizedBox(width: 8),
              _arrow(CupertinoIcons.chevron_left, () => onMove(-1)),
              Text(
                '${index + 1}/$total',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              _arrow(CupertinoIcons.chevron_right, () => onMove(1)),
            ],
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
            child: Text('특이사항 · ${payslip.note}', style: AppTextStyles.caption),
          ),
        ],
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Padding(
      padding: EdgeInsets.all(5),
      child: Icon(icon, size: 12, color: AppColors.textTertiary),
    ),
  );
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
      scale: 0.96,
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
