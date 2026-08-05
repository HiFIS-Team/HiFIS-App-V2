part of 'approval_screen.dart';

// ── 공통 조각 ──

/// 날짜 고르는 칸 — 입력칸([_Field])과 같은 면·높이로 맞춘다
class _DateField extends StatelessWidget {
  _DateField({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${value.year}. ${value.month}. ${value.day}.',
                style: AppTextStyles.body2,
              ),
            ),
            Icon(
              CupertinoIcons.calendar,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 폼 입력칸
class _Field extends StatelessWidget {
  _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.lines = 1,
    this.align = TextAlign.start,
    this.suffix,
    this.digitsOnly = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final TextAlign align;
  final String? suffix;

  /// 금액처럼 숫자만 받고 천 단위로 끊어 보여줄지
  final bool digitsOnly;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.body2,
              textAlign: align,
              cursorColor: AppColors.primary,
              minLines: lines,
              maxLines: lines,
              keyboardType: digitsOnly
                  ? TextInputType.number
                  : (lines > 1 ? TextInputType.multiline : null),
              inputFormatters: digitsOnly ? [_ThousandsFormatter()] : null,
              textInputAction: lines > 1
                  ? TextInputAction.newline
                  : TextInputAction.done,
              onSubmitted: (_) => onSubmitted?.call(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (suffix != null) ...[
            SizedBox(width: 8),
            Text(
              suffix!,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 숫자만 받아 천 단위로 끊어 보여준다
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final text = _comma(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
