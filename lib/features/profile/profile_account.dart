part of 'profile_screen.dart';

// ---------------------------------------------------------------------------
// 비밀번호 변경 / 회원 탈퇴
// ---------------------------------------------------------------------------

class _PasswordCard extends StatefulWidget {
  _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  /// 검증에 걸린 칸으로 커서를 옮긴다 (다른 폼들과 같은 방식)
  final _currentFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final current = _current.text;
    final next = _next.text;
    if (current.isEmpty || next.isEmpty) {
      AppToast.show(context, '비밀번호를 모두 입력해주세요');
      // 셋 중 **비어 있는 첫 칸**으로 — '모두'라고만 하면 어디가 빈지 모른다
      (current.isEmpty ? _currentFocus : _nextFocus).requestFocus();
      return;
    }
    // 서버도 8자 미만이면 422 를 주지만, 안내가 여기서 나는 게 낫다
    if (next.length < 8) {
      AppToast.show(context, '새 비밀번호는 8자 이상이어야 해요');
      _nextFocus.requestFocus();
      return;
    }
    if (next != _confirm.text) {
      AppToast.show(context, '새 비밀번호가 서로 달라요');
      _confirmFocus.requestFocus();
      return;
    }

    setState(() => _saving = true);
    try {
      await StaffApi.changePassword(
        currentPassword: current,
        newPassword: next,
      );

      // 서버가 토큰 버전을 올려서 **지금 쓰던 토큰도 같이 죽는다** —
      // access 만이 아니라 refresh 까지 401 이 된다 (직접 확인).
      // 그냥 두면 다음 요청에서 '세션이 만료됐어요' 로 튕긴다.
      // 새 비밀번호로 다시 들어가 이 기기만 이어 준다.
      final session = AuthSession.instance;
      await session.signIn(
        email: currentUser?.email ?? session.email ?? '',
        password: next,
        autoLogin: session.autoLogin,
      );

      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      AppToast.show(context, '비밀번호를 바꿨어요. 다른 기기는 다시 로그인해야 해요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('비밀번호 변경', style: AppTextStyles.title3),
          SizedBox(height: 20),
          _FieldLabel('현재 비밀번호'),
          SizedBox(height: 8),
          _InputBox(
            controller: _current,
            focusNode: _currentFocus,
            obscure: true,
          ),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 (8자 이상)'),
          SizedBox(height: 8),
          _InputBox(controller: _next, focusNode: _nextFocus, obscure: true),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 확인'),
          SizedBox(height: 8),
          _InputBox(
            controller: _confirm,
            focusNode: _confirmFocus,
            obscure: true,
            helper: '바꾸면 이 기기만 남고 다른 기기는 로그아웃돼요.',
          ),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _SmallPrimaryButton(
              label: '비밀번호 변경',
              busy: _saving,
              onTap: _change,
            ),
          ),
        ],
      ),
    );
  }
}

/// 로그아웃 — 확인을 한 번 받고 로그인 화면으로 돌아간다
class _LogoutCard extends StatelessWidget {
  _LogoutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('로그아웃', style: AppTextStyles.title3),
          SizedBox(height: 8),
          Text(
            '이 기기에서 로그아웃해요. 자동 로그인을 켜 뒀더라도 '
            '다음에 들어올 때는 다시 로그인해야 해요.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => confirmLogout(context),
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '로그아웃',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawCard extends StatelessWidget {
  _WithdrawCard();

  /// 탈퇴 — 되돌릴 수 없어서 두 번 묻는다
  Future<void> _withdraw(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: '정말 탈퇴할까요?',
      message: '되돌릴 수 없어요. 계정이 비활성화되고 이름·연락처가 지워져요.',
      confirmLabel: '탈퇴하기',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await StaffApi.withdraw();
    } catch (error) {
      // 대표가 혼자면 서버가 막는다 (승인권이 비어 버린다)
      if (context.mounted) AppToast.show(context, messageOf(error));
      return;
    }
    if (!context.mounted) return;
    // 로그아웃과 같은 순서 — 얹혀 있는 화면부터 걷어내고 세션을 끊는다
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await AuthSession.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '회원 탈퇴',
            style: AppTextStyles.title3.copyWith(color: AppColors.error),
          ),
          SizedBox(height: 8),
          Text(
            '탈퇴하면 이름·연락처 등 개인 식별 정보와 로그인 수단이 삭제되고 '
            '계정이 비활성화돼요. 회사가 법적으로 보관해야 하는 근태·급여 기록은 '
            '익명 처리되어 일정 기간 보존될 수 있어요.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => _withdraw(context),
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '회원 탈퇴하기',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
