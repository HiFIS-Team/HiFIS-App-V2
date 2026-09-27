part of 'salary_screen.dart';

/// 급여 신청서 작성 — 폰은 밀려 들어오는 화면, PC는 모달
///
/// **금액마다 왜 그 금액인지를 같이 보여준다** (2026-09-27 대표 요청).
/// 서버가 계산한 값을 그대로 채워 두고, 기본급·커미션 카드마다 근거(수업 건수·
/// 회당 금액 합·요율·수업 목록)를 붙인다. 커미션은 본인이 고칠 수 있는데,
/// **고치면 그 카드에 사유 칸이 열리고 비우면 제출이 안 된다.** 서버도 막는다.
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

/// 커미션 한 줄의 입력 상태 — 금액 칸과 사유 칸
class _CommissionInput {
  _CommissionInput(this.auto)
    : amount = TextEditingController(text: _amount(auto));

  /// 서버가 계산한 값 — 되돌리기의 목적지이자 비교 기준
  final int auto;
  final TextEditingController amount;
  final reason = TextEditingController();

  int get value =>
      int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  bool get changed => value != auto;

  /// 바꿨는데 사유가 비었나 — 이러면 제출을 막는다
  bool get missingReason => changed && reason.text.trim().isEmpty;

  void reset() {
    amount.text = _amount(auto);
    reason.clear();
  }

  void dispose() {
    amount.dispose();
    reason.dispose();
  }
}

class _PayslipFormState extends State<_PayslipForm> {
  late final _note = TextEditingController(text: widget.payslip.note ?? '');
  late final _new = _CommissionInput(widget.payslip.autoNew);
  late final _renewal = _CommissionInput(widget.payslip.autoRenewal);

  /// 서버가 `canAdjust` 로 열어 준 사람만 커미션을 고친다 (알바·FC 는 제외)
  bool get _canAdjust => widget.payslip.canAdjust;

  int get _newValue => _canAdjust ? _new.value : _new.auto;
  int get _renewalValue => _canAdjust ? _renewal.value : _renewal.auto;

  int get _autoTotal => widget.payslip.formBase + _new.auto + _renewal.auto;

  /// 기본급 + 커미션 — 입력하는 동안 바로 따라 움직인다
  int get _total => widget.payslip.formBase + _newValue + _renewalValue;

  bool get _blocked =>
      _canAdjust && (_new.missingReason || _renewal.missingReason);

  void _submit() {
    if (_blocked) {
      AppToast.show(context, '금액을 바꾼 이유를 적어 주세요');
      return;
    }
    final payslip = widget.payslip;
    final note = _note.text.trim();
    payslip.note = note.isEmpty ? null : note;
    // 안 고쳤으면 아예 안 보낸다 — 서버 계산값 그대로 쓰라는 뜻이다
    final newChanged = _canAdjust && _new.changed;
    final renewalChanged = _canAdjust && _renewal.changed;
    payslip.adjustNew = newChanged ? _new.value : null;
    payslip.adjustRenewal = renewalChanged ? _renewal.value : null;
    payslip.adjustNewReason = newChanged ? _new.reason.text.trim() : null;
    payslip.adjustRenewalReason = renewalChanged
        ? _renewal.reason.text.trim()
        : null;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _note.dispose();
    _new.dispose();
    _renewal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payslip = widget.payslip;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TotalCard(
          total: _total,
          diff: _total - _autoTotal,
          period: _periodLabel(payslip),
          payDay: payslip.payDay,
        ),
        const SizedBox(height: 20),
        _FormLabel('지급 항목'),
        const SizedBox(height: 10),
        _BaseCard(payslip: payslip),
        const SizedBox(height: 12),
        _CommissionCard(
          title: 'PT 커미션 · 신규',
          auto: _new.auto,
          input: _canAdjust ? _new : null,
          items: payslip.newSaleItems,
          rate: payslip.newRate,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _CommissionCard(
          title: 'PT 커미션 · 재등록',
          auto: _renewal.auto,
          input: _canAdjust ? _renewal : null,
          items: payslip.renewalSaleItems,
          rate: payslip.renewalRate,
          // 재등록 합이 기준액 이하라 신규 요율로 내려갔으면 이유를 적는다
          notice: payslip.downgraded
              ? payslip.renewalThreshold > 0
                    ? '재등록·소개 합이 ${_won(payslip.renewalThreshold)} 이하라 '
                          '신규와 같은 요율이 적용됐어요'
                    : '재등록·소개 합이 기준액 이하라 신규와 같은 요율이 적용됐어요'
              : null,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        _Hint(
          _canAdjust
              ? '수업 기록에서 회사가 계산한 금액이에요. 빠진 수업이 있으면 '
                    '커미션을 고치고 이유를 적어 주세요.'
              : '수업 기록에서 회사가 계산한 금액이라 고칠 수 없어요.',
        ),
        const SizedBox(height: 22),
        _FormLabel('특이사항 (선택)'),
        const SizedBox(height: 10),
        _TextBox(controller: _note, hint: '대표님께 따로 전할 말이 있으면 적어 주세요', lines: 3),
        const SizedBox(height: 16),
        // 실제 입금액이 다르다는 건 나중에 문의로 돌아오는 부분이라 눈에 띄게
        _TaxNotice(
          '위 금액은 세금·보험 공제 전이에요. 4대보험·소득세를 회사에서 따로 뗀 뒤 '
          '대표 승인을 거쳐 ${_dayLabel(payslip.payDay)}에 입금돼요.',
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        width: dialogWidth(context, 440),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${payslip.month.month}월 급여 신청서', style: AppTextStyles.title3),
            const SizedBox(height: 16),
            // 창이 낮으면 폼이 잘리므로 안쪽만 스크롤한다
            Flexible(child: SingleChildScrollView(child: body)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '취소',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: '제출',
                    filled: !_blocked,
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
      bottomBar: GlassBottomButton(
        label: '제출하기',
        active: !_blocked,
        onPressed: _submit,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          GlassBottomButton.inset(context),
        ),
        children: [body],
      ),
    );
  }

  /// `8.27 ~ 9.26` — 끝은 안 포함이라 하루 당긴다. 모르면 null
  static String? _periodLabel(_Payslip payslip) {
    final start = payslip.periodStart;
    final end = payslip.periodEnd;
    if (start == null || end == null) return null;
    final last = end.subtract(const Duration(days: 1));
    return '${start.month}.${start.day} ~ ${last.month}.${last.day}';
  }
}

/// 맨 위 — 총 지급액 · 근무 기간 · 지급일
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.diff,
    required this.period,
    required this.payDay,
  });

  final int total;

  /// 자동 계산과의 차이 — 0 이면 안 그린다
  final int diff;
  final String? period;
  final DateTime payDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '총 지급액 (공제 전)',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _won(total),
            style: AppTextStyles.title1.copyWith(
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (diff != 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '자동 계산보다 ${diff > 0 ? '+' : '−'}${_won(diff.abs())}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (period != null) ...[
                _meta('근무 기간', period!),
                const SizedBox(width: 20),
              ],
              _meta('지급일', _dayLabel(payDay)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppTextStyles.body2.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// 기본급 — 고칠 수 없다. 업무 누락으로 깎였으면 그 이유를 적는다
class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    final cut = payslip.baseBefore - payslip.formBase;
    return _Card(
      children: [
        Row(
          children: [
            Expanded(child: Text('기본급', style: _strong)),
            Text(_won(payslip.formBase), style: _strong),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(CupertinoIcons.lock_fill, size: 12, color: AppColors.gray400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '직급 기본급이라 고칠 수 없어요',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        if (cut > 0 && payslip.taskMissDays > 0) ...[
          const SizedBox(height: 10),
          _Formula(
            '원래 ${_won(payslip.baseBefore)} − 개인 업무 누락 '
            '${payslip.taskMissDays}일 ${_won(cut)}',
          ),
        ],
      ],
    );
  }
}

/// PT 커미션 한 줄 — 금액 · 근거 · 수업 목록 · (고쳤으면) 되돌리기와 사유
///
/// **신청서와 대표 결재 화면이 같이 쓴다** (2026-09-27). [input] 이 있으면
/// 신청서라 금액을 고치고, 없으면 읽기 전용이라 [submitted]·[reason] 을 보여준다.
class _CommissionCard extends StatefulWidget {
  const _CommissionCard({
    required this.title,
    required this.auto,
    required this.items,
    required this.rate,
    this.input,
    this.submitted,
    this.reason,
    this.onChanged,
    this.notice,
  });

  final String title;

  /// 서버가 계산한 값
  final int auto;

  /// 신청서의 입력 상태 — null 이면 읽기 전용
  final _CommissionInput? input;

  /// 읽기 전용일 때 — 신청한 금액과 고친 이유
  final int? submitted;
  final String? reason;
  final List<SaleItem> items;

  /// 적용된 요율 — 모르면 근거식 대신 건수만 적는다
  final double? rate;

  /// 요율이 내려간 이유 같은 한 줄
  final String? notice;
  final VoidCallback? onChanged;

  @override
  State<_CommissionCard> createState() => _CommissionCardState();
}

class _CommissionCardState extends State<_CommissionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final input = widget.input;
    final items = widget.items;
    final base = items.fold<int>(0, (sum, item) => sum + item.amount);
    final rate = widget.rate;
    final auto = widget.auto;
    final changed = input?.changed ?? false;
    // 읽기 전용 — 신청 금액이 계산값과 다르면 고쳐서 낸 것이다
    final submitted = widget.submitted;
    final adjusted = input == null && submitted != null && submitted != auto;

    return _Card(
      highlighted: changed || adjusted,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title, style: _strong)),
            if (input != null)
              _AmountField(
                controller: input.amount,
                onChanged: widget.onChanged ?? () {},
              )
            else
              Text(_won(submitted ?? auto), style: _strong),
          ],
        ),
        const SizedBox(height: 10),
        // 근거식 — 수업 N회 · 회당 금액 합 × 요율
        _Formula(
          items.isEmpty
              ? '이번 기간 해당 수업이 없어요'
              : rate == null
              ? '수업 ${items.length}회 · 회당 금액 합 ${_won(base)}'
              : '수업 ${items.length}회 · 회당 금액 합 ${_won(base)} '
                    '× ${(rate * 100).round()}% = ${_won(auto)}',
        ),
        if (widget.notice case final notice?) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 12,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  notice,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Pressable(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Text(
                  _open ? '수업 목록 접기' : '수업 ${items.length}건 보기',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Icon(
                  _open
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 12,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.memberName}  ·  ${item.pkg}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      _won(item.amount),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
        // 대표 화면 — 고쳐서 낸 것이면 원래 값과 사유
        if (adjusted) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.gray100),
          const SizedBox(height: 12),
          Text(
            '자동 계산 ${_won(auto)}',
            style: AppTextStyles.caption.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '바꾼 이유 · ${(widget.reason ?? '').isEmpty ? '적지 않았어요' : widget.reason}',
            style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary),
          ),
        ],
        // 신청서 — 고쳤으면 원래 값 · 되돌리기 · 사유(필수)
        if (input != null && changed) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.gray100),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '자동 계산 ${_won(auto)}',
                  style: AppTextStyles.caption.copyWith(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              Pressable(
                onTap: () {
                  input.reset();
                  widget.onChanged?.call();
                },
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '되돌리기',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '바꾼 이유 (필수)',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: input.missingReason
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _TextBox(
            controller: input.reason,
            hint: '예) 9/14 대타 수업 2회가 빠졌어요',
            lines: 2,
            error: input.missingReason,
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}

/// 흰 카드 — 고친 카드는 테두리로 표시한다
class _Card extends StatelessWidget {
  const _Card({required this.children, this.highlighted = false});

  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.gray100,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 근거식 한 줄 — 회색 면 위 작은 글자
class _Formula extends StatelessWidget {
  const _Formula(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 안내 한 줄 — 아이콘 + 작은 글자
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            CupertinoIcons.info_circle,
            size: 13,
            color: AppColors.gray400,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// 여러 줄 입력칸 — 흰 면에 테두리 (사유칸은 비었으면 빨간 테두리)
class _TextBox extends StatelessWidget {
  const _TextBox({
    required this.controller,
    required this.hint,
    this.lines = 2,
    this.error = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int lines;
  final bool error;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.gray100,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: lines,
        minLines: lines,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        style: AppTextStyles.body2,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 커미션 금액 입력칸 — 오른쪽 정렬 + 뒤에 '원'
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final style = _strong.copyWith(
      color: AppColors.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: style,
            cursorColor: AppColors.primary,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: '0',
              hintStyle: style.copyWith(color: AppColors.gray400),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('원', style: style),
      ],
    );
  }
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

/// 카드 제목·금액 글자 — 본문 굵게
TextStyle get _strong =>
    AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700);
