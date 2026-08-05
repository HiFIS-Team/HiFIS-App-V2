part of 'profile_screen.dart';

// ---------------------------------------------------------------------------
// 공용 소품
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  _InputBox({
    this.controller,
    this.value,
    this.hint,
    this.enabled = true,
    this.obscure = false,
    this.helper,
    this.keyboardType,
  });

  /// 고칠 수 있는 칸은 컨트롤러를 받는다.
  /// 예전에는 `initialValue` 만 넘겼는데 그러면 **적은 값을 꺼낼 수가 없다**
  final TextEditingController? controller;

  /// 읽기 전용 칸에 보여줄 값
  final String? value;

  final String? hint;
  final bool enabled;
  final bool obscure;
  final String? helper;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: enabled
              ? TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: AppTextStyles.body2,
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.body2.copyWith(
                      color: AppColors.gray400,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                )
              : Text(
                  value ?? '',
                  style: AppTextStyles.body2.copyWith(color: AppColors.gray400),
                ),
        ),
        if (helper != null) ...[
          SizedBox(height: 8),
          Text(helper!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _SmallPrimaryButton extends StatelessWidget {
  _SmallPrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;

  /// 서버에 보내는 중 — 연타로 두 번 저장되지 않게 막는다
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? () {} : onTap,
      scale: 0.94,
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: busy ? AppColors.gray300 : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          widthFactor: 1,
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 서버는 아바타 색을 `#RRGGBB` 로 받는다
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
