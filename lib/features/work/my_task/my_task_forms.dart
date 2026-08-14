part of 'my_task_section.dart';

/// 적을 수 있는 글자 수 — 서버 `MyTask.content` 가 200자다
const _contentMax = 60;

/// 업무 추가 — **결재 없이 바로 들어간다**
class _AddTaskCard extends StatefulWidget {
  const _AddTaskCard();

  @override
  State<_AddTaskCard> createState() => _AddTaskCardState();
}

class _AddTaskCardState extends State<_AddTaskCard> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _value => _text.text.trim();

  void _submit() {
    if (_value.isEmpty) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: '업무 추가',
    hint: '매일 할 일을 적어주세요. 하루에 한 번씩 체크해요.',
    confirmLabel: '추가',
    enabled: _value.isNotEmpty,
    onConfirm: _submit,
    body: [
      _Field(
        controller: _text,
        autofocus: true,
        hintText: '예) 탈의실 향기 확인',
        maxLength: _contentMax,
        onSubmitted: (_) => _submit(),
      ),
    ],
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
  });

  final TextEditingController controller;
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
