part of 'contribution_section.dart';

// ---------------------------------------------------------------------------
// 기여 점수 주기 (마스터~매니저)
// ---------------------------------------------------------------------------

/// 창의적 아이디어·자발적 목표 업무를 직접 주는 화면
///
/// 근무 외 출근·매출 성과는 기록에서 자동으로 들어오므로 여기서 못 준다.
class _GrantScreen extends StatefulWidget {
  _GrantScreen();

  @override
  State<_GrantScreen> createState() => _GrantScreenState();
}

class _GrantScreenState extends State<_GrantScreen> {
  ContribType _kind = ContribType.idea;
  Employee? _target;
  final _title = TextEditingController();

  bool _saving = false;

  /// 줄 수 있는 사람 — 본인은 뺀다
  ///
  /// 점장은 자기 지점만, 대표·관리자는 전 지점.
  /// (서버는 대상 지점을 막지 않지만, 안 보고 준 점수는 근거가 없다)
  ///
  /// 권한은 **서버가 막는다** — 아래 [_grantable] 과 같은 표가 서버에도 있어서
  /// 못 주는 사람을 고르면 403 `NOT_GRANTABLE` 이 난다. 눌렀을 때 튕길 사람은
  /// 애초에 안 세운다.
  List<Employee> get _people {
    final me = currentUser;
    if (me == null) return const [];
    final sameBranchOnly = me.role == Role.manager;
    final allowed = _grantable[me.role] ?? const <Role>{};
    // 앱 공통 차례 (지점 → 직급 → 이름)
    return [
      for (final employee in StaffDirectory.instance.employees)
        if (employee.id != me.id &&
            allowed.contains(employee.role) &&
            (!sameBranchOnly || employee.branchId == me.branchId))
          employee,
    ]..sort(StaffDirectory.instance.compareStaff);
  }

  /// 누가 누구에게 줄 수 있나 — 서버 `GRANTABLE` 과 같은 표
  ///
  /// **자기보다 아래에만** 준다. 점장끼리 서로 얹어 주면 랭킹이 뜻을 잃고,
  /// 표에 자기 권한이 없어 본인에게 주는 길도 같이 막힌다.
  static const _grantable = {
    Role.master: {Role.manager, Role.member},
    Role.admin: {Role.manager, Role.member},
    Role.manager: {Role.member},
  };

  bool get _ready => _target != null && _title.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready) {
      AppToast.show(context, '받을 사람과 내용을 채워주세요');
      return;
    }
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final target = _target!;
    try {
      // 점수는 항목마다 정해져 있어 주는 사람이 고르지 않는다
      final grant = await ContributionApi.create(
        employeeId: target.id,
        type: _kind,
        reason: _title.text.trim(),
      );
      if (!mounted) return;
      AppToast.show(context, '${target.name}님에게 ${grant.points}점을 줬어요');
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                68,
                24,
                // 마지막 줄(점수)이 아래 버튼·모달 끝에 붙지 않게 넉넉히
                MediaQuery.paddingOf(context).bottom + 130,
              ),
              children: [
                _label('항목'),
                SizedBox(height: 8),
                Row(
                  children: [
                    for (final kind in ContribType.values.where(
                      (k) => k.grantedInApp,
                    ))
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: kind == ContribType.idea ? 8 : 0,
                          ),
                          child: _kindButton(kind),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                _label('받을 사람'),
                SizedBox(height: 8),
                // **다른 화면과 같은 칸이다** (프로젝트 담당·일정 참석자·
                // 회의록·칭찬·동료평가). 예전에는 여기만 알약으로 남아 있었다
                PersonWrap(
                  children: [
                    for (final person in _people)
                      PersonCard(
                        staff: staffFrom(person),
                        joined: person.id == _target?.id,
                        onTap: () => setState(() => _target = person),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                _label('내용'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _title,
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _kind == ContribType.idea
                          ? '예) 락커 회전율 안내 문구 제안'
                          : '예) 신규 회원 온보딩 문서 정리',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 점수 주기', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomButton(
              label: _saving ? '주는 중...' : '주기',
              active: _ready && !_saving,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.label.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );

  /// 항목 버튼 — 점수가 항목에 붙어 있으므로 여기에 같이 적는다
  Widget _kindButton(ContribType kind) {
    final on = kind == _kind;
    final color = on ? AppColors.primary : AppColors.gray500;

    return Pressable(
      onTap: () => setState(() => _kind = kind),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kind.icon, size: 16, color: color),
            SizedBox(height: 10),
            Text(
              kind.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${kind.points}점',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on ? AppColors.primary : AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
