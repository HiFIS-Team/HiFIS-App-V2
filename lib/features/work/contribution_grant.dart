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
  List<Employee> get _people {
    final me = currentUser;
    if (me == null) return const [];
    final sameBranchOnly = me.role == Role.manager;
    return [
      for (final employee in StaffDirectory.instance.employees)
        if (employee.id != me.id &&
            (!sameBranchOnly || employee.branchId == me.branchId))
          employee,
    ];
  }

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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final person in _people) _personChip(person)],
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
      scale: 0.97,
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

  Widget _personChip(Employee person) {
    final on = person.id == _target?.id;
    return Pressable(
      onTap: () => setState(() => _target = person),
      scale: 0.96,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 140),
        height: 44,
        padding: EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: person.name, size: 32),
            SizedBox(width: 8),
            Text(
              person.name,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
