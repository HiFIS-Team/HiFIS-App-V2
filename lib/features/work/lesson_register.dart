part of 'lesson_section.dart';

/// 회원 등록 화면 — 신규/재등록을 전환하며 회원 정보와 등록권을 입력한다
class _RegisterScreen extends StatefulWidget {
  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  /// true면 재등록 모드
  bool _renew = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _rounds = TextEditingController();
  final _payment = TextEditingController();
  final _search = TextEditingController();

  /// 재등록 모드에서 선택된 기존 회원
  _LessonMember? _selected;

  /// 소개한 회원 — 서버가 이름이 아니라 회원 id 를 요구해서 골라 받는다
  ///
  /// 소개로 온 회원은 급여 인센티브가 워크인(40%)이 아니라 재등록과 같은
  /// 요율(50%)로 잡힌다. 비워 두면 트레이너 몫이 줄어든다.
  Member? _referrer;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 입력에 따라 등록 버튼·회당 단가·검색 결과가 실시간 갱신되도록 한다
    for (final controller in [_name, _rounds, _payment, _search]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _rounds, _payment, _search]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _roundCount => int.tryParse(_rounds.text.trim()) ?? 0;
  int get _paymentWon => int.tryParse(_payment.text.trim()) ?? 0;

  /// 회당 단가 — 결제액 ÷ 회차
  int get _unitPrice => _roundCount > 0 && _paymentWon > 0
      ? (_paymentWon / _roundCount).round()
      : 0;

  /// 검색어로 걸러진 내 담당 회원 목록
  List<_LessonMember> get _filtered {
    final base = _LessonStore.instance.myMembers;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  bool get _complete =>
      (_renew
          ? _selected != null
          : _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty) &&
      _roundCount > 0 &&
      _paymentWon > 0;

  Future<void> _pickReferrer() async {
    final picked = await showFullPage<Member>(
      context,
      (_) => _ReferrerPickScreen(selected: _referrer),
    );
    if (picked != null && mounted) setState(() => _referrer = picked);
  }

  /// 아직 안 채운 것 중 **맨 앞의 하나** — 다 채웠으면 null
  ///
  /// 예전에는 `성함·연락처와 등록권 정보를 입력해주세요` 하나로 뭉쳐 있어서
  /// 넷 중 무엇이 빈지 알 수 없었다. 다른 폼들은 빠진 칸을 집어 말한다.
  String? get _missing {
    if (_renew) {
      if (_selected == null) return '재등록할 회원을 골라주세요';
    } else {
      if (_name.text.trim().isEmpty) return '성함을 입력해주세요';
      if (_phone.text.trim().isEmpty) return '연락처를 입력해주세요';
    }
    if (_roundCount <= 0) return '회차를 입력해주세요';
    if (_paymentWon <= 0) return '결제액을 입력해주세요';
    return null;
  }

  Future<void> _submit() async {
    final missing = _missing;
    if (missing != null) {
      AppToast.show(context, missing);
      return;
    }
    if (_saving) return;

    final me = currentUser;
    if (me == null) {
      AppToast.show(context, '로그인 정보를 확인할 수 없어요');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      if (_renew) {
        // 기존 회원에게 새 등록권을 하나 더 발급한다
        final member = _selected!;
        await RegistrationApi.create(
          memberId: member.id,
          trainerId: me.id,
          type: RegistrationType.renewal,
          totalSessions: _roundCount,
          pricePaid: _paymentWon,
          sessionUnitPrice: _unitPrice,
        );
        if (!mounted) return;
        AppToast.show(context, '${member.name}님이 재등록되었습니다');
      } else {
        // 회원과 첫 등록권을 한 트랜잭션으로 만든다 — 둘로 나눠 부르면
        // 등록권에서 실패했을 때 등록권 없는 회원이 남는다
        final name = _name.text.trim();
        await MemberApi.create(
          name: name,
          phone: _phone.text.trim(),
          branchId: me.branchId,
          ownerTrainerId: me.id,
          referrerMemberId: _referrer?.id,
          type: RegistrationType.newMember,
          totalSessions: _roundCount,
          pricePaid: _paymentWon,
          sessionUnitPrice: _unitPrice,
        );
        if (!mounted) return;
        AppToast.show(context, '$name님이 등록되었습니다');
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      ModeSwitch(
                        left: '신규 회원',
                        right: '재등록',
                        value: _renew,
                        onChanged: (v) => setState(() => _renew = v),
                      ),
                      SizedBox(height: 24),
                      if (_renew) ...[
                        // 재등록: 기존 회원을 검색해 선택한다
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('재등록할 회원', style: AppTextStyles.label),
                        ),
                        SizedBox(height: 8),
                        // 신규 탭의 입력 3칸을 투명한 틀로 깔아 전체 높이를
                        // 픽셀 단위로 똑같이 맞춘다 — 등록권 위치가 두 탭에서
                        // 완전히 같아지고, 회원 목록은 남는 공간에서 스크롤된다.
                        Stack(
                          children: [
                            IgnorePointer(
                              child: Opacity(
                                opacity: 0,
                                child: Column(
                                  children: [
                                    _FormField(controller: _name, hint: ''),
                                    SizedBox(height: 8),
                                    _FormField(controller: _phone, hint: ''),
                                    SizedBox(height: 8),
                                    _PickerField(label: '', value: null),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Column(
                                children: [
                                  _FormField(
                                    controller: _search,
                                    hint: '회원 이름 검색',
                                  ),
                                  SizedBox(height: 8),
                                  Expanded(
                                    child: _filtered.isEmpty
                                        ? Center(
                                            child: Text(
                                              _LessonStore
                                                      .instance
                                                      .myMembers
                                                      .isEmpty
                                                  ? '담당 회원이 없어요'
                                                  : '검색 결과가 없어요',
                                              style: AppTextStyles.body2
                                                  .copyWith(
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                            ),
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: ListView(
                                              padding: EdgeInsets.zero,
                                              children: [
                                                for (
                                                  var i = 0;
                                                  i < _filtered.length;
                                                  i++
                                                ) ...[
                                                  if (i > 0)
                                                    SizedBox(height: 8),
                                                  _RenewPickRow(
                                                    name: _filtered[i].name,
                                                    color: _filtered[i].color,
                                                    trailing: '내 담당',
                                                    selected:
                                                        _selected?.id ==
                                                        _filtered[i].id,
                                                    onTap: () => setState(
                                                      () => _selected =
                                                          _filtered[i],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('회원 정보', style: AppTextStyles.label),
                        ),
                        SizedBox(height: 8),
                        _FormField(controller: _name, hint: '성함'),
                        SizedBox(height: 8),
                        _FormField(
                          controller: _phone,
                          hint: '연락처 (010-0000-0000)',
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 8),
                        // 소개한 회원은 이름이 아니라 등록된 회원을 골라야 한다
                        _PickerField(
                          label: '소개한 회원 (선택)',
                          value: _referrer?.name,
                          onTap: _pickReferrer,
                          onClear: _referrer == null
                              ? null
                              : () => setState(() => _referrer = null),
                        ),
                        if (_referrer != null) ...[
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.info_circle,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '소개로 온 회원이라 인센티브가 재등록과 같은 요율로 잡혀요',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('등록권', style: AppTextStyles.label),
                      ),
                      SizedBox(height: 8),
                      _FormField(
                        controller: _rounds,
                        hint: '회차 (예: 30)',
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 8),
                      _FormField(
                        controller: _payment,
                        hint: '결제액 (원)',
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 14),
                      // 결제액 ÷ 회차로 자동 계산되는 단가
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '회당 단가',
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              _unitPrice > 0 ? '${_comma(_unitPrice)}원' : '—',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('회원 등록', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 하단 고정: 네이티브 리퀴드 글래스 등록 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'register',
                    label: _saving
                        ? '등록 중...'
                        : _renew
                        ? '재등록'
                        : '신규 회원 등록',
                    // 필수 입력이 채워져야 채워진 상태가 되고,
                    // 미완성 시 동작은 _submit에서 무시한다
                    filled: _complete && !_saving,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 소개한 회원 고르기 — 지점 전체 회원에서 찾는다
///
/// 소개자가 우리 센터 회원이 아니면 고를 수 없다. 서버가 실제 회원인지
/// 검증하기 때문에 이름만 적어 보낼 수 없다.
class _ReferrerPickScreen extends StatefulWidget {
  _ReferrerPickScreen({this.selected});

  final Member? selected;

  @override
  State<_ReferrerPickScreen> createState() => _ReferrerPickScreenState();
}

class _ReferrerPickScreenState extends State<_ReferrerPickScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Member> get _filtered {
    final base = _LessonStore.instance.members;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Text(
                    '이 회원을 데려온 기존 회원을 골라주세요',
                    style: AppTextStyles.caption,
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            MediaQuery.paddingOf(context).bottom + 96,
                          ),
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0) SizedBox(height: 8),
                              _RenewPickRow(
                                name: list[i].name,
                                color: avatarColorFor(list[i].name),
                                trailing: list[i].phone,
                                selected: widget.selected?.id == list[i].id,
                                onTap: () => Navigator.pop(context, list[i]),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('소개한 회원', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
        ],
      ),
    );
  }
}

/// 회원 선택 줄 — 선택되면 파란 배경과 체크로 표시
class _RenewPickRow extends StatelessWidget {
  _RenewPickRow({
    required this.name,
    required this.color,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 고른 회원이
      // 서서히 사라지며 둘 다 선택된 것처럼 보인다
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                name.characters.first,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.body2.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 18,
                color: AppColors.primary,
              )
            else
              Text(
                trailing,
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
        ),
      ),
    );
  }
}

/// 회색 입력 칸
class _FormField extends StatelessWidget {
  _FormField({required this.controller, required this.hint, this.keyboardType});

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDecorations.fieldPaddingMultiline,
      decoration: AppDecorations.field(),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body1,
        cursorColor: AppColors.primary,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 눌러서 고르는 칸 — 입력 칸과 같은 모양이라 폼에서 줄이 맞는다
class _PickerField extends StatelessWidget {
  _PickerField({
    required this.label,
    required this.value,
    this.onTap,
    this.onClear,
  });

  final String label;

  /// 고른 값 — 없으면 [label]이 회색으로 뜬다
  final String? value;

  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final picked = value != null;

    return Pressable(
      onTap: onTap ?? () {},
      scale: 0.99,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                picked ? value! : label,
                style: AppTextStyles.body1.copyWith(
                  color: picked ? AppColors.textPrimary : AppColors.gray400,
                ),
              ),
            ),
            if (picked && onClear != null)
              Pressable(
                onTap: onClear!,
                scale: 0.9,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 17,
                  color: AppColors.gray300,
                ),
              )
            else
              Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: AppColors.gray300,
              ),
          ],
        ),
      ),
    );
  }
}
