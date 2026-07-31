part of 'salary_screen.dart';

/// 급여 신청서 작성 — 폰은 밀려 들어오는 화면, PC는 모달
///
/// 제출하면 그 달 급여가 대표 승인을 기다린다.
Future<bool?> _showPayslipForm(BuildContext context, _Payslip payslip) {
  if (isDesktop) {
    return showAppDialog<bool>(context, (_) => _PayslipForm(payslip: payslip));
  }
  return Navigator.push<bool>(
    context,
    CupertinoPageRoute(builder: (_) => _PayslipForm(payslip: payslip)),
  );
}

class _PayslipForm extends StatefulWidget {
  _PayslipForm({required this.payslip});

  final _Payslip payslip;

  @override
  State<_PayslipForm> createState() => _PayslipFormState();
}

class _PayslipFormState extends State<_PayslipForm> {
  late _EmployType _type = widget.payslip.type;
  late final Set<_Insurance> _insurances = {...widget.payslip.insurances};
  late final _note = TextEditingController(text: widget.payslip.note ?? '');

  /// 프리랜서는 4대보험 대상이 아니라 고를 수 없다
  bool get _canPickInsurance => _type != _EmployType.freelance;

  /// 고른 조건으로 금액이 어떻게 되는지 미리 계산해 본다
  _Payslip get _preview => _Payslip(
    month: widget.payslip.month,
    sessions: widget.payslip.sessions,
    newSignups: widget.payslip.newSignups,
    reSignups: widget.payslip.reSignups,
    type: _type,
    insurances: _insurances,
    status: widget.payslip.status,
  );

  void _pickType(int index) {
    setState(() {
      _type = _EmployType.values[index];
      if (!_canPickInsurance) _insurances.clear();
    });
  }

  void _toggle(_Insurance insurance) {
    setState(() {
      if (!_insurances.remove(insurance)) _insurances.add(insurance);
    });
  }

  /// 신청서를 그 달 급여에 반영하고 대표 승인 대기로 넘긴다
  void _submit() {
    widget.payslip
      ..type = _type
      ..insurances = {..._insurances}
      ..note = _note.text.trim().isEmpty ? null : _note.text.trim()
      ..status = _PayStatus.pending
      ..submittedAt = DateTime.now()
      ..decidedAt = null
      ..comment = null;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payslip = widget.payslip;
    final preview = _preview;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FormLabel('근무 실적'),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _fact('PT 세션', '${payslip.sessions}회'),
              SizedBox(height: 8),
              _fact('신규 등록', '${payslip.newSignups}건'),
              SizedBox(height: 8),
              _fact('재등록', '${payslip.reSignups}건'),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    size: 13,
                    color: AppColors.gray400,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '수업·근태 기록에서 회사가 집계한 값이라 고칠 수 없어요.',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        _FormLabel('고용 형태'),
        SizedBox(height: 8),
        SegmentedTabs(
          labels: [for (final t in _EmployType.values) t.label],
          selected: _EmployType.values.indexOf(_type),
          onSelect: _pickType,
        ),
        SizedBox(height: 20),
        _FormLabel('가입 보험'),
        SizedBox(height: 8),
        if (_canPickInsurance)
          for (final insurance in _Insurance.values)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _CheckRow(
                label: insurance.label,
                checked: _insurances.contains(insurance),
                onTap: () => _toggle(insurance),
              ),
            )
        else
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '프리랜서는 4대보험 대신 사업소득세 3.3%가 원천징수돼요.',
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
          ),
        SizedBox(height: 20),
        _FormLabel('특이사항 (선택)'),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _note,
            maxLines: 3,
            style: AppTextStyles.body2,
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: '예) 이번 달부터 국민연금 가입했어요',
              hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        SizedBox(height: 20),
        // 제출하면 얼마를 받게 되는지 미리 보여준다
        Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _amountRow('지급', preview.gross),
              SizedBox(height: 6),
              _amountRow('공제', -preview.deduction),
              SizedBox(height: 10),
              Container(
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '실수령액',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    _won(preview.net),
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          '제출하면 대표 승인 후 ${_dayLabel(payslip.payDay)}에 지급돼요.\n'
          '기본급과 수당 단가는 회사가 정하는 값이라 신청서에서 바꿀 수 없어요.',
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        width: dialogWidth(context, 460),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${payslip.month.month}월 급여 신청서', style: AppTextStyles.title3),
            SizedBox(height: 20),
            // 창이 낮으면 폼이 잘리므로 안쪽만 스크롤한다
            Flexible(child: SingleChildScrollView(child: body)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: '취소',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _DialogButton(
                    label: '제출',
                    filled: true,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return PhoneDetailScaffold(
      title: '${payslip.month.month}월 급여 신청서',
      bottomBar: GlassBottomButton(label: '제출하기', onPressed: _submit),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [body],
      ),
    );
  }

  Widget _fact(String label, String value) => Row(
    children: [
      Expanded(child: Text(label, style: AppTextStyles.body2)),
      Text(
        value,
        style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _amountRow(String label, int value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.primary),
        ),
      ),
      Text(
        _won(value),
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    ],
  );
}

class _FormLabel extends StatelessWidget {
  _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.label.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _CheckRow extends StatelessWidget {
  _CheckRow({required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: checked ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 120),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? AppColors.primary : AppColors.gray300,
                  width: 1.4,
                ),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                color: checked ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  _DialogButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.gray100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 제출·승인 상태를 알리는 색 면 (요약 카드 아래)
class _StatusNotice extends StatelessWidget {
  _StatusNotice({
    required this.payslip,
    required this.onSubmit,
    required this.onCancel,
  });

  final _Payslip payslip;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = payslip.status;

    // 승인이 끝난 달은 알릴 게 없다
    if (status == _PayStatus.approved || status == _PayStatus.paid) {
      return SizedBox.shrink();
    }

    final (title, body, action, onAction) = switch (status) {
      _PayStatus.draft => (
        '아직 제출하지 않았어요',
        '신청서를 내면 대표 승인 후 ${_dayLabel(payslip.payDay)}에 지급돼요.',
        '급여 신청서 작성',
        onSubmit,
      ),
      _PayStatus.pending => (
        '${payslip.type.label} · ${payslip.insuranceLabel}로 제출했어요',
        '${_dayLabel(payslip.submittedAt!)} 제출 · 대표 승인을 기다리는 중이에요.',
        '제출 취소',
        onCancel,
      ),
      _ => (
        '신청서가 반려됐어요',
        payslip.comment ?? '내용을 고쳐 다시 제출해 주세요.',
        '다시 작성',
        onSubmit,
      ),
    };

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 7),
              Text(
                status.label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: status.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            body,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12),
          Pressable(
            onTap: onAction,
            scale: 0.97,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status == _PayStatus.pending
                    ? AppColors.surface
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                action,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: status == _PayStatus.pending
                      ? AppColors.textPrimary
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
