part of 'project_screen.dart';

/// 새 프로젝트 만들기 — 만들면 그 프로젝트를 돌려준다
Future<_Project?> _showProjectComposer(BuildContext context) {
  // 폰은 팝업이 답답해서 오른쪽에서 밀려 들어오는 페이지로 연다
  if (!isDesktop) {
    return Navigator.push<_Project>(
      context,
      CupertinoPageRoute(builder: (_) => _ProjectComposer(phone: true)),
    );
  }
  return showAppDialog<_Project>(context, (context) => _ProjectComposer());
}

class _ProjectComposer extends StatefulWidget {
  _ProjectComposer({this.phone = false});

  /// 폰은 팝업이 아니라 밀려 들어오는 페이지로 뜬다
  final bool phone;

  @override
  State<_ProjectComposer> createState() => _ProjectComposerState();
}

class _ProjectComposerState extends State<_ProjectComposer> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _nameFocus = FocusNode();

  /// 기본 마감은 2주 뒤
  late DateTime _due = DateTime.now().add(Duration(days: 14));

  /// 참여 멤버 — 직원·점장은 본인이 기본으로 든다.
  ///
  /// **대표·관리자는 안 든다.** 프로젝트를 만들어 맡기는 자리라 본인이
  /// 참여자도 담당자도 아니다 (그래서 [_owner] 도 비운 채로 시작한다).
  final _members = <String>[if (myRole.doesFieldWork) me];

  /// 만들면서 같이 등록할 할 일
  final _todos = <_Todo>[];

  /// 맡을 사람 — 비어 있으면 아직 안 골랐다는 뜻이다
  String _owner = myRole.doesFieldWork ? me : '';

  Color _color = AppColors.primary;

  /// 프로젝트를 구분하는 색 — 빨강은 D-day 배지와 헷갈려서 뺐다
  static const _palette = [
    AppColors.primary,
    AppColors.violet,
    AppColors.teal,
    AppColors.success,
    AppColors.warning,
    Color(0xFF8B95A1),
  ];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    // 페이지가 밀려 들어오는 중에 키보드가 같이 올라오면 어수선해서
    // 폰에서는 자동 포커스를 두지 않는다
    if (!widget.phone) _nameFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              (AppColors.isDark
                      ? ColorScheme.dark(surface: AppColors.surface)
                      : ColorScheme.light(surface: AppColors.surface))
                  .copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _toggleMember(String name) {
    setState(() {
      if (_members.contains(name)) {
        _members.remove(name);
        // 빠진 사람이 맡기로 한 자리는 정말로 비워둔다 —
        // 본인으로 되돌리면 대표가 만든 프로젝트의 담당이 대표가 된다
        if (_owner == name) _owner = '';
        for (final todo in _todos) {
          if (todo.assignee == name) todo.assignee = null;
        }
      } else {
        _members.add(name);
      }
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, '프로젝트 이름을 입력해주세요');
      _nameFocus.requestFocus();
      return;
    }
    if (_owner.isEmpty) {
      AppToast.show(context, '담당자를 정해주세요');
      return;
    }
    final now = DateTime.now();
    Navigator.pop(
      context,
      _Project(
        name: name,
        desc: _desc.text.trim(),
        colorHex: _hexOf(_color),
        owner: _owner,
        start: now,
        due: _due,
        // 명단 순서대로 정렬해 두면 아바타 줄이 화면마다 같은 순서로 보인다
        members: [
          for (final staff in staffList)
            if (_members.contains(staff.name)) staff.name,
        ],
        todos: _todos,
        // 타임라인은 서버가 만들면서 '프로젝트를 만들었어요' 를 쌓아 준다
        events: [],
      ),
    );
  }

  /// 폼 본문 — 팝업(데스크톱)과 페이지(폰)가 같이 쓴다
  Widget _form(BuildContext context, int dday) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          controller: _name,
          focusNode: _nameFocus,
          hint: '프로젝트 이름',
          bold: true,
          onSubmitted: _submit,
        ),
        SizedBox(height: 8),
        _Field(controller: _desc, hint: '어떤 프로젝트인가요? (선택)', lines: 2),
        SizedBox(height: 16),
        Row(
          children: [
            SizedBox(width: 62, child: Text('마감일', style: AppTextStyles.label)),
            Pressable(
              onTap: _pickDue,
              scale: 0.97,
              pressedColor: AppColors.gray100,
              borderRadius: BorderRadius.circular(10),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${_due.year}.${_due.month}.${_due.day}',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6),
            _DdayBadge(dday: dday, phase: _Phase.running),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('담당', style: AppTextStyles.label)),
            _AssigneeChip(
              name: _owner.isEmpty ? null : _owner,
              onTap: () async {
                final picked = await _pickMember(
                  context,
                  // **명단 전체에서 고른다.** 참여 멤버 중에서만 고르게 하면
                  // 대표가 프로젝트를 만들 때 멤버부터 넣어야 담당을 고를 수 있다
                  names: [for (final staff in staffList) staff.name],
                  current: _owner.isEmpty ? null : _owner,
                );
                // 담당은 비울 수 없다 (빈 문자열 = 안 고르고 닫음)
                if (picked == null || picked.isEmpty) return;
                setState(() {
                  _owner = picked;
                  // 맡은 사람은 당연히 참여한다
                  if (!_members.contains(picked)) _members.add(picked);
                });
              },
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('색상', style: AppTextStyles.label)),
            for (final color in _palette)
              Pressable(
                onTap: () => setState(() => _color = color),
                scale: 0.9,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: _color == color
                      ? Icon(Icons.check_rounded, size: 15, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        Text('참여 멤버', style: AppTextStyles.label),
        SizedBox(height: 8),
        ScrollBox(
          maxHeight: kChipBoxHeight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final staff in staffList)
                _MemberChip(
                  staff: staff,
                  joined: _members.contains(staff.name),
                  // 나는 담당 기본값이라 빼지 않는다
                  onTap: staff.name == me
                      ? null
                      : () => _toggleMember(staff.name),
                ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Text('할 일', style: AppTextStyles.label),
            SizedBox(width: 6),
            Text(
              '${_todos.length}',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _TodoComposer(
          members: _members,
          onAdd: (text, assignee) =>
              setState(() => _todos.add(_Todo(text: text, assignee: assignee))),
        ),
        for (final todo in _todos)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    todo.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2,
                  ),
                ),
                if (todo.assignee != null) ...[
                  Avatar(name: todo.assignee!, size: 20),
                  SizedBox(width: 6),
                  Text(
                    todo.assignee!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(width: 6),
                Pressable(
                  onTap: () => setState(() => _todos.remove(todo)),
                  scale: 0.9,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 만들기 버튼 (데스크톱 팝업 전용 — 폰은 하단 글래스 버튼을 쓴다)
  Widget _submitButton() {
    final empty = _name.text.trim().isEmpty;

    return Pressable(
      onTap: _submit,
      scale: 0.97,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          // 이름을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
          color: empty ? AppColors.gray200 : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '만들기',
          style: AppTextStyles.body2.copyWith(
            color: empty ? AppColors.gray500 : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dday = _dday(_due);

    // 폰은 팝업 대신 오른쪽에서 밀려 들어오는 페이지로 연다
    if (widget.phone) {
      return PhoneDetailScaffold(
        title: '새 프로젝트',
        // 만들기는 하단 탭바 자리에 글래스 버튼으로 띄운다
        bottomBar: GlassBottomButton(
          label: '만들기',
          active: _name.text.trim().isNotEmpty,
          onPressed: _submit,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            GlassBottomButton.inset(context),
          ),
          children: [
            // 입력칸(gray50)이 회색 배경에 묻히지 않게 흰 카드 위에 올린다
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: AppDecorations.card(),
              child: _form(context, dday),
            ),
          ],
        ),
      );
    }

    return Container(
      width: dialogWidth(context, 460),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      // 할 일을 여러 개 적으면 길어져서 본문만 스크롤되게 높이를 묶는다
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('새 프로젝트', style: AppTextStyles.title2),
            SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _form(context, dday))),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Text(
                    '취소',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _submitButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 생성 폼 입력칸
class _Field extends StatelessWidget {
  _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.lines = 1,
    this.bold = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final bool bold;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDecorations.fieldPadding,
      decoration: AppDecorations.field(),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: bold
            ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
            : AppTextStyles.body2,
        cursorColor: AppColors.primary,
        minLines: lines,
        maxLines: lines,
        keyboardType: lines > 1 ? TextInputType.multiline : null,
        textInputAction: lines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: (_) => onSubmitted?.call(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: (bold ? AppTextStyles.body1 : AppTextStyles.body2)
              .copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 참여 멤버 고르는 알약 (생성 폼)
class _MemberChip extends StatelessWidget {
  _MemberChip({required this.staff, required this.joined, this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? () {},
      scale: onTap == null ? 1 : 0.96,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: staff.name, size: 22),
            SizedBox(width: 6),
            Text(
              staff.name == me ? '나' : staff.name,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: joined ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 참여 멤버 관리 — 직원을 눌러 넣고 뺀 뒤 '추가' 로 확정한다
///
/// **고르는 동안에는 프로젝트를 안 건드린다.** 팝업 안에서만 담아 두고
/// '추가' 를 눌러야 반영한다 — 그래야 '취소' 가 뜻이 있다.
/// (예전에는 누르는 즉시 반영돼서 되돌릴 방법이 없었다.)
void _showMemberManager(
  BuildContext context,
  _Project project,
  VoidCallback onChanged,
) {
  final picked = {...project.members};

  showAppDialog<bool>(
    context,
    (context) => StatefulBuilder(
      builder: (context, setLocal) => Container(
        width: dialogWidth(context, 300),
        padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('참여 멤버', style: AppTextStyles.title3),
            ),
            SizedBox(height: 8),
            // 직원이 늘면 팝업이 화면 밖으로 나간다 — 높이만 막고 안에서 스크롤
            ScrollBox(
              maxHeight: kListBoxHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final staff in staffList)
                    _MemberToggleRow(
                      staff: staff,
                      joined: picked.contains(staff.name),
                      onTap: () {
                        setLocal(() {
                          if (!picked.remove(staff.name)) {
                            picked.add(staff.name);
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '취소',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: '추가',
                    filled: true,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ).then((confirmed) {
    // 바깥을 눌러 닫으면 null 이다 — 취소와 같이 다룬다
    if (confirmed != true) return;
    project.members
      ..clear()
      ..addAll(picked);
    // 빠진 사람이 맡고 있던 할 일은 담당자를 비운다
    for (final todo in project.todos) {
      if (todo.assignee case final name? when !picked.contains(name)) {
        todo.assignee = null;
      }
    }
    onChanged();
  });
}

/// 멤버 관리 한 줄 — 오른쪽 동그라미로 참여 여부를 보여준다
class _MemberToggleRow extends StatelessWidget {
  _MemberToggleRow({
    required this.staff,
    required this.joined,
    required this.onTap,
  });

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Avatar(name: staff.name, size: 32),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              staff.name == me ? '${staff.name} (나)' : staff.name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(staff.role, style: AppTextStyles.caption),
          SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: joined ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: joined ? AppColors.primary : AppColors.gray300,
                width: 1.5,
              ),
            ),
            child: joined
                ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
