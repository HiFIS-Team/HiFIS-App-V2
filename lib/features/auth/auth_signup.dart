part of 'auth_screen.dart';

/// 회원가입 — 초대키를 받은 직원만 가입할 수 있다
///
/// 성공하면 가입한 이메일을 돌려주며 닫힌다. 로그인 화면이 그 이메일을
/// 채워 두기 때문에 바로 로그인할 수 있다.
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
      'invite': invite.isEmpty
          ? '초대키를 입력해 주세요.'
          : invite.replaceAll('-', '').length < 8
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

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.values.any((e) => e != null)) return;

    setState(() => _busy = true);
    await _fakeDelay();
    if (!mounted) return;

    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '회원가입',
      caption: '초대키를 받은 직원만 가입할 수 있어요.',
      onBack: () => Navigator.pop(context),
      children: [
        _AuthField(
          controller: _invite,
          label: '초대키',
          hint: 'HIFIS-4F2A-91K7',
          autofocus: !isDesktop,
          textInputAction: TextInputAction.next,
          formatters: [_UpperCaseFormatter()],
          error: _errors['invite'],
        ),
        SizedBox(height: 7),
        Text('관리자에게 받은 초대키를 그대로 입력해 주세요.', style: AppTextStyles.caption),
        SizedBox(height: 16),
        _AuthField(
          controller: _name,
          label: '이름',
          hint: '홍길동',
          textInputAction: TextInputAction.next,
          error: _errors['name'],
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _email,
          label: '업무용 이메일',
          hint: 'name@hifis.app',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          error: _errors['email'],
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _phone,
          label: '전화번호',
          hint: '010-1234-5678',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          formatters: [_PhoneFormatter()],
          error: _errors['phone'],
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _password,
          label: '비밀번호',
          hint: '8자 이상, 영문·숫자 포함',
          obscure: true,
          textInputAction: TextInputAction.next,
          error: _errors['password'],
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _confirm,
          label: '비밀번호 확인',
          hint: '비밀번호 다시 입력',
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          error: _errors['confirm'],
        ),
        SizedBox(height: 28),
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
