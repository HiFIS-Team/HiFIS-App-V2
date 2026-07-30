part of 'auth_screen.dart';

// ---------------------------------------------------------------------------
// 화면 틀
// ---------------------------------------------------------------------------

/// 로그인 계열 화면의 공통 틀
///
/// 폰은 흰 바탕 한 장을 그대로 쓰고, 데스크톱은 회색 바탕 가운데에
/// 카드 하나를 띄운다. 입력 칸이 회색(gray50)이라 바탕이 흰색이어야
/// 칸이 보인다 — 폰 배경을 background로 두면 칸이 사라진다.
class _AuthScaffold extends StatelessWidget {
  _AuthScaffold({
    required this.children,
    this.title,
    this.caption,
    this.onBack,
  });

  final List<Widget> children;
  final String? title;
  final String? caption;
  final VoidCallback? onBack;

  /// 데스크톱 카드 폭
  static const double cardWidth = 420;

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (onBack != null) ...[
        Pressable(
          onTap: onBack!,
          scale: 0.9,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 10),
      ],
      Text(title!, style: AppTextStyles.title1),
      if (caption != null) ...[
        SizedBox(height: 8),
        Text(
          caption!,
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
      ],
      SizedBox(height: 28),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[if (title != null) _header(), ...children];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: Container(
                padding: EdgeInsets.fromLTRB(36, 32, 36, 36),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 12, 24, 40),
          children: content,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 입력
// ---------------------------------------------------------------------------

/// 로그인 계열 입력 칸 — 라벨 + 회색 상자 + (틀렸을 때) 빨간 안내
class _AuthField extends StatefulWidget {
  _AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.formatters,
    this.error,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.center = false,
    this.letterSpacing,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  /// 비밀번호 칸 — 눈 버튼으로 잠깐 볼 수 있다
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  /// 검증에 걸린 이유 (없으면 안 그린다)
  final String? error;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  /// 인증번호처럼 가운데 정렬로 크게 보여줄 때
  final bool center;
  final double? letterSpacing;
  final int? maxLength;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _focused = false;
  late bool _hidden = widget.obscure;

  void _onFocus() {
    if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (widget.error != null) return AppColors.error;
    if (_focused) return AppColors.primary;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: Duration(milliseconds: 120),
      height: 54,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1.4),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.formatters,
              maxLength: widget.maxLength,
              textInputAction: widget.textInputAction,
              onSubmitted: (_) => widget.onSubmitted?.call(),
              textAlign: widget.center ? TextAlign.center : TextAlign.start,
              cursorColor: AppColors.primary,
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: widget.letterSpacing,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray400,
                  letterSpacing: widget.letterSpacing,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                counterText: '',
              ),
            ),
          ),
          if (widget.obscure)
            Pressable(
              onTap: () => setState(() => _hidden = !_hidden),
              scale: 0.9,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  _hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: AppColors.gray400,
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        box,
        if (widget.error != null) ...[
          SizedBox(height: 7),
          Text(
            widget.error!,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// 전화번호를 010-1234-5678 꼴로 맞춰 준다
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      // 3자리·7자리 뒤에 하이픈 (010-1234-5678)
      if (i == 3 || i == 7) buffer.write('-');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------------------------------------------------------------------------
// 버튼 · 체크
// ---------------------------------------------------------------------------

/// 화면 아래 큰 버튼 — 디자인 시스템 기본(높이 56, radius 14)
class _AuthButton extends StatelessWidget {
  _AuthButton({required this.label, required this.onTap, this.busy = false});

  final String label;
  final VoidCallback onTap;

  /// 처리 중 — 두 번 눌리지 않게 막고 스피너를 보여준다
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? () {} : onTap,
      scale: 0.98,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: busy
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                label,
                style: AppTextStyles.body1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// 글자만 있는 보조 버튼 (회원가입 · 비밀번호 찾기 등)
class _AuthTextButton extends StatelessWidget {
  _AuthTextButton({
    required this.label,
    required this.onTap,
    this.strong = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: strong ? AppColors.primary : AppColors.textSecondary,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 자동 로그인 체크
class _AuthCheck extends StatelessWidget {
  _AuthCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      scale: 0.97,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 120),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.primary : AppColors.gray300,
                width: 1.4,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 검증
// ---------------------------------------------------------------------------

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// 이메일 형식 확인 — 틀린 이유를 돌려준다 (맞으면 null)
String? _checkEmail(String value) {
  if (value.isEmpty) return '이메일을 입력해 주세요.';
  if (!_emailPattern.hasMatch(value)) return '이메일 형식이 올바르지 않아요.';
  return null;
}

String? _checkPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '전화번호를 입력해 주세요.';
  if (digits.length != 11 || !digits.startsWith('01')) {
    return '휴대폰 번호 11자리를 입력해 주세요.';
  }
  return null;
}

/// 8자 이상 + 영문·숫자 섞기
String? _checkPassword(String value) {
  if (value.isEmpty) return '비밀번호를 입력해 주세요.';
  if (value.length < 8) return '8자 이상으로 만들어 주세요.';
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
  final hasDigit = RegExp(r'\d').hasMatch(value);
  if (!hasLetter || !hasDigit) return '영문과 숫자를 함께 넣어 주세요.';
  return null;
}

/// 서버를 기다리는 척하는 시간 — 실제 연동 때 API 호출로 바꾼다
Future<void> _fakeDelay() => Future.delayed(Duration(milliseconds: 600));
