part of 'auth_screen.dart';

/// 비밀번호 찾기 — 인증번호를 받아 새 비밀번호로 바꾼다
///
/// 세 단계를 한 화면에서 갈아 끼운다.
/// 0 이메일·전화번호 입력 → 1 인증번호 확인 → 2 새 비밀번호 설정.
/// 문자·메일 발송이 없어 인증번호는 6자리면 통과시킨다. 실제 연동 때는
/// [_send]에서 발송 API를, [_verify]에서 확인 API를 부르면 된다.
class _PasswordResetScreen extends StatefulWidget {
  _PasswordResetScreen();

  @override
  State<_PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<_PasswordResetScreen> {
  /// 0 연락처 입력 · 1 인증번호 · 2 새 비밀번호
  int _step = 0;

  /// 0 이메일 · 1 전화번호
  int _method = 0;

  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _contactError;
  String? _codeError;
  String? _passwordError;
  String? _confirmError;

  /// 인증번호 유효 시간 (초)
  static const _limit = 180;
  int _left = _limit;
  Timer? _ticker;

  /// 2단계에서 받은 재설정 토큰 — 3단계에서 한 번만 쓸 수 있다
  String? _resetToken;

  @override
  void dispose() {
    _ticker?.cancel();
    _contact.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _email => _method == 0;

  String get _timeLeft {
    final m = (_left ~/ 60).toString();
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startTimer() {
    _ticker?.cancel();
    setState(() => _left = _limit);
    _ticker = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _left--);
      if (_left <= 0) timer.cancel();
    });
  }

  /// 인증번호 보내기 — 1단계 통과이자 재전송
  Future<void> _send() async {
    final value = _contact.text.trim();
    final error = _email ? _checkEmail(value) : _checkPhone(value);
    setState(() => _contactError = error);
    if (error != null) return;

    setState(() => _busy = true);
    try {
      // 계정이 없어도 서버는 성공으로 답한다 (가입 여부가 새어 나가지 않게)
      await AuthApi.requestPasswordReset(byEmail: _email, contact: value);
    } catch (error) {
      if (!mounted) return;
      return setState(() {
        _busy = false;
        _contactError = messageOf(error);
      });
    }
    if (!mounted) return;

    setState(() {
      _busy = false;
      _step = 1;
      _codeError = null;
      _code.clear();
    });
    _startTimer();
    AppToast.show(context, '인증번호를 보냈어요');
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    final error = code.length < 6
        ? '인증번호 6자리를 입력해 주세요.'
        : _left <= 0
        ? '인증 시간이 지났어요. 다시 받아 주세요.'
        : null;

    setState(() => _codeError = error);
    if (error != null) return;

    setState(() => _busy = true);
    try {
      _resetToken = await AuthApi.verifyPasswordReset(
        contact: _contact.text.trim(),
        code: code,
      );
    } catch (error) {
      if (!mounted) return;
      return setState(() {
        _busy = false;
        _codeError = messageOf(error);
      });
    }
    if (!mounted) return;

    _ticker?.cancel();
    setState(() {
      _busy = false;
      _step = 2;
    });
  }

  Future<void> _change() async {
    final passwordError = _checkPassword(_password.text);
    final confirmError = _confirm.text.isEmpty
        ? '비밀번호를 한 번 더 입력해 주세요.'
        : _confirm.text != _password.text
        ? '비밀번호가 서로 달라요.'
        : null;

    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    if (passwordError != null || confirmError != null) return;

    setState(() => _busy = true);
    try {
      await AuthApi.confirmPasswordReset(
        resetToken: _resetToken!,
        password: _password.text,
      );
    } catch (error) {
      if (!mounted) return;
      return setState(() {
        _busy = false;
        _passwordError = messageOf(error);
      });
    }
    if (!mounted) return;

    Navigator.pop(context, true);
  }

  /// 뒤로 — 단계가 남아 있으면 한 단계씩 물러난다
  void _back() {
    if (_step == 0) return Navigator.pop(context);
    _ticker?.cancel();
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: switch (_step) {
        0 => '비밀번호 찾기',
        1 => '인증번호 입력',
        _ => '새 비밀번호',
      },
      caption: switch (_step) {
        0 => '가입할 때 등록한 이메일이나 전화번호를 알려 주세요.',
        1 => '${_contact.text.trim()} 으로 6자리 번호를 보냈어요.',
        _ => '앞으로 사용할 비밀번호를 입력해 주세요.',
      },
      // 데스크톱은 회원가입과 같이 헤더에 뒤로 버튼을 두지 않는다 —
      // 카드가 그만큼 길어져 창 안에 안 들어간다. 대신 아래에 링크를 둔다.
      onBack: isDesktop ? null : _back,
      children: [
        _StepBar(step: _step),
        SizedBox(height: 24),
        ...switch (_step) {
          0 => _contactStep(),
          1 => _codeStep(),
          _ => _passwordStep(),
        },
        if (isDesktop) ...[SizedBox(height: 14), _backLink()],
      ],
    );
  }

  /// 데스크톱에서 헤더의 뒤로 버튼을 대신하는 링크
  ///
  /// 누르면 [_back] 과 똑같이 움직인다 — 첫 단계면 로그인으로 나가고
  /// 아니면 한 단계 물러난다. 자리만 아래로 옮긴 것이다.
  Widget _backLink() {
    final (prompt, action) = switch (_step) {
      0 => ('비밀번호가 기억났나요?', '로그인'),
      1 => ('주소를 잘못 입력했나요?', '다시 입력'),
      _ => ('인증을 다시 할까요?', '이전 단계'),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: AppTextStyles.label.copyWith(color: AppColors.textTertiary),
        ),
        SizedBox(width: 6),
        _AuthTextButton(label: action, onTap: _back, strong: true),
      ],
    );
  }

  List<Widget> _contactStep() => [
    SegmentedTabs(
      labels: ['이메일', '전화번호'],
      selected: _method,
      onSelect: (i) => setState(() {
        _method = i;
        _contact.clear();
        _contactError = null;
      }),
    ),
    SizedBox(height: 20),
    _AuthField(
      // 방식을 바꾸면 입력 칸도 새로 시작하게 키를 나눈다
      key: ValueKey(_method),
      controller: _contact,
      label: _email ? '이메일' : '전화번호',
      hint: _email ? 'name@hifis.app' : '010-1234-5678',
      keyboardType: _email ? TextInputType.emailAddress : TextInputType.phone,
      formatters: _email ? null : [_PhoneFormatter()],
      textInputAction: TextInputAction.done,
      onSubmitted: _send,
      error: _contactError,
    ),
    SizedBox(height: 28),
    _AuthButton(label: '인증번호 받기', onTap: _send, busy: _busy),
  ];

  List<Widget> _codeStep() => [
    _AuthField(
      controller: _code,
      label: '인증번호',
      hint: '000000',
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      center: true,
      letterSpacing: 10,
      autofocus: !isDesktop,
      textInputAction: TextInputAction.done,
      onSubmitted: _verify,
      error: _codeError,
    ),
    SizedBox(height: 12),
    Row(
      children: [
        Text(
          _left > 0 ? '남은 시간 $_timeLeft' : '인증 시간이 지났어요',
          style: AppTextStyles.label.copyWith(
            color: _left > 0 ? AppColors.primary : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacer(),
        _AuthTextButton(label: '인증번호 재전송', onTap: _send),
      ],
    ),
    SizedBox(height: 28),
    _AuthButton(label: '확인', onTap: _verify, busy: _busy),
  ];

  List<Widget> _passwordStep() => [
    _AuthField(
      controller: _password,
      label: '새 비밀번호',
      hint: '8자 이상, 영문·숫자 포함',
      obscure: true,
      autofocus: !isDesktop,
      textInputAction: TextInputAction.next,
      error: _passwordError,
    ),
    SizedBox(height: 16),
    _AuthField(
      controller: _confirm,
      label: '새 비밀번호 확인',
      hint: '비밀번호 다시 입력',
      obscure: true,
      textInputAction: TextInputAction.done,
      onSubmitted: _change,
      error: _confirmError,
    ),
    SizedBox(height: 28),
    _AuthButton(label: '비밀번호 변경', onTap: _change, busy: _busy),
  ];
}

/// 세 단계 진행 막대
class _StepBar extends StatelessWidget {
  _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
