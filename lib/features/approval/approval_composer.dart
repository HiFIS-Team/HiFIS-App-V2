part of 'approval_screen.dart';

// ── 결재 올리기 ──

Future<_Draft?> _showComposer(BuildContext context) {
  return showDialog<_Draft>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(
      child: Material(type: MaterialType.transparency, child: _Composer()),
    ),
  );
}

class _Composer extends StatefulWidget {
  _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _body = TextEditingController();
  final _place = TextEditingController();
  final _titleFocus = FocusNode();

  _Kind _kind = _Kind.expense;

  /// 외근·출장, 근무 변경일 때만 쓴다 (기본은 오늘 하루)
  late DateTime _start = DateTime.now();
  late DateTime _end = DateTime.now();

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _body.dispose();
    _place.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// 날짜 고르기 — 일정 화면과 같은 달력을 쓴다
  Future<void> _pick({required bool start}) async {
    final base = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 2),
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
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        // 시작이 끝보다 뒤로 가면 끝도 같이 민다
        if (_end.isBefore(_start)) _end = picked;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '결재 제목을 입력해주세요');
      _titleFocus.requestFocus();
      return;
    }
    final place = _place.text.trim();
    Navigator.pop(
      context,
      _Draft(
        kind: _kind,
        title: title,
        amount: int.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
        body: _body.text.trim(),
        // 기간·장소는 그 종류일 때만 보낸다 — 안 보이는 칸의 값이 따라가면 안 된다
        startDate: _kind.needsWhen ? _start : null,
        endDate: _kind.needsWhen ? _end : null,
        place: _kind.needsWhen && place.isNotEmpty ? place : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = _title.text.trim().isEmpty;

    return Container(
      width: 520,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('결재 올리기', style: AppTextStyles.title2),
            SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('결재 종류', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    // 두 칸씩 끊어 카드로 고른다
                    for (var i = 0; i < _Kind.values.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (var j = i; j < i + 2; j++) ...[
                              if (j > i) SizedBox(width: 8),
                              Expanded(
                                child: _KindCard(
                                  kind: _Kind.values[j],
                                  selected: _kind == _Kind.values[j],
                                  onTap: () =>
                                      setState(() => _kind = _Kind.values[j]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(height: 10),
                    Text('제목', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    _Field(
                      controller: _title,
                      focusNode: _titleFocus,
                      hint: '무엇에 대한 결재인가요?',
                      onSubmitted: _submit,
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Text('금액', style: AppTextStyles.label),
                        SizedBox(width: 4),
                        Text('(선택)', style: AppTextStyles.caption),
                      ],
                    ),
                    SizedBox(height: 8),
                    _Field(
                      controller: _amount,
                      hint: '0',
                      align: TextAlign.right,
                      suffix: '원',
                      digitsOnly: true,
                    ),
                    // 외근·출장, 근무 변경은 언제 어디로 가는지가 결재의 핵심이다.
                    // 나머지 종류에는 이 두 칸이 안 나온다.
                    if (_kind.needsWhen) ...[
                      SizedBox(height: 14),
                      Text('기간', style: AppTextStyles.label),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              value: _start,
                              onTap: () => _pick(start: true),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('~', style: AppTextStyles.body2),
                          ),
                          Expanded(
                            child: _DateField(
                              value: _end,
                              onTap: () => _pick(start: false),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Text('장소', style: AppTextStyles.label),
                          SizedBox(width: 4),
                          Text('(선택)', style: AppTextStyles.caption),
                        ],
                      ),
                      SizedBox(height: 8),
                      _Field(controller: _place, hint: '어디로 가나요?'),
                    ],
                    SizedBox(height: 14),
                    Text('내용', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    _Field(
                      controller: _body,
                      hint: '사유·근거·견적 등 결재에 필요한 내용을 적어주세요',
                      lines: 4,
                    ),
                    SizedBox(height: 14),
                    // 결재선은 아직 못 고른다 — 대표 한 사람에게 올린다
                    // (서버는 여러 명을 순서대로 세울 수 있다, backend-gap.md 48번)
                    Row(
                      children: [
                        Text('결재자', style: AppTextStyles.label),
                        SizedBox(width: 10),
                        if (_defaultApprover case final approver?) ...[
                          Avatar(name: approver.name, size: 24),
                          SizedBox(width: 6),
                          Text(
                            '${approver.name} ${approver.rank.label}',
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          Text(
                            '대표를 찾지 못했어요',
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 14,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
                      // 제목을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                      color: empty ? AppColors.gray200 : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '올리기',
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
      ),
    );
  }
}

/// 결재 종류 카드 — 아이콘 아래 이름, 고르면 파랗게 찬다
class _KindCard extends StatefulWidget {
  _KindCard({required this.kind, required this.selected, required this.onTap});

  final _Kind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_KindCard> createState() => _KindCardState();
}

class _KindCardState extends State<_KindCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : AppColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.gray200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.kind.icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                widget.kind.label,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
