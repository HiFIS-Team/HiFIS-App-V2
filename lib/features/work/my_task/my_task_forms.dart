part of 'my_task_section.dart';

/// 적을 수 있는 글자 수 — 서버 `MyTask.content` 가 200자다
const _contentMax = 60;

/// 업무 추가 — 오른쪽에서 밀려 들어오는 화면
///
/// **팝업이 아니다.** 여러 줄을 쌓아 두고 한 번에 만드는 자리라
/// 팝업으로는 좁다 (프로젝트 만들기와 같은 방식 — `showFullPage`).
class _AddTaskScreen extends StatefulWidget {
  const _AddTaskScreen();

  @override
  State<_AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<_AddTaskScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// 아직 안 만든 줄들 — `추가` 를 눌러야 서버로 간다
  final _staged = <String>[];

  /// 돌아오는 요일 — **기본은 매일**이라 예전과 같게 보인다.
  /// 한 번에 담은 줄들에 **다 같이** 걸린다 (서버 `MyTaskCreate.weekdays`)
  final _days = <int>{...everyWeekday};

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _value => _text.text.trim();

  /// 입력칸의 글을 아래 목록으로 옮긴다 — 칸을 비우고 커서를 남겨서
  /// 엔터만 계속 눌러 여러 줄을 이어 적을 수 있다
  void _stage() {
    if (_value.isEmpty) return;
    setState(() {
      _staged.add(_value);
      _text.clear();
    });
    _focus.requestFocus();
  }

  void _submit() {
    // 적다 만 글도 같이 담는다 — 엔터를 안 누르고 바로 만드는 사람이 많다
    final all = [..._staged, if (_value.isNotEmpty) _value];
    if (all.isEmpty) return;
    // 하나도 안 고르면 영영 안 뜨는 업무가 된다 — 그때는 매일로 본다
    // (서버도 같은 규칙이다 — `clean_weekdays`)
    final days = (_days.toList()..sort());
    Navigator.pop(context, (all, days.isEmpty ? everyWeekday : days));
  }

  int get _count => _staged.length + (_value.isEmpty ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 입력칸 — 카드 없이 큼직하게. 이 화면의 주인공이다
        Container(
          padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gray100),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: true,
                  hintText: '예) 탈의실 향기 확인',
                  maxLength: _contentMax,
                  onSubmitted: (_) => _stage(),
                  bare: true,
                ),
              ),
              // 한 줄 더 — 엔터와 같은 일을 한다
              Pressable(
                onTap: _stage,
                scale: 0.92,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _value.isEmpty
                        ? AppColors.gray100
                        : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 19,
                    color: _value.isEmpty ? AppColors.gray400 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            '엔터를 누르면 한 줄씩 더 담을 수 있어요',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
          ),
        ),
        const SizedBox(height: 18),
        // 돌아오는 요일 — 여기서 고른 것이 **담은 줄 전체**에 걸린다
        WeekdayPicker(
          selected: _days,
          onChanged: () => setState(() {}),
          note: '고른 요일에만 목록에 떠요',
        ),
        const SizedBox(height: 20),
        if (_staged.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle,
                    size: 30,
                    color: AppColors.gray300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '적은 업무가 여기 쌓여요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Text('담은 업무 ${_staged.length}개', style: AppTextStyles.label),
          ),
          // **실제 목록과 같은 모양이다** — 만들고 나면 어떻게 보이는지가
          // 여기서 그대로 보인다
          for (var i = 0; i < _staged.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _StagedRow(
              text: _staged[i],
              onRemove: () => setState(() => _staged.removeAt(i)),
            ),
          ],
        ],
      ],
    );

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: '업무 추가',
        bottomBar: GlassBottomButton(
          label: _count > 1 ? '$_count개 추가' : '추가',
          active: _count > 0,
          onPressed: _submit,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            GlassBottomButton.inset(context),
          ),
          children: [body],
        ),
      );
    }

    // 데스크톱은 가운데 모달 — `showFullPage` 의 틀은 **자기 Scaffold 를 가진
    // 화면**을 기대한다. 맨 Column 을 넣으면 Material 이 없어서 TextField 가
    // 죽는다 (실제로 겪었다).
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 18),
                  child: Text('업무 추가', style: AppTextStyles.title3),
                ),
                body,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 22),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '취소',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: _count > 1 ? '$_count개 추가' : '추가',
                    filled: _count > 0,
                    onTap: _submit,
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

/// 아직 안 만든 줄 — 오른쪽 X 로 뺀다
class _StagedRow extends StatelessWidget {
  const _StagedRow({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 9, 12),
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        // 실제 목록의 체크 자리와 같은 크기·색이라 미리보기가 된다
        Icon(CupertinoIcons.circle, size: 22, color: AppColors.gray300),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Pressable(
          onTap: onRemove,
          scale: 0.9,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              CupertinoIcons.xmark,
              size: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 수정·삭제 결재 폼이 돌려주는 값
class _RequestResult {
  const _RequestResult({required this.reason, this.content, this.weekdays});

  final String reason;

  /// 고치겠다는 내용 — 삭제면 null
  final String? content;

  /// 고치겠다는 요일 — 삭제면 null. **내용과 따로 고칠 수 있다**
  final List<int>? weekdays;
}

/// 수정·삭제 신청 — **대표가 승인해야 실제로 바뀐다**
class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.task, required this.type});

  final MyTask task;
  final MyTaskRequestType type;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late final _content = TextEditingController(text: widget.task.content);
  final _reason = TextEditingController();

  /// 지금 걸린 요일에서 시작한다 — 안 건드리면 그대로 간다
  late final _days = <int>{...widget.task.weekdays};

  bool get _isEdit => widget.type == MyTaskRequestType.edit;

  /// 요일을 바꿨나 — 차례를 맞춰 견준다 (서버도 정렬해서 준다)
  bool get _daysChanged {
    final now = _days.toList()..sort();
    return now.join(',') != widget.task.weekdays.join(',');
  }

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _content.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _ready {
    if (_reason.text.trim().isEmpty) return false;
    if (!_isEdit) return true;
    final next = _content.text.trim();
    if (next.isEmpty) return false;
    // 안 바꿨으면 올릴 이유가 없다 — 대표가 무엇을 승인하는지 알 수 없다.
    // **내용·요일 중 하나만 바꿔도 된다** (2026-08-20)
    return next != widget.task.content || _daysChanged;
  }

  void _submit() {
    if (!_ready) return;
    // 하나도 안 고르면 매일 — 추가 화면과 같은 규칙이다
    final days = _days.toList()..sort();
    Navigator.pop(
      context,
      _RequestResult(
        reason: _reason.text.trim(),
        content: _isEdit ? _content.text.trim() : null,
        weekdays: _isEdit ? (days.isEmpty ? everyWeekday : days) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: _isEdit ? '업무 수정 신청' : '업무 삭제 신청',
    hint: '대표님이 승인해야 반영돼요.',
    confirmLabel: '신청',
    enabled: _ready,
    onConfirm: _submit,
    body: [
      if (_isEdit) ...[
        _Label('고칠 내용'),
        _Field(
          controller: _content,
          autofocus: true,
          hintText: '업무 내용',
          maxLength: _contentMax,
        ),
        const SizedBox(height: 14),
        _Label('돌아오는 요일'),
        WeekdayPicker(
          selected: _days,
          onChanged: () => setState(() {}),
          note: '고른 요일에만 목록에 떠요',
        ),
        const SizedBox(height: 14),
      ] else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(widget.task.content, style: AppTextStyles.body1),
        ),
        const SizedBox(height: 14),
      ],
      _Label('사유'),
      _Field(
        controller: _reason,
        autofocus: !_isEdit,
        hintText: _isEdit ? '예) 이름이 헷갈려요' : '예) 이제 안 하는 일이에요',
        maxLength: _contentMax,
        onSubmitted: (_) => _submit(),
      ),
    ],
  );
}

/// 팝업 껍데기 — 제목·안내·내용·버튼 두 개
///
/// 추가와 수정·삭제가 같은 모양이어야 해서 한 곳에 둔다.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.enabled,
    required this.onConfirm,
    required this.body,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final bool enabled;
  final VoidCallback onConfirm;

  /// 제목 아래 들어가는 입력칸들
  final List<Widget> body;

  @override
  Widget build(BuildContext context) => Container(
    width: dialogWidth(context, 320),
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.title3),
        const SizedBox(height: 6),
        Text(hint, style: AppTextStyles.caption.copyWith(height: 1.5)),
        const SizedBox(height: 14),
        ...body,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '취소',
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                // 채워진 파란 버튼이 곧 '지금 누를 수 있다'는 표시다 —
                // 빈 칸이 있으면 회색으로 두고 눌러도 아무 일이 없다
                // (`_submit` 이 먼저 되돌아온다). '기타' 입력 팝업과 같은 방식.
                label: confirmLabel,
                filled: enabled,
                onTap: onConfirm,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(text, style: AppTextStyles.caption),
  );
}

/// 회색 면 입력칸 — 팝업 안에서 쓰는 모양은 여기 하나다
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hintText,
    required this.maxLength,
    this.autofocus = false,
    this.onSubmitted,
    this.focusNode,
    this.bare = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  /// 회색 면 없이 글자만 — 바깥에서 이미 칸을 그렸을 때
  final bool bare;

  @override
  Widget build(BuildContext context) => Container(
    padding: bare
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: bare
        ? null
        : BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLength: maxLength,
      style: AppTextStyles.body1,
      cursorColor: AppColors.primary,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
        border: InputBorder.none,
        isCollapsed: true,
        counterText: '',
      ),
    ),
  );
}
