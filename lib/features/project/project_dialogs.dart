part of 'project_screen.dart';

// ── 팝업 ──

/// 담당자 고르기 — 고르면 이름, '담당자 없음'이면 빈 문자열, 취소면 null
Future<String?> _pickMember(
  BuildContext context, {
  required List<String> names,
  String? current,
}) {
  return showAppDialog<String>(
    context,
    (context) => Container(
      width: dialogWidth(context, 280),
      padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
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
            child: Text('담당자 선택', style: AppTextStyles.title3),
          ),
          SizedBox(height: 8),
          // 명단 전체를 세우면 팝업이 화면 밖으로 나간다 — 높이만 막고 안에서 스크롤
          ScrollBox(
            maxHeight: kListBoxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in names)
                  _PickRow(
                    name: name,
                    role: staffOf(name).role,
                    selected: name == current,
                    onTap: () => Navigator.pop(context, name),
                  ),
              ],
            ),
          ),
          Divider(height: 12, color: AppColors.divider),
          Pressable(
            onTap: () => Navigator.pop(context, ''),
            scale: 0.98,
            pressedColor: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Text(
              '담당자 없음',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 담당자 목록 한 줄
class _PickRow extends StatelessWidget {
  _PickRow({
    required this.name,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String role;
  final bool selected;
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
          Avatar(name: name, size: 30),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(role, style: AppTextStyles.caption),
          if (selected) ...[
            SizedBox(width: 8),
            Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

/// 기한 연장 결재 — 승인이든 반려든 사유를 받아 돌려준다 (취소면 null)
Future<String?> _showDecisionDialog(
  BuildContext context, {
  required _Project project,
  required bool approve,
}) {
  return showAppDialog<String>(
    context,
    (context) => _DecisionDialog(project: project, approve: approve),
  );
}

class _DecisionDialog extends StatefulWidget {
  _DecisionDialog({required this.project, required this.approve});

  final _Project project;
  final bool approve;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(
        context,
        widget.approve ? '승인 사유를 입력해주세요' : '반려 사유를 입력해주세요',
      );
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final project = widget.project;
    final request = project.request!;
    final accent = approve ? AppColors.primary : AppColors.error;
    final empty = _reason.text.trim().isEmpty;

    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(approve ? '기한 연장 승인' : '기한 연장 반려', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            approve ? '승인하면 마감일이 바로 바뀝니다' : '반려하면 지금 마감일 그대로 갑니다',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          // 무엇을 결재하는지 다시 보여준다
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 삭제는 견줄 값이 없어서 종류 이름이 그 자리에 선다
                    Text(
                      _requestChange(project, request) ??
                          _requestLabel(request.type),
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${request.requester} 신청',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  request.reason,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: approve ? '승인 사유를 적어주세요' : '반려 사유를 적어주세요',
            lines: 3,
          ),
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
              Pressable(
                onTap: _submit,
                scale: 0.97,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    // 사유를 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                    color: empty ? AppColors.gray200 : accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    approve ? '승인' : '반려',
                    style: AppTextStyles.body2.copyWith(
                      color: empty ? AppColors.gray500 : Colors.white,
                      fontWeight: FontWeight.w700,
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

/// 기한 연장 신청 폼 — 새 마감일과 사유를 받아 신청을 돌려준다
Future<_Extension?> _showExtensionDialog(
  BuildContext context,
  _Project project,
) {
  return showAppDialog<_Extension>(
    context,
    (context) => _ExtensionDialog(project: project),
  );
}

class _ExtensionDialog extends StatefulWidget {
  _ExtensionDialog({required this.project});

  final _Project project;

  @override
  State<_ExtensionDialog> createState() => _ExtensionDialogState();
}

class _ExtensionDialogState extends State<_ExtensionDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  /// 기본은 기존 마감에서 일주일 뒤 (이미 지났으면 오늘부터 일주일)
  late DateTime _due = _later(widget.project.due).add(Duration(days: 7));

  static DateTime _later(DateTime due) {
    final now = DateTime.now();
    return due.isAfter(now) ? due : now;
  }

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    // 연장이므로 기존 마감(또는 오늘) 다음 날부터 고를 수 있다
    final first = _later(widget.project.due).add(Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: first,
      lastDate: DateTime(first.year + 3),
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

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, '연장 사유를 입력해주세요');
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(
      context,
      _Extension(
        requester: me,
        due: _due,
        reason: reason,
        time: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final overdue = _dday(project.due) < 0;

    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기한 연장 신청', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '승인되면 마감일이 바뀌고, 반려되면 지금 마감일 그대로 갑니다',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('현재 마감', style: AppTextStyles.label),
              ),
              Text(
                _date(project.due),
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: overdue ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              if (overdue) ...[
                SizedBox(width: 6),
                Text(
                  '${-_dday(project.due)}일 지남',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('연장 마감', style: AppTextStyles.label),
              ),
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
              _DdayBadge(dday: _dday(_due), phase: _Phase.running),
            ],
          ),
          SizedBox(height: 14),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: '왜 연장이 필요한가요?',
            lines: 3,
          ),
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
              Pressable(
                onTap: _submit,
                scale: 0.97,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    // 사유를 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                    color: _reason.text.trim().isEmpty
                        ? AppColors.gray200
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '신청',
                    style: AppTextStyles.body2.copyWith(
                      color: _reason.text.trim().isEmpty
                          ? AppColors.gray500
                          : Colors.white,
                      fontWeight: FontWeight.w700,
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

/// 프로젝트 수정 신청 창 — 이름·설명·색만 바꾼다
///
/// **기한은 여기 없다.** 기한 연장이 이미 제 창을 갖고 있어서, 여기에 또 두면
/// 같은 일을 두 길로 올리게 된다. 담당자·참여 멤버도 없다 — 사람을 빼면 그
/// 사람이 바로 잠기고 할 일 담당도 비워져서 성격이 다르다 (2026-08-14 결정).
///
/// 돌려주는 것은 **바뀐 칸만** 담은 map 이다 (`title` · `purpose` · `color`).
/// 안 바꾼 칸을 같이 보내면 결재하는 쪽이 무엇이 바뀌는지 못 가린다.
Future<({Map<String, String> payload, String reason})?> _showEditDialog(
  BuildContext context,
  _Project project,
) {
  return showAppDialog<({Map<String, String> payload, String reason})>(
    context,
    (context) => _EditDialog(project: project),
  );
}

class _EditDialog extends StatefulWidget {
  _EditDialog({required this.project});

  final _Project project;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name = TextEditingController(text: widget.project.name);
  late final _desc = TextEditingController(text: widget.project.desc);
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  late Color _color = widget.project.color;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _desc, _reason]) {
      c.addListener(() => setState(() {}));
    }
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  /// 실제로 바뀐 칸만 — 안 바꾼 것을 보내면 결재 카드가 다 바뀐 것처럼 보인다
  Map<String, String> get _changes {
    final project = widget.project;
    return {
      if (_name.text.trim() != project.name) 'title': _name.text.trim(),
      if (_desc.text.trim() != project.desc) 'purpose': _desc.text.trim(),
      if (_color != project.color) 'color': _hexOf(_color),
    };
  }

  bool get _ready =>
      _changes.isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _reason.text.trim().isNotEmpty;

  void _submit() {
    if (_name.text.trim().isEmpty) {
      AppToast.show(context, '프로젝트 이름을 입력해주세요');
      return;
    }
    if (_changes.isEmpty) {
      AppToast.show(context, '바뀐 것이 없어요');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      AppToast.show(context, '수정 사유를 입력해주세요');
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(context, (payload: _changes, reason: _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프로젝트 수정 신청', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text('승인되면 바뀌고, 반려되면 지금 내용 그대로 갑니다', style: AppTextStyles.caption),
          SizedBox(height: 16),
          _Field(controller: _name, hint: '프로젝트 이름'),
          SizedBox(height: 10),
          _Field(controller: _desc, hint: '무엇을 하는 프로젝트인가요?', lines: 2),
          SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text('색상', style: AppTextStyles.label),
              ),
              for (final color in _projectPalette)
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
                        ? Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: '왜 고치나요? (대표가 이걸 보고 결재해요)',
            lines: 2,
          ),
          SizedBox(height: 18),
          _DialogActions(label: '신청', ready: _ready, onSubmit: _submit),
        ],
      ),
    );
  }
}

/// 다이얼로그 아래 `취소 · 확인` 줄 — 연장·수정 창이 같이 쓴다
///
/// [ready] 가 false 면 확인 버튼이 흐리다. 눌러도 막히지 않고 [onSubmit] 이
/// 무엇이 빠졌는지 알려 준다 — 흐린 버튼이 왜 안 되는지 모르면 답답하다.
class _DialogActions extends StatelessWidget {
  _DialogActions({
    required this.label,
    required this.ready,
    required this.onSubmit,
    this.destructive = false,
  });

  final String label;
  final bool ready;
  final VoidCallback onSubmit;

  /// true 면 확인 버튼이 빨갛다 (삭제 신청)
  final bool destructive;

  @override
  Widget build(BuildContext context) => Row(
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
      Pressable(
        onTap: onSubmit,
        scale: 0.97,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: !ready
                ? AppColors.gray200
                : destructive
                ? AppColors.error
                : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: ready ? Colors.white : AppColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

/// 프로젝트 삭제 신청 창 — 사유만 받는다
Future<String?> _showDeleteDialog(BuildContext context, _Project project) {
  return showAppDialog<String>(
    context,
    (context) => _DeleteDialog(project: project),
  );
}

class _DeleteDialog extends StatefulWidget {
  _DeleteDialog({required this.project});

  final _Project project;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _reasonFocus.requestFocus();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, '삭제 사유를 입력해주세요');
      _reasonFocus.requestFocus();
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프로젝트 삭제 신청', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '승인되면 할 일·타임라인·점수까지 같이 지워집니다.'
            ' 승인 전까지는 그대로 있어요',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: '왜 지우나요? (대표가 이걸 보고 결재해요)',
            lines: 3,
          ),
          SizedBox(height: 18),
          _DialogActions(
            label: '삭제 신청',
            ready: _reason.text.trim().isNotEmpty,
            destructive: true,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

/// 인원 추가 신청 창 — **넣기만 한다** (2026-08-19)
///
/// 빼는 자리를 안 둔 이유가 있다. 참여 멤버에서 빼면 그 사람에게 걸린
/// 할 일(`_Todo.assignee`)이 붕 뜨고, 무엇으로 대신할지가 안 정해졌다.
/// 서버도 같은 이유로 `addIds` 만 받는다.
///
/// **삭제 신청 창과 같은 틀이다** — 사유 칸과 버튼이 그대로고, 위에
/// 고르는 줄만 하나 얹었다.
Future<({List<String> names, String reason})?> _showMembersDialog(
  BuildContext context,
  _Project project,
) {
  return showAppDialog<({List<String> names, String reason})>(
    context,
    (context) => _MembersDialog(project: project),
  );
}

class _MembersDialog extends StatefulWidget {
  _MembersDialog({required this.project});

  final _Project project;

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();

  /// 이번에 넣을 사람 — 이름이다 (폼이 아직 이름을 사람 키로 쓴다)
  final _picked = <String>[];

  /// 고를 수 있는 사람 — **이미 참여 중인 사람은 뺀다.**
  /// 넣어 봐야 서버가 `ALREADY_MEMBER` 로 되돌린다
  late final _candidates = [
    for (final staff in staffList)
      if (!widget.project.members.contains(staff.name)) staff.name,
  ];

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_picked.isEmpty) {
      AppToast.show(context, '넣을 사람을 골라주세요');
      return;
    }
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, '추가 사유를 입력해주세요');
      _reasonFocus.requestFocus();
      return;
    }
    // 명단 순서대로 — 아바타 줄이 화면마다 같은 순서로 보인다
    Navigator.pop(context, (
      names: [
        for (final staff in staffList)
          if (_picked.contains(staff.name)) staff.name,
      ],
      reason: reason,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('인원 추가 신청', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '승인되면 참여 멤버로 들어옵니다. 승인 전까지는 그대로예요',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          if (_candidates.isEmpty)
            Text('더 넣을 사람이 없어요', style: AppTextStyles.caption)
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in _candidates)
                      _PickChip(
                        name: name,
                        on: _picked.contains(name),
                        onTap: () => setState(() {
                          if (!_picked.remove(name)) _picked.add(name);
                        }),
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 14),
          _Field(
            controller: _reason,
            focusNode: _reasonFocus,
            hint: '왜 넣나요? (대표가 이걸 보고 결재해요)',
            lines: 3,
          ),
          SizedBox(height: 18),
          _DialogActions(
            label: '추가 신청',
            ready: _picked.isNotEmpty && _reason.text.trim().isNotEmpty,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

/// 고르는 알약 하나 — 누르면 켜고 꺼진다
class _PickChip extends StatelessWidget {
  const _PickChip({required this.name, required this.on, required this.onTap});

  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          name,
          style: AppTextStyles.body2.copyWith(
            color: on ? Colors.white : AppColors.textSecondary,
            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
