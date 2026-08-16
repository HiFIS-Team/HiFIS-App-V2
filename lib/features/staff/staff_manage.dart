part of 'staff_screen.dart';

// ---------------------------------------------------------------------------
// 인사 관리 — MASTER·ADMIN 만 본다
// ---------------------------------------------------------------------------

/// 인사 정보를 건드릴 수 있는 권한인가
///
/// **MASTER 만 된다** (2026-08-04 정함).
///
/// ADMIN 은 **지켜보는 자리**다 — 명단·현황은 다 보지만 승진·발령·초대처럼
/// 사람을 바꾸는 일은 대표만 한다. 서버는 점장(MANAGER)에게도 열려 있지만
/// 앱은 그보다 좁게 잡는다. 열려면 여기 한 줄만 고치면 된다.
bool get _canManageStaff => myRole == Role.master;

/// 이 사람의 인사 정보를 내가 바꿀 수 있는가
///
/// 서버가 **본인보다 높은 권한자의 계정은 수정을 막는다** (403 FORBIDDEN).
/// 눌러도 실패할 버튼을 보여주지 않으려고 앱도 같은 기준으로 감춘다.
bool _canManage(_Member member) =>
    _canManageStaff && myRole.index <= member.permission.index;

/// 내가 줄 수 있는 권한 — **나보다 높은 권한은 못 준다** (서버가 403)
List<Role> get _grantableRoles =>
    Role.values.where((r) => r.index >= myRole.index).toList();

/// 조직도 헤더의 '직원 초대' — 지점 고르개 옆에 선다
class _InviteButton extends StatelessWidget {
  _InviteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.person_badge_plus,
              size: 15,
              color: AppColors.surface,
            ),
            SizedBox(width: 6),
            Text(
              '직원 초대',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 직원 한 명의 지점·직군·권한을 바꾸는 화면
///
/// 프로필(본인이 고치는 것)과 나누어 둔다 — 여기 값들은 **남이 정해 주는 것**이고
/// 서버도 다른 엔드포인트(`PATCH /employees/{id}`)를 쓴다.
class _ManageSheet extends StatefulWidget {
  _ManageSheet({required this.member});

  final _Member member;

  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late String _branchId = widget.member.source.branchId;
  late Rank _rank = widget.member.rank;
  late Role _role = widget.member.permission;
  late EmploymentType _employment = widget.member.source.employmentType;
  late EmployeeStatus _status = widget.member.source.status;

  bool _saving = false;

  _Member get member => widget.member;

  /// 바꾼 게 있는가 — 없으면 저장 버튼을 잠근다
  bool get _dirty =>
      _branchId != member.source.branchId ||
      _rank != member.rank ||
      _role != member.permission ||
      _employment != member.source.employmentType ||
      _status != member.source.status;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await StaffApi.updateEmployee(
        member.id,
        branchId: _branchId,
        rank: _rank,
        role: _role,
        employmentType: _employment,
        status: _status,
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, messageOf(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 본사(HQ)도 고를 수 있게 둔다 — MASTER·ADMIN 이 소속될 자리다.
    // 필터 칩에서만 감출 뿐 실제 소속으로는 쓴다.
    final branches = [...StaffDirectory.instance.branches]
      ..sort(
        (a, b) => StaffDirectory.instance
            .branchRank(a.id)
            .compareTo(StaffDirectory.instance.branchRank(b.id)),
      );

    return PhoneDetailScaffold(
      title: '인사 정보 변경',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          _ManageWho(member: member),
          SizedBox(height: 16),
          _PickerCard(
            title: '지점',
            note: '가입 이후 발령은 여기서 옮겨요',
            options: [for (final b in branches) (b.id, b.name)],
            selected: _branchId,
            onSelect: (id) => setState(() => _branchId = id),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '직군',
            note: '조직도에서 사람을 가르는 기준이에요',
            options: [for (final r in Rank.values) (r.wire, r.label)],
            selected: _rank.wire,
            onSelect: (wire) => setState(() => _rank = Rank.parse(wire)),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '권한',
            note: myRole == Role.master
                ? '무엇을 볼 수 있고 결재할 수 있는지가 정해져요'
                : '나보다 높은 권한은 줄 수 없어요',
            options: [for (final r in _grantableRoles) (r.wire, r.label)],
            selected: _role.wire,
            onSelect: (wire) => setState(() => _role = Role.parse(wire)),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '고용 형태',
            note: '알바는 직군과 상관없이 시급으로만 받아요',
            options: [for (final t in EmploymentType.values) (t.wire, t.label)],
            selected: _employment.wire,
            onSelect: (wire) =>
                setState(() => _employment = EmploymentType.parse(wire)),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '재직 상태',
            note: '퇴사로 바꾸면 조직도 퇴사자 칸으로 옮겨져요',
            // 비활성은 쓰지 않는다 — 조직도에서 가운데 칸을 알바에 내줬다
            options: [
              (EmployeeStatus.active.wire, '재직'),
              (EmployeeStatus.resigned.wire, '퇴사'),
            ],
            selected: _status == EmployeeStatus.resigned
                ? EmployeeStatus.resigned.wire
                : EmployeeStatus.active.wire,
            onSelect: (wire) =>
                setState(() => _status = EmployeeStatus.parse(wire)),
          ),
          SizedBox(height: 20),
          // 바꾼 게 없으면 눌러도 할 일이 없다 — 흐리게 두고 신호만 준다
          AppButton(
            label: _saving ? '저장 중…' : '저장',
            onTap: _dirty && !_saving ? _save : () {},
            filled: true,
            color: _dirty && !_saving ? null : AppColors.gray200,
            textColor: _dirty && !_saving ? null : AppColors.textTertiary,
          ),
          SizedBox(height: 12),
          Text(
            '바꾼 값은 본인에게 바로 보여요. 권한을 낮추면 보던 화면이 사라질 수 있어요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 누구를 고치고 있는지 — 화면 맨 위에서 다시 확인시킨다
class _ManageWho extends StatelessWidget {
  _ManageWho({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Avatar(name: member.name, imageUrl: member.avatarUrl, size: 46),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTextStyles.title3),
                SizedBox(height: 3),
                Text(
                  '${member.branchLabel} · ${member.role} · ${member.permission.label}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 값 하나를 고르는 카드 — 칩을 늘어놓고 하나만 켠다
///
/// 고를 것이 지점 3~4개, 직군 7개, 권한 4개라 다 보이는 게 낫다.
/// 목록에서 하나 고르려고 창을 또 여는 것보다 손이 덜 간다.
class _PickerCard extends StatelessWidget {
  _PickerCard({
    required this.title,
    required this.note,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String note;

  /// (값, 화면에 적을 이름)
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 3),
          Text(
            note,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in options)
                Pressable(
                  onTap: () => onSelect(value),
                  scale: 0.96,
                  // `alignment` 를 주면 안 된다 — Container 가 부모가 주는
                  // 최대 폭까지 늘어나서 칩이 한 줄에 하나씩 쌓인다
                  // (`Wrap` 을 쓴 뜻이 없어진다). 글자는 padding 이 가운데로 잡는다.
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 140),
                    height: 38,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: value == selected
                          ? AppColors.primary
                          : AppColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        label,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: value == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: value == selected
                              ? AppColors.surface
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 초대키
// ---------------------------------------------------------------------------

/// 초대키 발급·관리 화면
///
/// **신규 입사자의 지점·직군·권한은 이 키가 정한다.** 회원가입이 키에 적힌
/// 값을 그대로 쓰기 때문에(`branch_id=key.branch_id`), 사람을 어느 지점으로
/// 받을지는 여기서 결정된다.
class _InviteKeyScreen extends StatefulWidget {
  _InviteKeyScreen();

  @override
  State<_InviteKeyScreen> createState() => _InviteKeyScreenState();
}

class _InviteKeyScreenState extends State<_InviteKeyScreen>
    with SkeletonDelay<_InviteKeyScreen> {
  List<InviteKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final keys = await InviteKeyApi.list();
      if (mounted) setState(() => _keys = keys);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  Future<void> _issue() async {
    final made = await showFullPage<InviteKey>(
      context,
      (_) => _InviteKeyForm(),
    );
    if (made == null || !mounted) return;
    setState(() => _keys = [made, ..._keys]);
    // 발급한 키는 바로 넘겨줘야 쓸모가 있다 — 손이 안 가게 미리 복사해 둔다
    await Clipboard.setData(ClipboardData(text: made.code));
    if (mounted) AppToast.show(context, '${made.code} 를 복사했어요');
  }

  Future<void> _delete(InviteKey key) async {
    final ok = await showConfirmDialog(
      context,
      title: '${key.code} 를 지울까요?',
      message: '아직 가입 안 한 사람이 이 키를 갖고 있으면 못 쓰게 돼요.',
      confirmLabel: '지우기',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await InviteKeyApi.delete(key.id);
      if (!mounted) return;
      setState(() => _keys = _keys.where((k) => k.id != key.id).toList());
      AppToast.show(context, '초대키를 지웠어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  void _copy(InviteKey key) {
    Clipboard.setData(ClipboardData(text: key.code));
    AppToast.show(context, '${key.code} 를 복사했어요');
  }

  @override
  Widget build(BuildContext context) {
    // 쓸 수 있는 키를 위로 — 지난 키는 이력이라 아래에 둔다
    final usable = _keys.where((k) => k.usable).toList();
    final done = _keys.where((k) => !k.usable).toList();

    return PhoneDetailScaffold(
      title: '직원 초대',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '초대키로만 가입할 수 있어요',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '키를 만들 때 정한 지점·직군·권한으로 계정이 만들어져요. '
                  '만든 키를 새로 오는 분에게 전달하면 돼요.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                AppButton(label: '초대키 만들기', onTap: _issue, filled: true),
              ],
            ),
          ),
          SizedBox(height: 20),
          if (showSkeleton)
            SkeletonGroup(child: SkeletonRows(rows: 3, avatar: 0, trailing: 64))
          else ...[
            _SectionHeader(title: '쓸 수 있는 키', count: usable.length),
            SizedBox(height: 12),
            if (usable.isEmpty)
              EmptyCard(icon: CupertinoIcons.ticket, text: '쓸 수 있는 키가 없어요')
            else
              for (final key in usable)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _InviteKeyRow(
                    invite: key,
                    onCopy: () => _copy(key),
                    onDelete: () => _delete(key),
                  ),
                ),
            if (done.isNotEmpty) ...[
              SizedBox(height: 20),
              _SectionHeader(title: '지난 키', count: done.length),
              SizedBox(height: 12),
              for (final key in done)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _InviteKeyRow(
                    invite: key,
                    onCopy: null,
                    onDelete: () => _delete(key),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 초대키 한 줄
class _InviteKeyRow extends StatelessWidget {
  _InviteKeyRow({
    required this.invite,
    required this.onCopy,
    required this.onDelete,
  });

  final InviteKey invite;

  /// 지난 키는 복사할 이유가 없어서 null 이 온다
  final VoidCallback? onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final live = invite.usable;
    final branch = StaffDirectory.instance.branchName(invite.branchId);

    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: AppDecorations.card(radius: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.code,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: live ? AppColors.textPrimary : AppColors.gray400,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  [
                    if (branch.isNotEmpty) branch,
                    invite.rank.label,
                    invite.role.label,
                    // 알바일 때만 붙인다 — 정규직이 대부분이라 늘 적으면
                    // 줄만 길어지고 눈에 안 들어온다
                    if (invite.employmentType == EmploymentType.partTime)
                      invite.employmentType.label,
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _InviteStatusTag(invite: invite),
              SizedBox(height: 4),
              Text(
                live ? '${_date(invite.expiresAt)}까지' : _date(invite.createdAt),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(width: 6),
          if (onCopy case final copy?)
            _InviteAction(
              icon: CupertinoIcons.doc_on_doc,
              tooltip: '코드 복사',
              onTap: copy,
            ),
          _InviteAction(
            icon: CupertinoIcons.trash,
            tooltip: '지우기',
            danger: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _InviteStatusTag extends StatelessWidget {
  _InviteStatusTag({required this.invite});

  final InviteKey invite;

  @override
  Widget build(BuildContext context) {
    // 서버가 UNUSED 라고 해도 날짜가 지났으면 못 쓴다
    final (label, color) = switch (invite.status) {
      InviteStatus.used => ('사용됨', AppColors.gray400),
      InviteStatus.expired => ('만료', AppColors.gray400),
      InviteStatus.unused when !invite.usable => ('만료', AppColors.gray400),
      InviteStatus.unused => ('사용 전', AppColors.success),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        // 상태 알약은 전부 완전한 알약이다 (프로젝트·일정·월차와 같다)
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InviteAction extends StatelessWidget {
  _InviteAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 17,
            color: danger ? AppColors.error : AppColors.gray500,
          ),
        ),
      ),
    );
  }
}

/// 초대키 발급 폼
class _InviteKeyForm extends StatefulWidget {
  _InviteKeyForm();

  @override
  State<_InviteKeyForm> createState() => _InviteKeyFormState();
}

class _InviteKeyFormState extends State<_InviteKeyForm> {
  String? _branchId;
  Rank _rank = Rank.trainer;
  Role _role = Role.member;
  EmploymentType _employment = EmploymentType.fullTime;
  bool _saving = false;

  Future<void> _submit() async {
    final branchId = _branchId;
    if (branchId == null) {
      AppToast.show(context, '지점을 골라주세요');
      return;
    }
    setState(() => _saving = true);
    try {
      final made = await InviteKeyApi.create(
        branchId: branchId,
        role: _role,
        rank: _rank,
        employmentType: _employment,
      );
      if (mounted) Navigator.pop(context, made);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, messageOf(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = [...StaffDirectory.instance.branches]
      ..sort(
        (a, b) => StaffDirectory.instance
            .branchRank(a.id)
            .compareTo(StaffDirectory.instance.branchRank(b.id)),
      );

    return PhoneDetailScaffold(
      title: '초대키 만들기',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          _PickerCard(
            title: '지점',
            note: '이 키로 가입하면 이 지점 소속이 돼요',
            options: [for (final b in branches) (b.id, b.name)],
            selected: _branchId ?? '',
            onSelect: (id) => setState(() => _branchId = id),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '직군',
            note: '나중에 조직도에서 바꿀 수 있어요',
            options: [for (final r in Rank.values) (r.wire, r.label)],
            selected: _rank.wire,
            onSelect: (wire) => setState(() => _rank = Rank.parse(wire)),
          ),
          SizedBox(height: 12),
          _PickerCard(
            title: '권한',
            note: myRole == Role.master
                ? '대부분 MEMBER 예요'
                : '나보다 높은 권한은 줄 수 없어요',
            options: [for (final r in _grantableRoles) (r.wire, r.label)],
            selected: _role.wire,
            onSelect: (wire) => setState(() => _role = Role.parse(wire)),
          ),
          SizedBox(height: 12),
          // 고용 형태는 **여기서만** 정할 수 있다 — 키에 박혀서 가입할 때 그대로
          // 붙는다. 들어온 뒤 정규직으로 올리는 건 인사 정보 변경 쪽이라,
          // 그 화면과 같은 순서(지점·직군·권한·고용 형태)로 둔다.
          _PickerCard(
            title: '고용 형태',
            note: '알바는 직군과 상관없이 시급으로만 받아요',
            options: [for (final t in EmploymentType.values) (t.wire, t.label)],
            selected: _employment.wire,
            onSelect: (wire) =>
                setState(() => _employment = EmploymentType.parse(wire)),
          ),
          SizedBox(height: 20),
          AppButton(
            label: _saving ? '만드는 중…' : '만들기',
            onTap: _saving ? () {} : _submit,
            filled: true,
          ),
          SizedBox(height: 12),
          Text(
            '만들면 14일 동안 쓸 수 있어요. 코드는 자동으로 복사돼요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
