part of 'approval_screen.dart';

// ── 승인·반려 ──

/// 승인·반려 의견 받기 (취소면 null)
Future<String?> _showDecisionDialog(
  BuildContext context, {
  required _Doc doc,
  required bool approve,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _DecisionDialog(doc: doc, approve: approve),
      ),
    ),
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
    _focus.requestFocus();
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

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final doc = widget.doc;
    final empty = _comment.text.trim().isEmpty;

    return Container(
      width: 400,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(approve ? '결재 승인' : '결재 반려', style: AppTextStyles.title2),
          SizedBox(height: 6),
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
                    Icon(
                      doc.kind.icon,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
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
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Pressable(
                onTap: () => Navigator.pop(context),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
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
                scale: 0.97,
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
          ),
        ],
      ),
    );
  }
}
