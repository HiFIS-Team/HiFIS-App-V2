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
    Navigator.pop(context, all);
  }

  int get _count => _staged.length + (_value.isEmpty ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매일 할 일을 적어주세요. 하루에 한 번씩 체크해요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: true,
                  hintText: '예) 탈의실 향기 확인',
                  maxLength: _contentMax,
                  onSubmitted: (_) => _stage(),
                ),
              ),
              const SizedBox(width: 8),
              // 한 줄 더 적을 때 누른다 — 엔터와 같은 일을 한다
              Pressable(
                onTap: _stage,
                scale: 0.94,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _value.isEmpty
                        ? AppColors.gray100
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: _value.isEmpty ? AppColors.gray400 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          for (var i = 0; i < _staged.length; i++) ...[
            const SizedBox(height: 8),
            _StagedRow(
              text: _staged[i],
              onRemove: () => setState(() => _staged.removeAt(i)),
            ),
          ],
        ],
      ),
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

    // 데스크톱은 가운데 모달 — `showFullPage` 가 틀을 씌운다
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text('업무 추가', style: AppTextStyles.title3),
          ),
          body,
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
                  label: _count > 1 ? '$_count개 추가' : '추가',
                  filled: _count > 0,
                  onTap: _submit,
                ),
              ),
            ],
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
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.body2)),
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
  const _RequestResult({required this.reason, this.content});

  final String reason;

  /// 고치겠다는 내용 — 삭제면 null
  final String? content;
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

  bool get _isEdit => widget.type == MyTaskRequestType.edit;

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
    // 안 바꿨으면 올릴 이유가 없다 — 대표가 무엇을 승인하는지 알 수 없다
    return next.isNotEmpty && next != widget.task.content;
  }

  void _submit() {
    if (!_ready) return;
    Navigator.pop(
      context,
      _RequestResult(
        reason: _reason.text.trim(),
        content: _isEdit ? _content.text.trim() : null,
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
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
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
