part of 'auth_screen.dart';

/// 회원가입 결과 — 로그인 화면이 안내 문구를 고르는 데 쓴다
class _SignupOutcome {
  _SignupOutcome(this.email, this.result);

  final String email;
  final SignupResult result;
}

/// 회원가입
///
/// 초대키가 있으면 바로 가입되고, 없으면 관리자 승인 대기로 넘어간다.
/// 닫힐 때 가입한 이메일과 결과를 돌려주므로 로그인 화면이 이메일을
/// 채워 두고 결과에 맞는 안내를 띄운다.
class _SignupScreen extends StatefulWidget {
  _SignupScreen();

  @override
  State<_SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<_SignupScreen> {
  final _invite = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  final _errors = <String, String?>{};

  /// 약관 동의 — 둘 다 필수라 하나라도 빠지면 가입이 막힌다
  final _agreed = {LegalDocument.terms: false, LegalDocument.privacy: false};
  bool _agreeError = false;

  @override
  void dispose() {
    _invite.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invite = _invite.text.trim();
    final name = _name.text.trim();
    final email = _email.text.trim();

    final errors = <String, String?>{
      // 초대키는 선택 — 없으면 서버가 승인 대기(PENDING)로 받아 준다
      'invite': invite.isNotEmpty && invite.replaceAll('-', '').length < 8
          ? '초대키를 다시 확인해 주세요.'
          : null,
      'name': name.isEmpty
          ? '이름을 입력해 주세요.'
          : name.length < 2
          ? '이름을 두 글자 이상 입력해 주세요.'
          : null,
      'email': _checkEmail(email),
      'phone': _checkPhone(_phone.text),
      'password': _checkPassword(_password.text),
      'confirm': _confirm.text.isEmpty
          ? '비밀번호를 한 번 더 입력해 주세요.'
          : _confirm.text != _password.text
          ? '비밀번호가 서로 달라요.'
          : null,
    };

    final agreeMissing = _agreed.values.any((v) => !v);

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _agreeError = agreeMissing;
    });
    if (errors.values.any((e) => e != null) || agreeMissing) return;

    setState(() => _busy = true);
    try {
      final result = await AuthApi.signup(
        name: name,
        email: email,
        password: _password.text,
        phone: _phone.text,
        inviteKey: invite,
      );
      if (!mounted) return;
      Navigator.pop(context, _SignupOutcome(email, result));
    } catch (error) {
      if (!mounted) return;
      // 이메일 중복·초대키 만료 등 서버가 알려준 이유를 해당 칸에 붙인다
      final message = messageOf(error);
      setState(() {
        _busy = false;
        _errors['invite'] = message.contains('초대키') ? message : null;
        _errors['email'] = message.contains('초대키') ? null : message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '회원가입',
      caption: '초대키가 있으면 바로 가입돼요.',
      onBack: () => Navigator.pop(context),
      // 짝지은 칸을 나란히 두려면 폭이 있어야 한다 (폰은 이 값을 안 쓴다)
      width: 560,
      children: [
        _AuthField(
          controller: _invite,
          label: '초대키 (선택)',
          hint: 'HIFIS-4F2A-91K7',
          autofocus: !isDesktop,
          textInputAction: TextInputAction.next,
          formatters: [_UpperCaseFormatter()],
          error: _errors['invite'],
        ),
        SizedBox(height: 7),
        Text(
          '관리자에게 받은 초대키를 그대로 입력해 주세요.\n초대키가 없으면 가입 신청 후 관리자 승인을 기다리게 돼요.',
          style: AppTextStyles.caption,
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _name,
          label: '이름',
          hint: '홍길동',
          textInputAction: TextInputAction.next,
          error: _errors['name'],
        ),
        SizedBox(height: 16),
        // 폰에서 위아래로 쌓여도 입력 순서가 그대로이도록 짝을 지었다
        _FieldPair(
          left: _AuthField(
            controller: _email,
            label: '업무용 이메일',
            hint: 'name@hifis.app',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            error: _errors['email'],
          ),
          right: _AuthField(
            controller: _phone,
            label: '전화번호',
            hint: '010-1234-5678',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            formatters: [_PhoneFormatter()],
            error: _errors['phone'],
          ),
        ),
        SizedBox(height: 16),
        _FieldPair(
          left: _AuthField(
            controller: _password,
            label: '비밀번호',
            hint: '8자 이상, 영문·숫자 포함',
            obscure: true,
            textInputAction: TextInputAction.next,
            error: _errors['password'],
          ),
          right: _AuthField(
            controller: _confirm,
            label: '비밀번호 확인',
            hint: '비밀번호 다시 입력',
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            error: _errors['confirm'],
          ),
        ),
        SizedBox(height: 24),
        for (final document in LegalDocument.values) ...[
          _AgreeRow(
            document: document,
            value: _agreed[document]!,
            onChanged: (v) => setState(() {
              _agreed[document] = v;
              if (!_agreed.values.any((e) => !e)) _agreeError = false;
            }),
          ),
          if (document != LegalDocument.values.last) SizedBox(height: 6),
        ],
        if (_agreeError) ...[
          SizedBox(height: 7),
          Text(
            '필수 항목에 모두 동의해 주세요.',
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
        SizedBox(height: 24),
        _AuthButton(label: '가입하기', onTap: _submit, busy: _busy),
      ],
    );
  }
}

/// 초대키는 대문자로만 받는다
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => TextEditingValue(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
  );
}
