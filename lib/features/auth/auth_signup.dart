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

  /// 약관 동의 — 둘 다 필수라 하나라도 빠지면 가입이 막힌다
  final _agreed = {LegalDocument.terms: false, LegalDocument.privacy: false};
  bool _agreeError = false;

  /// 폰에서만 쓰는 단계 — 0 초대키 · 1 내 정보 · 2 비밀번호
  ///
  /// 한 화면에 입력칸 6개를 쌓으면 답답해서 끊어 받는다.
  /// PC는 카드가 넓어 두 칸씩 나란히 들어가므로 한 장으로 둔다.
  int _step = 0;

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

  /// 단계별 검증 — 폰은 이 단위로 끊어서 본다
  ///
  /// 0 초대키 · 1 내 정보 · 2 비밀번호
  Map<String, String?> _checkStep(int step) {
    final invite = _invite.text.trim();
    final name = _name.text.trim();

    return switch (step) {
      0 => {
        'invite': invite.isEmpty
            ? '초대키를 입력해 주세요.'
            : invite.replaceAll('-', '').length < 8
            ? '초대키를 다시 확인해 주세요.'
            : null,
      },
      1 => {
        'name': name.isEmpty
            ? '이름을 입력해 주세요.'
            : name.length < 2
            ? '이름을 두 글자 이상 입력해 주세요.'
            : null,
        'email': _checkEmail(_email.text.trim()),
        'phone': _checkPhone(_phone.text),
      },
      _ => {
        'password': _checkPassword(_password.text),
        'confirm': _confirm.text.isEmpty
            ? '비밀번호를 한 번 더 입력해 주세요.'
            : _confirm.text != _password.text
            ? '비밀번호가 서로 달라요.'
            : null,
      },
    };
  }

  /// 다음 단계로 — 이 단계 입력이 통과해야 넘어간다 (폰 전용)
  void _next() {
    final errors = _checkStep(_step);
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.values.any((e) => e != null)) return;
    setState(() => _step++);
  }

  /// 뒤로 — 단계가 남아 있으면 한 단계씩 물러난다 (폰 전용)
  void _back() {
    if (_step == 0 || isDesktop) return Navigator.pop(context);
    setState(() => _step--);
  }

  Future<void> _submit() async {
    final invite = _invite.text.trim();
    final name = _name.text.trim();
    final email = _email.text.trim();

    final errors = <String, String?>{
      for (var step = 0; step < 3; step++) ..._checkStep(step),
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
      await AuthApi.signup(
        name: name,
        email: email,
        password: _password.text,
        phone: _phone.text,
        inviteKey: invite,
        // 동의는 **가입 요청에 같이 실어 보낸다** — 서버가 같은 트랜잭션에
        // 남기므로, 가입은 됐는데 동의 기록만 없는 상태가 아예 생기지 않는다
        consents: [
          for (final document in LegalDocument.values)
            (docType: document.wire, docVersion: document.version),
        ],
      );
      if (!mounted) return;
      Navigator.pop(context, email);
    } catch (error) {
      if (!mounted) return;
      // 이메일 중복·초대키 만료 등 서버가 알려준 이유를 해당 칸에 붙인다
      final message = messageOf(error);
      final aboutInvite = message.contains('초대키');
      setState(() {
        _busy = false;
        _errors['invite'] = aboutInvite ? message : null;
        _errors['email'] = aboutInvite ? null : message;
        // 폰은 단계로 나뉘어 있어서, 오류가 난 칸이 있는 단계로 되돌아가야 보인다
        if (!isDesktop) _step = aboutInvite ? 0 : 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return _buildPhone();

    // 데스크톱은 뒤로 버튼을 위에 두지 않는다 — 카드가 그만큼 길어져
    // 창 안에 안 들어가고 스크롤이 생긴다. 대신 아래에 로그인 링크를 둔다.
    return _AuthScaffold(
      title: '회원가입',
      caption: '초대키를 받은 직원만 가입할 수 있어요.',
      // 짝지은 칸을 나란히 두려면 폭이 있어야 한다
      width: 560,
      children: [
        // 이름을 초대키와 짝지어 한 줄을 아낀다 — 카드가 창을 넘으면 스크롤이 생긴다
        _FieldPair(
          left: _AuthField(
            controller: _invite,
            label: '초대키',
            hint: 'HIFIS-4F2A-91K7',
            textInputAction: TextInputAction.next,
            formatters: [_UpperCaseFormatter()],
            error: _errors['invite'],
          ),
          right: _AuthField(
            controller: _name,
            label: '이름',
            hint: '홍길동',
            textInputAction: TextInputAction.next,
            error: _errors['name'],
          ),
        ),
        SizedBox(height: 7),
        Text('관리자에게 받은 초대키를 그대로 입력해 주세요.', style: AppTextStyles.caption),
        SizedBox(height: 16),
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
        SizedBox(height: 20),
        _AuthButton(label: '가입하기', onTap: _submit, busy: _busy),
        SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '이미 계정이 있나요?',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(width: 6),
            _AuthTextButton(
              label: '로그인',
              onTap: () => Navigator.pop(context),
              strong: true,
            ),
          ],
        ),
      ],
    );
  }

  /// 폰 — 세 단계로 끊어 받는다
  Widget _buildPhone() {
    final last = _step == 2;

    return _AuthScaffold(
      title: switch (_step) {
        0 => '초대키 입력',
        1 => '내 정보',
        _ => '비밀번호 설정',
      },
      caption: switch (_step) {
        0 => '관리자에게 받은 초대키가 필요해요.',
        1 => '급여·근태에 쓰이니 정확하게 입력해 주세요.',
        _ => '앞으로 로그인할 때 쓸 비밀번호예요.',
      },
      onBack: _back,
      children: [
        _StepBar(step: _step),
        SizedBox(height: 24),
        ...switch (_step) {
          0 => _inviteStep(),
          1 => _profileStep(),
          _ => _passwordStep(),
        },
        SizedBox(height: 28),
        _AuthButton(
          label: last ? '가입하기' : '다음',
          onTap: last ? _submit : _next,
          busy: _busy,
        ),
      ],
    );
  }

  List<Widget> _inviteStep() => [
    _AuthField(
      controller: _invite,
      label: '초대키',
      hint: 'HIFIS-4F2A-91K7',
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: _next,
      formatters: [_UpperCaseFormatter()],
      error: _errors['invite'],
    ),
    SizedBox(height: 7),
    Text('관리자에게 받은 초대키를 그대로 입력해 주세요.', style: AppTextStyles.caption),
  ];

  List<Widget> _profileStep() => [
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
      textInputAction: TextInputAction.done,
      onSubmitted: _next,
      formatters: [_PhoneFormatter()],
      error: _errors['phone'],
    ),
  ];

  List<Widget> _passwordStep() => [
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
  ];
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
