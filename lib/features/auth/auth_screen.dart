import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/auth/auth_api.dart';
import '../../core/api/auth/consent_api.dart';
import '../../core/api/client/api_exception.dart';
import '../../core/api/client/token_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../legal/legal_screen.dart';
import 'auth_session.dart';

part 'auth_widgets.dart';
part 'auth_signup.dart';
part 'auth_reset.dart';

/// 로그인 화면
///
/// 서버가 없어 자격 증명은 형식만 본다. 실제 연동 때는 [_submit]의
/// 대기 자리에 로그인 API를 넣고, 실패 응답을 _passwordError로 보여주면 된다.
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _email = TextEditingController(
    // 지난번에 로그인한 이메일을 미리 채워 둔다
    text: AuthSession.instance.email ?? '',
  );
  final _password = TextEditingController();

  late bool _auto = AuthSession.instance.autoLogin;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final emailError = _checkEmail(email);
    final passwordError = _password.text.isEmpty ? '비밀번호를 입력해 주세요.' : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _busy = true);
    try {
      // 로그인 상태가 되면 최상위 게이트가 메인 화면으로 바꿔 끼운다
      await AuthSession.instance.signIn(
        email: email,
        password: _password.text,
        autoLogin: _auto,
      );
    } catch (error) {
      if (!mounted) return;
      // 서버가 알려준 이유를 그대로 보여준다 (자격 증명 오류·네트워크 등)
      setState(() {
        _busy = false;
        _passwordError = messageOf(error);
      });
    }
  }

  Future<void> _openSignup() async {
    final email = await Navigator.push<String>(
      context,
      CupertinoPageRoute(builder: (_) => _SignupScreen()),
    );
    if (email == null || !mounted) return;

    // 가입한 이메일로 바로 로그인할 수 있게 채워 준다
    setState(() {
      _email.text = email;
      _emailError = null;
    });
    AppToast.show(context, '가입이 완료됐어요. 로그인해 주세요');
  }

  Future<void> _openReset() async {
    final done = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => _PasswordResetScreen()),
    );
    if (done != true || !mounted) return;
    AppToast.show(context, '비밀번호를 변경했어요');
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      children: [
        // 스플래시에서 보던 마크가 그대로 이어지도록 같은 이미지를 쓴다
        Center(
          child: Image.asset(
            'assets/images/hifis_mark.png',
            height: 64,
            cacheHeight: 192,
          ),
        ),
        SizedBox(height: 22),
        Center(child: Text('다시 만나서 반가워요', style: AppTextStyles.title1)),
        SizedBox(height: 8),
        Center(
          child: Text(
            '피트니스스타 직원 계정으로 로그인해 주세요.',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        ),
        SizedBox(height: 32),
        _AuthField(
          controller: _email,
          label: '이메일',
          hint: 'name@hifis.app',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          error: _emailError,
        ),
        SizedBox(height: 16),
        _AuthField(
          controller: _password,
          label: '비밀번호',
          hint: '비밀번호 입력',
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          error: _passwordError,
        ),
        SizedBox(height: 18),
        Row(
          children: [
            _AuthCheck(
              label: '자동 로그인',
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
            ),
            Spacer(),
            _AuthTextButton(label: '비밀번호 찾기', onTap: _openReset),
          ],
        ),
        SizedBox(height: 24),
        _AuthButton(label: '로그인', onTap: _submit, busy: _busy),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '아직 계정이 없나요?',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(width: 6),
            _AuthTextButton(label: '회원가입', onTap: _openSignup, strong: true),
          ],
        ),
        SizedBox(height: 12),
        // 가입하지 않은 사람도 언제든 열어볼 수 있어야 한다 (공개 의무)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final document in LegalDocument.values) ...[
              if (document != LegalDocument.values.first)
                Text(
                  ' · ',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
              Pressable(
                onTap: () => showLegalDocument(context, document),
                scale: 0.94,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    document.title,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
