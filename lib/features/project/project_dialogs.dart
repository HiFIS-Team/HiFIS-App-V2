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
                    Text(
                      '${_date(project.due)} → ${_date(request.due)}',
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
