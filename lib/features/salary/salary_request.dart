part of 'salary_screen.dart';

/// 급여 조건 카드
///
/// 회사가 정한 값(기본급·단가)과 본인이 신고한 값(고용 형태·보험)을
/// 나눠서 보여준다. 바꾸려면 신청하고 대표 승인을 받아야 한다.
class _ConditionCard extends StatelessWidget {
  _ConditionCard({
    required this.onRequest,
    required this.onCancel,
    required this.onHistory,
  });

  final VoidCallback onRequest;
  final ValueChanged<_PayRequest> onCancel;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final applied = _appliedRequest;
    final pending = _pendingRequest;
    final rejected =
        _requests.isNotEmpty &&
            _requests.first.status == _RequestStatus.rejected
        ? _requests.first
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('급여 조건', style: AppTextStyles.label)),
              Pressable(
                onTap: onHistory,
                scale: 0.94,
                child: Row(
                  children: [
                    Text(
                      '신청 내역',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          _row(
            '회사 지정',
            '기본급 ${_won(_companyBase.base)} · 세션 ${_won(_companyBase.sessionRate)}',
          ),
          SizedBox(height: 10),
          _row('내 신고', '${applied.type.label} · ${applied.insuranceLabel}'),
          SizedBox(height: 10),
          _row('적용', '${_monthLabel(applied.effectiveFrom)}부터'),

          // 대표 승인을 기다리는 중이면 무엇을 신청했는지 같이 보여준다
          if (pending != null) ...[
            SizedBox(height: 16),
            _Notice(
              status: _RequestStatus.pending,
              title:
                  '${pending.type.label} · ${pending.insuranceLabel}로 변경 신청했어요',
              body:
                  '${_dayLabel(pending.requestedAt)} 신청 · 대표 승인을 기다리는 중이에요.\\n'
                  '승인되면 ${_monthLabel(pending.effectiveFrom)} 급여부터 적용돼요.',
              action: '신청 취소',
              onAction: () => onCancel(pending),
            ),
          ] else if (rejected != null) ...[
            SizedBox(height: 16),
            _Notice(
              status: _RequestStatus.rejected,
              title: '지난 신청이 반려됐어요',
              body: rejected.comment ?? '',
              action: '다시 신청',
              onAction: onRequest,
            ),
          ] else ...[
            SizedBox(height: 18),
            Pressable(
              onTap: onRequest,
              scale: 0.98,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '조건 변경 신청',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 66, child: Text(label, style: AppTextStyles.caption)),
      Expanded(
        child: Text(
          value,
          style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}

/// 승인 대기·반려를 알리는 색 면
class _Notice extends StatelessWidget {
  _Notice({
    required this.status,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final _RequestStatus status;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
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
          if (body.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              body,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          SizedBox(height: 12),
          Pressable(
            onTap: onAction,
            scale: 0.96,
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  action,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 신청 폼
// ---------------------------------------------------------------------------

/// 조건 변경 신청 — 폰은 밀려 들어오는 화면, PC는 모달
Future<_PayRequest?> _showRequestComposer(BuildContext context) {
  if (isDesktop) {
    return showAppDialog<_PayRequest>(context, (_) => _RequestComposer());
  }
  return Navigator.push<_PayRequest>(
    context,
    CupertinoPageRoute(builder: (_) => _RequestComposer()),
  );
}

class _RequestComposer extends StatefulWidget {
  _RequestComposer();

  @override
  State<_RequestComposer> createState() => _RequestComposerState();
}

class _RequestComposerState extends State<_RequestComposer> {
  late _EmployType _type = _appliedRequest.type;
  late final Set<_Insurance> _insurances = {..._appliedRequest.insurances};
  final _reason = TextEditingController();

  /// 다음 달부터 적용 (신청 후 정산이 끝난 달은 못 바꾼다)
  late final DateTime _from = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
  );

  /// 프리랜서는 4대보험 대상이 아니라 고를 수 없다
  bool get _canPickInsurance => _type != _EmployType.freelance;

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

  void _submit() {
    Navigator.pop(
      context,
      _PayRequest(
        requestedAt: DateTime.now(),
        type: _type,
        insurances: {..._insurances},
        effectiveFrom: _from,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('고용 형태', style: AppTextStyles.label),
        SizedBox(height: 8),
        SegmentedTabs(
          labels: [for (final t in _EmployType.values) t.label],
          selected: _EmployType.values.indexOf(_type),
          onSelect: _pickType,
        ),
        SizedBox(height: 20),
        Text('가입 보험', style: AppTextStyles.label),
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
        Text('사유 (선택)', style: AppTextStyles.label),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _reason,
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
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '대표가 승인하면 ${_monthLabel(_from)} 급여부터 적용돼요.\n'
            '기본급과 세션 단가는 회사가 정하는 값이라 여기서 바꿀 수 없어요.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              height: 1.5,
            ),
          ),
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
            Text('급여 조건 변경 신청', style: AppTextStyles.title3),
            SizedBox(height: 20),
            body,
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
                    label: '신청',
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
      title: '급여 조건 신청',
      bottomBar: GlassBottomButton(label: '신청하기', onPressed: _submit),
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

// ---------------------------------------------------------------------------
// 신청 내역
// ---------------------------------------------------------------------------

class _RequestHistoryScreen extends StatelessWidget {
  _RequestHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '급여 조건 신청 내역',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          if (_requests.isEmpty)
            EmptyCard(icon: CupertinoIcons.doc_text, text: '신청한 내역이 없어요')
          else
            for (final request in _requests)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _RequestCard(request: request),
              ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  _RequestCard({required this.request});

  final _PayRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.type.label} · ${request.insuranceLabel}',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: request.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: request.status.color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '${_dayLabel(request.requestedAt)} 신청 · '
            '${_monthLabel(request.effectiveFrom)}부터 적용',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          if (request.reason != null) ...[
            SizedBox(height: 10),
            Text(
              request.reason!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (request.comment != null) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '대표 의견',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    request.comment!,
                    style: AppTextStyles.caption.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
