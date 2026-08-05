part of 'salary_screen.dart';

/// 급여 신청서 작성 — 폰은 밀려 들어오는 화면, PC는 모달
///
/// 실적과 커미션은 회사가 정한 값이라 확인만 한다.
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
  late final _note = TextEditingController(text: widget.payslip.note ?? '');

  /// 특이사항만 담아 닫는다 — 실제 제출 요청은 부르는 쪽이 보낸다
  void _submit() {
    final note = _note.text.trim();
    widget.payslip.note = note.isEmpty ? null : note;
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

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FormLabel('신청 금액'),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (final item in payslip.pays) ...[
                _amountRow(item),
                SizedBox(height: 8),
              ],
              Container(
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '총 지급액',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    _won(payslip.total),
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(
              CupertinoIcons.info_circle,
              size: 13,
              color: AppColors.gray400,
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                '세션·등록 건수는 수업 기록에서 회사가 집계한 값이라 고칠 수 없어요.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _FormLabel('특이사항 (선택)'),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          // 이 폼은 카드 안이 아니라 화면 배경 위에 바로 놓인다.
          // 라이트에서 gray50 은 배경과 같은 색이라 입력칸이 통째로 묻힌다
          // (`AppColors.track` 주석 참고). 흰 면에 테두리로 칸을 세운다.
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray100),
          ),
          child: TextField(
            controller: _note,
            maxLines: 2,
            style: AppTextStyles.body2,
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: '예) 대타 수업 2회가 빠진 것 같아요',
              hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        SizedBox(height: 14),
        // 실제 입금액이 다르다는 건 나중에 문의로 돌아오는 부분이라 눈에 띄게
        _TaxNotice(
          '위 금액은 세금·보험 공제 전이에요. 4대보험·소득세를 회사에서 따로 뗀 뒤 '
          '대표 승인을 거쳐 ${_dayLabel(payslip.payDay)}에 입금돼요.',
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        width: dialogWidth(context, 400),
        padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${payslip.month.month}월 급여 신청서', style: AppTextStyles.title3),
            SizedBox(height: 16),
            // 창이 낮으면 폼이 잘리므로 안쪽만 스크롤한다
            Flexible(child: SingleChildScrollView(child: body)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '취소',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AppButton(label: '제출', filled: true, onTap: _submit),
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

  Widget _amountRow(_PayItem item) => Row(
    children: [
      // 항목과 근거를 한 덩어리로 — Flexible과 Spacer를 따로 두면
      // 둘이 남는 폭을 나눠 가져 금액 위치가 줄마다 달라진다
      Expanded(
        child: Row(
          children: [
            Text(
              item.label,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
            if (item.note != null) ...[
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      SizedBox(width: 10),
      Text(
        _won(item.amount),
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    ],
  );
}

/// 공제 전 금액이라는 경고 — 실제 입금액과 다른 이유를 짚어 준다
class _TaxNotice extends StatelessWidget {
  _TaxNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 14,
            color: AppColors.error,
          ),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// 급여 신청서 작성·제출 상태 안내
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

    // 승인·지급이 끝난 달도 **이 자리를 비우지 않는다.** 예전에는 통째로
    // 감췄는데, 그러면 요약 카드와 지난 흐름 사이가 뚝 끊겨서 신청 칸이
    // 통째로 사라진 것처럼 보인다. 상태만 알리고 버튼을 안 준다.
    final (title, body, action, onAction) = switch (status) {
      _PayStatus.draft => (
        '아직 제출하지 않았어요',
        '신청서를 내면 대표 승인 후 ${_dayLabel(payslip.payDay)}에 지급돼요.',
        '급여 신청서 작성',
        onSubmit,
      ),
      _PayStatus.pending => (
        '${_won(payslip.total)}으로 제출했어요',
        '${_dayLabel(payslip.submittedAt!)} 제출 · 대표 승인을 기다리는 중이에요.',
        '제출 취소',
        onCancel,
      ),
      _PayStatus.approved => (
        '승인됐어요',
        '${_dayLabel(payslip.payDay)}에 입금될 예정이에요.',
        null,
        null,
      ),
      _PayStatus.paid => (
        '${_won(payslip.total)}이 지급됐어요',
        // 지급 시각은 대표가 이체를 확인하고 찍는다 — 없을 수도 있다
        payslip.paidAt == null
            ? '입금이 끝났어요.'
            : '${_dayLabel(payslip.paidAt!)} 입금 완료.',
        null,
        null,
      ),
      _ => (
        '신청서가 반려됐어요',
        payslip.comment ?? '내용을 확인하고 다시 제출해 주세요.',
        '다시 작성',
        onSubmit,
      ),
    };

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        // 옆 지급 카드와 같은 네모로 보이게 모서리를 맞춘다
        borderRadius: BorderRadius.circular(24),
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
          // 데스크톱은 옆 카드와 높이를 맞추느라 남는 공간이 생긴다.
          // 버튼을 아래로 밀어 붙여 빈자리가 위쪽 설명 아래로 모이게 한다
          if (isDesktop) Spacer() else SizedBox(height: 12),
          if (isDesktop) SizedBox(height: 12),
          // 승인·지급이 끝나면 누를 것이 없다 — 버튼 자리를 아예 안 만든다
          // (막힌 버튼을 남겨 두면 눌러 보고 안 되는 이유를 찾게 된다)
          if (action != null && onAction != null)
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
