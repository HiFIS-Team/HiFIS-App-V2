part of 'my_task_section.dart';

/// 적을 수 있는 글자 수 — 서버 `MyTask.content` 가 200자다
const _contentMax = 60;

/// 업무 추가 — 오른쪽에서 밀려 들어오는 화면
///
/// **팝업이 아니다.** 여러 줄을 쌓아 두고 한 번에 만드는 자리라
/// 팝업으로는 좁다 (프로젝트 만들기와 같은 방식 — `showFullPage`).
///
/// ## 요일을 하나씩 훑는다 (2026-08-20 요청)
///
/// **본인 근무일 첫 요일부터 마지막까지** 한 칸씩 넘어가며 담는다.
///
/// ```
/// 월  적기 …            → 다음
/// 화  [세탁 ☑] [청소 ☐]  + 적기 → 다음      ← 앞 요일에 담은 것을 체크로 고른다
/// …
/// 금  …                 → 추가
/// ```
///
/// 앞 요일에 담은 것을 체크로 고르는 것이 핵심이다 — **중복되는 건 중복되게,
/// 새로운 건 새롭게** 담긴다. 같은 이름이 여러 요일에 걸리면 서버가 요일을
/// 합쳐 **한 줄**로 만든다 (두 줄이면 어느 쪽을 체크했는지 알 수 없다).
///
/// 도는 요일은 **근무일뿐이다.** 쉬는 날은 넣는 것이 선택이라 여기서 안 묻고,
/// 넣고 싶으면 만든 뒤 수정에서 요일을 더한다.
class _AddTaskScreen extends StatefulWidget {
  const _AddTaskScreen();

  @override
  State<_AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<_AddTaskScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// 훑을 요일 — **본인 근무일**을 차례대로.
  ///
  /// 근무 설정을 아직 안 한 사람은 이레 다 돈다 — 그 사람은 서버도 전부
  /// 근무일로 보므로(`_is_workday`) 어느 요일이든 비면 누락이다.
  static final _stepDays = () {
    final mine = currentUser?.workDays ?? const <int>[];
    return (mine.isEmpty ? [...everyWeekday] : [...mine])..sort();
  }();

  /// 지금 몇 번째 요일인가
  int _step = 0;

  /// 업무 이름 → 걸리는 요일. **화면 전체가 이 하나를 채운다**
  final _plan = <String, Set<int>>{};

  int get _day => _stepDays[_step];
  bool get _last => _step == _stepDays.length - 1;

  static const _dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  String get _dayName => _dayNames[_day - 1];

  /// 이 요일에 걸린 업무들 (담은 차례대로)
  List<String> get _todays => [
    for (final e in _plan.entries)
      if (e.value.contains(_day)) e.key,
  ];

  /// 앞 요일에서 담았는데 **이 요일에는 아직 안 건** 것들 — 체크로 고른다
  List<String> get _others => [
    for (final e in _plan.entries)
      if (!e.value.contains(_day)) e.key,
  ];

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

  /// 입력칸의 글을 이 요일에 담는다 — 칸을 비우고 커서를 남겨서
  /// 엔터만 계속 눌러 여러 줄을 이어 적을 수 있다
  void _stage() {
    if (_value.isEmpty) return;
    setState(() {
      _plan.putIfAbsent(_value, () => <int>{}).add(_day);
      _text.clear();
    });
    _focus.requestFocus();
  }

  /// 앞 요일 것을 이 요일에도 걸거나 뺀다
  void _toggle(String content) {
    setState(() {
      final days = _plan[content];
      if (days == null) return;
      if (!days.remove(_day)) days.add(_day);
      // 어느 요일에도 안 걸리면 목록에서 뺀다 — 영영 안 뜨는 업무가 된다
      if (days.isEmpty) _plan.remove(content);
    });
  }

  /// 적다 만 글도 같이 담는다 — 엔터를 안 누르고 바로 넘기는 사람이 많다
  void _flush() {
    if (_value.isEmpty) return;
    _plan.putIfAbsent(_value, () => <int>{}).add(_day);
    _text.clear();
  }

  void _next() {
    setState(() {
      _flush();
      _step++;
    });
    _focus.requestFocus();
  }

  void _back() {
    setState(() {
      _flush();
      _step--;
    });
  }

  void _submit() {
    _flush();
    if (_plan.isEmpty) return;
    Navigator.pop(context, {
      for (final e in _plan.entries) e.key: e.value.toList()..sort(),
    });
  }

  /// 지금까지 담은 업무 수 — 마지막 칸의 버튼에 쓴다
  int get _count =>
      _plan.length + (_value.isEmpty || _plan.containsKey(_value) ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 지금 어느 요일을 담고 있는지 — 이 화면에서 제일 먼저 읽혀야 한다
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$_dayName요일', style: AppTextStyles.title2),
            const SizedBox(width: 8),
            Text(
              '${_step + 1} / ${_stepDays.length}',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            // 폰은 헤더 뒤로가기가 **화면을 통째로 닫는다** — 앞 요일로
            // 돌아갈 길이 여기 없으면 처음부터 다시 해야 한다
            if (!isDesktop && _step > 0)
              Pressable(
                onTap: _back,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    '이전',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 20),
        if (_todays.isEmpty && _others.isEmpty)
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
          ),
        if (_todays.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Text(
              '$_dayName요일 업무 ${_todays.length}개',
              style: AppTextStyles.label,
            ),
          ),
          for (var i = 0; i < _todays.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _StagedRow(text: _todays[i], onRemove: () => _toggle(_todays[i])),
          ],
        ],
        // **앞 요일에 담은 것** — 체크하면 이 요일에도 걸린다.
        // 같은 이름을 다시 적을 필요가 없다
        if (_others.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Text('다른 요일에 담은 것', style: AppTextStyles.label),
          ),
          for (var i = 0; i < _others.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PickRow(
              text: _others[i],
              days: weekdayLabel(_plan[_others[i]]!.toList()..sort()),
              onTap: () => _toggle(_others[i]),
            ),
          ],
        ],
      ],
    );

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: '업무 추가',
        // 마지막 요일에서만 만든다 — 그 전까지는 다음 요일로 넘어간다.
        // **비워 두고 넘어가도 된다** (근무일이면 그날이 누락이라는 뜻이다)
        bottomBar: GlassBottomButton(
          label: _last ? (_count > 1 ? '$_count개 추가' : '추가') : '다음',
          active: _last ? _count > 0 : true,
          onPressed: _last ? _submit : _next,
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
                    // 첫 요일에서만 취소다 — 그다음부터는 앞 요일로 돌아간다
                    label: _step == 0 ? '취소' : '이전',
                    onTap: _step == 0 ? () => Navigator.pop(context) : _back,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: _last ? (_count > 1 ? '$_count개 추가' : '추가') : '다음',
                    filled: _last ? _count > 0 : true,
                    onTap: _last ? _submit : _next,
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

/// 앞 요일에 담은 업무 — **누르면 이 요일에도 걸린다**
///
/// 같은 이름을 요일마다 다시 적게 하면 오타 하나로 두 줄이 된다
/// (서버가 막지만 그 전에 손이 더 간다). 체크로 고르는 편이 빠르다.
class _PickRow extends StatelessWidget {
  const _PickRow({required this.text, required this.days, required this.onTap});

  final String text;

  /// 지금까지 걸린 요일 — `월·수` (어디에 넣었는지가 보여야 판단이 된다)
  final String days;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        // 담긴 것(`_StagedRow`)과 갈리게 테두리만 두른다 — 회색 면을 또
        // 쓰면 이 요일에 든 것과 안 든 것이 한눈에 안 갈린다
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.circle, size: 22, color: AppColors.gray300),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            days,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 수정·삭제 폼이 돌려주는 값
class _RequestResult {
  const _RequestResult({this.reason = '', this.content, this.weekdays});

  /// 결재 사유 — **바로 고치는 길에서는 빈 문자열**이다 (안 묻는다)
  final String reason;

  /// 고치겠다는 내용 — 삭제면 null
  final String? content;

  /// 고치겠다는 요일 — 삭제면 null. **내용과 따로 고칠 수 있다**
  final List<int>? weekdays;
}

/// 누락 사유서 폼 (2026-08-21)
///
/// 수정·삭제 신청과 **같은 모양**이다 — 같은 자리에서 올리는 문서라
/// 생김새가 갈리면 안 된다.
///
/// **반려된 것은 다시 낼 수 있다.** 그때는 반려 사유를 위에 보여준다 —
/// 무엇을 고쳐 적어야 하는지 모르면 같은 것을 또 내게 된다.
class _ExcuseCard extends StatefulWidget {
  const _ExcuseCard({required this.miss});

  final MyTaskMiss miss;

  @override
  State<_ExcuseCard> createState() => _ExcuseCardState();
}

class _ExcuseCardState extends State<_ExcuseCard> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reason.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final miss = widget.miss;
    return _FormCard(
      title: '누락 사유서',
      hint: '대표님이 승인하면 깎인 점수가 되돌아와요.',
      confirmLabel: '제출',
      enabled: _reason.text.trim().isNotEmpty,
      onConfirm: _submit,
      body: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${miss.date.month}월 ${miss.date.day}일',
                style: AppTextStyles.body1,
              ),
              const SizedBox(height: 4),
              Text(
                miss.contents.join(' · '),
                style: AppTextStyles.caption.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        // 반려됐던 것이면 왜 반려됐는지 — 안 보여주면 같은 것을 또 낸다
        if (miss.rejectReason != null && miss.rejectReason!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Label('반려 사유'),
          Text(
            miss.rejectReason!,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.error,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Label('사유'),
        _Field(
          controller: _reason,
          autofocus: true,
          hintText: '예) 그날 정전으로 세탁기를 못 돌렸어요',
          maxLength: _contentMax,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// 업무 수정·삭제 폼 — 결재로 갈 때와 바로 갈 때가 **같은 모양**이다
///
/// 아직 한 번도 체크 안 한 업무는 [approval] 이 false 로 온다. 그때는
/// **사유 칸이 없다** — 결재가 없으니 사유를 읽을 사람도 없다.
class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.task,
    required this.type,
    this.approval = true,
  });

  final MyTask task;
  final MyTaskRequestType type;

  /// 대표 결재를 타는가 — false 면 누르는 즉시 반영된다
  final bool approval;

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
    if (widget.approval && _reason.text.trim().isEmpty) return false;
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
    title: widget.approval ? (_isEdit ? '업무 수정 신청' : '업무 삭제 신청') : '업무 수정',
    hint: widget.approval ? '대표님이 승인해야 반영돼요.' : '아직 한 번도 안 한 업무라 바로 고칠 수 있어요.',
    confirmLabel: widget.approval ? '신청' : '저장',
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
      ] else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(widget.task.content, style: AppTextStyles.body1),
        ),
      // 결재로 갈 때만 사유를 묻는다 — 바로 고치는 길에는 읽을 사람이 없다
      if (widget.approval) ...[
        const SizedBox(height: 14),
        _Label('사유'),
        _Field(
          controller: _reason,
          autofocus: !_isEdit,
          hintText: _isEdit ? '예) 이름이 헷갈려요' : '예) 이제 안 하는 일이에요',
          maxLength: _contentMax,
          onSubmitted: (_) => _submit(),
        ),
      ],
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
