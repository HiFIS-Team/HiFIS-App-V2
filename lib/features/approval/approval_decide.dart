part of 'approval_screen.dart';

// ── 승인·반려 ──

/// 승인·반려 의견 받기 (취소면 null)
///
/// **폰은 옆에서 밀려 들어오는 페이지**로 연다 — 창이 폭 400 고정이라
/// 폰(375)에서는 좌우 여백 없이 화면에 꽉 찼다.
/// PC 는 창 그대로지만 폭을 [dialogWidth] 로 재서 좁은 창에서도 넘치지 않는다.
Future<String?> _showDecisionDialog(
  BuildContext context, {
  required _Doc doc,
  required bool approve,
}) {
  if (!isDesktop) {
    return Navigator.push<String>(
      context,
      CupertinoPageRoute(
        builder: (_) => _DecisionDialog(doc: doc, approve: approve),
      ),
    );
  }
  return showAppDialog<String>(
    context,
    (context) => _DecisionDialog(doc: doc, approve: approve),
  );
}

class _DecisionDialog extends StatefulWidget {
  _DecisionDialog({required this.doc, required this.approve});

  final _Doc doc;
  final bool approve;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _comment = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
    // 폰은 페이지가 밀려 들어오는 중에 키보드가 같이 올라오면 어수선하다
    if (isDesktop) _focus.requestFocus();
  }

  @override
  void dispose() {
    _comment.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      AppToast.show(
        context,
        widget.approve ? '승인 의견을 입력해주세요' : '반려 사유를 입력해주세요',
      );
      _focus.requestFocus();
      return;
    }
    Navigator.pop(context, comment);
  }

  /// 창 제목 · 폰 페이지 제목 — 같은 말을 쓴다
  String get _heading => widget.approve ? '결재 승인' : '결재 반려';

  /// 안내 · 문서 요약 · 의견칸 — 창이든 페이지든 같은 것이 선다
  Widget _body() {
    final approve = widget.approve;
    final doc = widget.doc;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          approve ? '다음 결재자에게 넘어갑니다' : '반려하면 이 결재는 여기서 끝납니다',
          style: AppTextStyles.caption,
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(doc.kind.icon, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    doc.kind.label,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                  if (doc.amount > 0) ...[
                    Spacer(),
                    Text(
                      _won(doc.amount),
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 4),
              Text(
                doc.title,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${doc.writer} 신청',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _Field(
          controller: _comment,
          focusNode: _focus,
          hint: approve ? '승인 의견을 적어주세요' : '반려 사유를 적어주세요',
          lines: 3,
        ),
      ],
    );
  }

  /// 창 아래 버튼 줄 (PC 전용 — 폰은 하단 글래스 버튼을 쓴다)
  Widget _footer() {
    final approve = widget.approve;
    final empty = _comment.text.trim().isEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Pressable(
          onTap: () => Navigator.pop(context),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            '취소',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 8),
        Pressable(
          onTap: _submit,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: empty
                  ? AppColors.gray200
                  : (approve ? AppColors.primary : AppColors.error),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              approve ? '승인' : '반려',
              style: AppTextStyles.body2.copyWith(
                color: empty ? AppColors.gray500 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 폰은 옆에서 밀려 들어온 페이지 — 제목은 껍데기가 그리고,
    // 처리 버튼은 하단 탭바 자리의 글래스 버튼이 받는다 (일정 폼과 같은 틀)
    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: _heading,
        bottomBar: GlassBottomButton(
          label: widget.approve ? '승인' : '반려',
          // 의견을 적어야 채워진 상태가 되고, 안 적었을 때는 _submit 이 안내한다
          active: _comment.text.trim().isNotEmpty,
          onPressed: _submit,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            GlassBottomButton.inset(context),
          ),
          children: [
            // 입력칸(gray50)이 회색 배경에 묻히지 않게 흰 카드 위에 올린다
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: AppDecorations.card(),
              child: _body(),
            ),
          ],
        ),
      );
    }

    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_heading, style: AppTextStyles.title2),
          SizedBox(height: 6),
          _body(),
          SizedBox(height: 18),
          _footer(),
        ],
      ),
    );
  }
}
