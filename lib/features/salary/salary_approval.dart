part of 'salary_screen.dart';

// ---------------------------------------------------------------------------
// 결재 — 급여 신청을 받아 승인·반려·지급 처리한다
//
// 서버 권한을 그대로 따른다:
//   조회   MASTER · ADMIN · MANAGER   (MANAGER 는 서버가 자기 지점으로 좁힌다)
//   처리   MASTER · MANAGER           (ADMIN 은 지켜보는 자리라 버튼이 없다)
// 눌러도 403 이 날 버튼은 아예 안 보여준다.
// ---------------------------------------------------------------------------

/// 결재 탭을 볼 수 있는 사람
bool get _canSeeApproval =>
    myRole == Role.master || myRole == Role.admin || myRole == Role.manager;

/// 실제로 승인·반려·지급을 누를 수 있는 사람
bool get _canDecide => myRole.canApprove;

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

  /// 처리하고 목록을 다시 받는다 — 함이 셋이라 한 건만 옮기면 어긋나기 쉽다
  Future<void> _run(Future<Payslip> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
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
class _DecideButton extends StatelessWidget {
  _DecideButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: filled ? 22 : 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: filled ? null : Border.all(color: AppColors.gray200),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: filled ? Colors.white : (color ?? AppColors.textSecondary),
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
    this.onApprove,
    this.onReject,
    this.onPay,
  });

  final Payslip payslip;

  /// null 이면 버튼을 안 그린다 (ADMIN 이거나 그 단계가 아닌 것)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPay;

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
              Avatar(name: _name, size: 36),
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
            // 전자결재 화면과 같은 모양 — 반려는 테두리만, 승인은 채운다
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null) ...[
                  _DecideButton(
                    label: '반려',
                    color: AppColors.error,
                    onTap: onReject!,
                  ),
                  SizedBox(width: 8),
                ],
                if (onApprove != null)
                  _DecideButton(label: '승인', filled: true, onTap: onApprove!),
                if (onPay != null)
                  _DecideButton(label: '지급 완료', filled: true, onTap: onPay!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
