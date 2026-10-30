part of 'my_task_section.dart';

/// 적을 수 있는 글자 수 — 서버 `MyTask.content` 가 200자다
const _contentMax = 60;

/// 업무 추가 — 오른쪽에서 밀려 들어오는 화면
///
/// **팝업이 아니다.** 여러 줄을 쌓아 두고 한 번에 만드는 자리라
/// 팝업으로는 좁다 (프로젝트 만들기와 같은 방식 — `showFullPage`).
///
/// ## 요일을 골라 담는다 (2026-10-27 대표 요청)
///
/// **업무를 적고, 돌아올 요일 칸을 누른다.** 한 화면이다.
///
/// ```
/// 돌아오는 요일   [월][화][수][목][금][토][일]
/// 업무 적기 …     ↑
/// 담은 업무       세탁 · 청소 …            → N개 추가
/// ```
///
/// 예전에는 **근무일을 하루씩 넘기며** 그날 업무를 담았다 (2026-08-20). 요일이
/// 많으면 같은 화면을 대여섯 번 넘겨야 했고, 금요일에만 하는 일 하나를 넣으려
/// 해도 월요일부터 걸어가야 했다.
///
/// 고른 요일은 **담은 업무 전부에** 같이 걸린다 — 월 단위가 날짜를 다루는 것과
/// 같다. 요일이 다른 업무는 한 번 더 추가하면 된다.
///
/// 처음에는 **그 사람 근무일**이 켜져 있다. 쉬는 날에도 하는 일이면 그 칸을
/// 더 누르면 된다.
class _AddTaskScreen extends StatefulWidget {
  const _AddTaskScreen({this.ownerName, this.ownerWorkDays});

  /// 남의 목록에 넣을 때 그 사람 이름 — 대표·관리자끼리 (2026-10-27). null 이면 본인
  final String? ownerName;

  /// 그 사람 근무일 — 처음 켜 둘 요일이다 (null 이면 본인 것)
  final List<int>? ownerWorkDays;

  @override
  State<_AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<_AddTaskScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// 돌아올 요일 — 처음에는 **그 사람 근무일**이 켜져 있다.
  ///
  /// 근무 설정을 아직 안 한 사람은 이레 다 켠다 — 그 사람은 서버도 전부
  /// 근무일로 보므로(`_is_workday`) 어느 요일이든 비면 누락이다.
  ///
  /// **`static` 이면 안 된다** (2026-09-05 고침). `static final` 은 앱이 켜진
  /// 뒤 **처음 연 사람의 근무일로 굳어** 다음 사람에게도 그대로 갔다. 그러면
  /// 토·일 근무자가 앞사람(월~금) 요일로 담아서 그날 목록에 영영 안 떴다.
  /// 화면마다 새로 세면 그 자리에서 로그인한 사람 것이 된다.
  late final Set<int> _weekdays = () {
    final days = widget.ownerWorkDays ?? currentUser?.workDays ?? const <int>[];
    return {...(days.isEmpty ? everyWeekday : days)};
  }();

  /// 업무 이름들 — **적은 차례대로** (요일·날짜는 내보낼 때 한꺼번에 붙인다)
  final _plan = <String>{};

  /// 업무 이름 → 체크할 때 받을 칸 (2026-08-31). 안 붙이면 없는 것이다
  ///
  /// **칸은 업무에 하나**다 — 서버도 이름으로 한 줄로 합친다
  final _fields = <String, List<MyTaskField>>{};

  /// 월 단위로 담는 중인가 (2026-09-21 대표 요청)
  ///
  /// 주 단위는 **요일을 고르고**, 월 단위는 **날짜를 고르고** 업무를 쌓는다.
  /// 매달 1일에 하는 재고 조사 같은 것을 요일로는 만들 수가 없었다.
  bool _monthly = false;

  /// 월 단위일 때 고른 **달의 며칠** — 담은 업무 **전부에** 같이 걸린다
  ///
  /// 업무마다 다른 날짜를 주지 않는다 — 날짜가 다른 업무는 한 번 더 추가한다.
  final _monthdays = <int>{};

  /// 갈래를 바꾼다 — **담아 둔 이름은 그대로 들고 간다**
  ///
  /// 이름을 적는 것이 이 화면에서 제일 품이 드는 일이라, 갈래를 잘못 골랐다고
  /// 처음부터 다시 적게 하지 않는다. 고른 요일·날짜도 각자 그대로 남는다.
  void _setMonthly(bool value) {
    if (_monthly == value) return;
    setState(() {
      _flush();
      _monthly = value;
    });
  }

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

  /// 입력칸의 글을 담는다 — 칸을 비우고 커서를 남겨서
  /// 엔터만 계속 눌러 여러 줄을 이어 적을 수 있다
  void _stage() {
    if (_value.isEmpty) return;
    setState(() {
      _plan.add(_value);
      _text.clear();
    });
    _focus.requestFocus();
  }

  /// 담은 줄을 뺀다
  void _remove(String content) {
    setState(() {
      _plan.remove(content);
      _fields.remove(content);
    });
  }

  /// 적다 만 글도 같이 담는다 — 엔터를 안 누르고 바로 넘기는 사람이 많다
  void _flush() {
    if (_value.isEmpty) return;
    _plan.add(_value);
    _text.clear();
  }

  void _submit() {
    setState(_flush);
    if (_plan.isEmpty) return;
    // 아무 요일·날짜에도 안 걸리면 **영영 안 뜨는 업무**가 된다
    if (_monthly && _monthdays.isEmpty) {
      return AppToast.show(context, '도는 날짜를 하나 이상 골라주세요');
    }
    if (!_monthly && _weekdays.isEmpty) {
      return AppToast.show(context, '돌아오는 요일을 하나 이상 골라주세요');
    }
    final month = _monthdays.toList()..sort();
    // 월 단위 업무도 `weekdays` 칸이 `NOT NULL` 이라 값을 채워 보낸다 — 서버는
    // `monthdays` 가 있으면 요일을 안 보므로 매일로 둔다 (`stands_on`)
    final days = _monthly ? [...everyWeekday] : (_weekdays.toList()..sort());
    Navigator.pop(
      context,
      _AddResult(
        {for (final key in _plan) key: days},
        _fields,
        // 주 단위면 빈 map — 그때는 서버가 요일만 본다
        monthdays: _monthly ? {for (final key in _plan) key: month} : const {},
      ),
    );
  }

  /// 담아 둔 줄에 입력 칸을 붙이거나 뗀다 — 줄을 누르면 열린다
  Future<void> _editFields(String content) async {
    final made = await showAppDialog<List<MyTaskField>>(
      context,
      (_) =>
          _FieldsCard(content: content, fields: _fields[content] ?? const []),
    );
    if (made == null || !mounted) return;
    setState(() {
      if (made.isEmpty) {
        _fields.remove(content);
      } else {
        _fields[content] = made;
      }
    });
  }

  /// 지금까지 담은 업무 수 — 버튼에 쓴다 (적다 만 글까지 센다)
  int get _count =>
      _plan.length + (_value.isEmpty || _plan.contains(_value) ? 0 : 1);

  /// 담은 업무가 돌아오는 때 — 담긴 줄 머리에 적는다
  String get _whenLabel {
    if (_monthly) {
      final picked = _monthdays.toList()..sort();
      return picked.isEmpty ? '날짜를 골라주세요' : monthdayLabel(picked);
    }
    if (_weekdays.isEmpty) return '요일을 골라주세요';
    // 이레 다면 `weekdayLabel` 이 빈 글자를 준다 (목록 줄에서는 안 적는 게 맞다)
    final days = _weekdays.toList()..sort();
    return isEveryWeekday(days) ? '매일' : weekdayLabel(days);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 주냐 월이냐 — **제일 위에서 먼저 고른다.** 아래 화면이 통째로 갈린다
        // 다른 화면의 목록바와 같은 공용 위젯 — 따로 그리면 모양이 갈린다
        ModeSwitch(
          left: '주 단위',
          right: '월 단위',
          value: _monthly,
          onChanged: _setMonthly,
        ),
        const SizedBox(height: 18),
        if (_monthly) ...[
          Text('도는 날짜', style: AppTextStyles.label),
          const SizedBox(height: 10),
          _MonthdayPicker(
            selected: _monthdays,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 22),
        ],
        // 돌아올 요일 — 칸을 눌러 켜고 끈다. 처음에는 근무일이 켜져 있다
        if (!_monthly) ...[
          Text('돌아오는 요일', style: AppTextStyles.label),
          const SizedBox(height: 10),
          WeekdayPicker(
            selected: _weekdays,
            onChanged: () => setState(() {}),
            note: '담은 업무가 고른 요일마다 목록에 떠요',
          ),
          const SizedBox(height: 22),
        ],

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
        if (_plan.isEmpty)
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
        if (_plan.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Row(
              children: [
                Text('담은 업무 ${_plan.length}개', style: AppTextStyles.label),
                const SizedBox(width: 8),
                // 어느 요일(날짜)에 걸리는지 — 위에서 고친 것이 바로 따라온다
                Flexible(
                  child: Text(
                    _whenLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final (i, content) in _plan.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _StagedRow(
              text: content,
              fields: _fields[content] ?? const [],
              onTap: () => _editFields(content),
              onRemove: () => _remove(content),
            ),
          ],
        ],
      ],
    );

    final title = widget.ownerName == null
        ? '업무 추가'
        : '${widget.ownerName}님 업무 추가';

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: title,
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
                  child: Text(title, style: AppTextStyles.title3),
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

/// 달의 며칠 — 1~31 칸을 눌러 고른다 (2026-09-21)
///
/// [selected] 를 **직접 고쳐 쓴다** — 요일 고르개(`WeekdayPicker`)와 같은
/// 방식이다. 값을 복사해 돌려주면 부모가 두 벌을 들게 된다.
///
/// **31일까지 다 연다.** 없는 날(2월 31일)은 그 달에 그냥 안 선다 —
/// 말일로 당기지 않는다 (서버 `stands_on` 과 같은 규칙).
class _MonthdayPicker extends StatelessWidget {
  const _MonthdayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final VoidCallback onChanged;

  void _toggle(int day) {
    if (!selected.remove(day)) selected.add(day);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final picked = selected.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 한 줄에 일곱 칸 — 달력과 같은 폭이라 눈에 익다
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: monthdayMax,
          itemBuilder: (context, index) {
            final day = index + 1;
            final on = selected.contains(day);
            return Pressable(
              onTap: () => _toggle(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.gray100,
                  ),
                ),
                child: Text(
                  '$day',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            picked.isEmpty
                ? '도는 날짜를 골라주세요'
                // 29~31일은 없는 달이 있다 — 고른 뒤에 알면 늦다
                : '${monthdayLabel(picked)}에 돌아와요'
                      '${picked.any((d) => d > 28) ? ' · 없는 달은 건너뛰어요' : ''}',
            style: AppTextStyles.caption.copyWith(
              color: picked.isEmpty
                  ? AppColors.gray400
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 아직 안 만든 줄 — **누르면 입력 칸**, 오른쪽 X 로 뺀다
class _StagedRow extends StatelessWidget {
  const _StagedRow({
    required this.text,
    required this.fields,
    required this.onTap,
    required this.onRemove,
  });

  final String text;

  /// 이 업무에 붙은 입력 칸 — 있으면 이름 아래에 한 마디로 적는다
  final List<MyTaskField> fields;

  final VoidCallback onTap;
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
          child: Pressable(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 칸을 안 붙였으면 붙이는 길이 있다고 알려 준다 — 줄을 눌러야
                // 열리는데 아무 표시가 없으면 있는 줄을 모른다
                Text(
                  fields.isEmpty
                      ? '눌러서 입력 칸 추가'
                      : [for (final f in fields) f.name].join(' · '),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: fields.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
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

/// 추가 화면이 돌려주는 값 — 업무별 요일과 입력 칸
class _AddResult {
  const _AddResult(this.plan, this.fields, {this.monthdays = const {}});

  /// 업무 이름 → 걸리는 요일
  final Map<String, List<int>> plan;

  /// 업무 이름 → 체크할 때 받을 칸 (안 붙인 업무는 없다)
  final Map<String, List<MyTaskField>> fields;

  /// 업무 이름 → 걸리는 **달의 며칠** — 월 단위로 담았을 때만 찬다
  ///
  /// 비어 있으면 주 단위다. 서버도 이 칸이 있으면 요일을 안 본다
  /// (`services/my_tasks.stands_on`).
  final Map<String, List<int>> monthdays;
}

/// 업무 하나의 입력 칸을 손보는 창 — 추가 화면에서 줄을 누르면 열린다
class _FieldsCard extends StatefulWidget {
  const _FieldsCard({required this.content, required this.fields});

  final String content;
  final List<MyTaskField> fields;

  @override
  State<_FieldsCard> createState() => _FieldsCardState();
}

class _FieldsCardState extends State<_FieldsCard> {
  late var _fields = [...widget.fields];

  @override
  Widget build(BuildContext context) => _FormCard(
    title: widget.content,
    hint: '칸을 붙이면 체크할 때 값을 물어봐요.',
    confirmLabel: '저장',
    enabled: true,
    onConfirm: () => Navigator.pop(context, _fields),
    body: [
      _Label('입력 칸'),
      _FieldsEditor(
        fields: _fields,
        onChanged: (next) => setState(() => _fields = next),
      ),
    ],
  );
}

/// 업무 하나에 붙일 수 있는 입력 칸 수 — 서버 `MAX_FIELDS` 와 같은 값
const _maxFields = 5;

/// 칸 이름 길이 — 서버 `MyTaskField.name` 이 20자다
const _fieldNameMax = 20;

/// **체크할 때 받을 칸을 정하는 자리** (2026-08-31 요청)
///
/// 주간 신규·재등록 수처럼 체크와 함께 받아야 하는 값이 있다. 칸을 붙이면
/// 그 업무는 **값을 다 채워야 체크가 된다.**
///
/// 추가 화면과 수정 폼이 같이 쓴다 — 두 자리에서 모양이 갈리면 안 된다.
class _FieldsEditor extends StatelessWidget {
  const _FieldsEditor({required this.fields, required this.onChanged});

  final List<MyTaskField> fields;
  final ValueChanged<List<MyTaskField>> onChanged;

  void _add(BuildContext context) async {
    final made = await showAppDialog<MyTaskField>(
      context,
      (_) => const _FieldNameCard(),
    );
    if (made == null) return;
    // 같은 이름을 두 번 두지 않는다 — 값이 이름을 키로 담아서 겹치면 덮인다
    if (fields.any((f) => f.name == made.name)) return;
    onChanged([...fields, made]);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 9, 10),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: Text(fields[i].name, style: AppTextStyles.body2)),
              Text(
                fields[i].number ? '숫자' : '글',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 6),
              Pressable(
                onTap: () => onChanged([...fields]..removeAt(i)),
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
        ),
      ],
      if (fields.length < _maxFields) ...[
        if (fields.isNotEmpty) const SizedBox(height: 8),
        Pressable(
          onTap: () => _add(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Text(
              fields.isEmpty ? '입력 칸 추가' : '칸 하나 더',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// 칸 하나 만들기 — 이름과 종류
class _FieldNameCard extends StatefulWidget {
  const _FieldNameCard();

  @override
  State<_FieldNameCard> createState() => _FieldNameCardState();
}

class _FieldNameCardState extends State<_FieldNameCard> {
  final _name = TextEditingController();
  bool _number = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _name.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, MyTaskField(name: text, number: _number));
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: '입력 칸',
    hint: '체크할 때 이 값을 물어봐요.',
    confirmLabel: '추가',
    enabled: _name.text.trim().isNotEmpty,
    onConfirm: _submit,
    body: [
      _Label('칸 이름'),
      _Field(
        controller: _name,
        autofocus: true,
        hintText: '예) 신규',
        maxLength: _fieldNameMax,
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 14),
      _Label('받을 값'),
      Row(
        children: [
          for (final number in [true, false]) ...[
            if (!number) const SizedBox(width: 8),
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _number = number),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _number == number
                        ? AppColors.primary
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    number ? '숫자' : '글',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _number == number
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// **체크하면서 값을 적는 창** (2026-08-31 요청)
///
/// 칸이 붙은 업무는 이 창이 대신 뜬다 — 확인 창(`showConfirmDialog`)과
/// 두 번 묻지 않으려고 되돌릴 수 없다는 말도 여기 같이 적는다.
class _ValueCard extends StatefulWidget {
  const _ValueCard({required this.task});

  final MyTask task;

  @override
  State<_ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<_ValueCard> {
  late final _inputs = {
    for (final f in widget.task.fields) f.name: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    for (final c in _inputs.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 하나라도 비면 못 넘긴다 — 값을 받으려고 만든 칸이다
  bool get _ready => _inputs.values.every((c) => c.text.trim().isNotEmpty);

  void _submit() {
    if (!_ready) return;
    Navigator.pop(context, {
      for (final e in _inputs.entries) e.key: e.value.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.task.fields;
    return _FormCard(
      title: widget.task.content,
      // 처음 체크할 때만 결재 이야기를 한다 — 확인 창과 같은 규칙이다
      hint: widget.task.everChecked
          ? '한 번 체크하면 되돌릴 수 없어요.'
          : '한 번 체크하면 되돌릴 수 없어요.\n그 뒤로는 고치거나 지울 때 대표님 승인이 필요해요.',
      confirmLabel: '완료',
      enabled: _ready,
      onConfirm: _submit,
      body: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _Label(fields[i].name),
          _Field(
            controller: _inputs[fields[i].name]!,
            autofocus: i == 0,
            number: fields[i].number,
            hintText: fields[i].number ? '숫자' : '내용',
            maxLength: fields[i].number ? 9 : _contentMax,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ],
    );
  }
}

/// 수정·삭제 폼이 돌려주는 값
class _RequestResult {
  const _RequestResult({
    this.reason = '',
    this.content,
    this.weekdays,
    this.monthdays,
    this.fields,
  });

  /// 결재 사유 — **바로 고치는 길에서는 빈 문자열**이다 (안 묻는다)
  final String reason;

  /// 고치겠다는 내용 — 삭제면 null
  final String? content;

  /// 고치겠다는 요일 — 삭제면 null. **내용과 따로 고칠 수 있다**
  final List<int>? weekdays;

  /// 고치겠다는 **달의 며칠** — 월 단위 업무를 고칠 때만 찬다 (2026-09-21).
  /// 주 단위 업무에는 null 이라 갈래가 안 바뀐다
  final List<int>? monthdays;

  /// 고치겠다는 입력 칸 — 삭제면 null. **빈 목록은 칸을 없앤다는 뜻**이다
  final List<MyTaskField>? fields;
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

  /// 지금 걸린 **달의 며칠** — 월 단위 업무만 찬다 (2026-09-21)
  late final _monthdays = <int>{...?widget.task.monthdays};

  /// 월 단위 업무인가 — **여기서 갈래를 바꾸지 않는다.**
  ///
  /// 만들 때 고른 갈래를 그대로 두고 값만 고친다. 갈래까지 여기서 바꾸면
  /// 이미 체크한 업무의 지난 날짜 판정이 통째로 다시 계산된다 — 주 단위로
  /// 만든 업무를 월 단위로 돌리면 안 한 날이 갑자기 누락이 된다.
  /// 갈래를 바꾸려면 지우고 새로 만든다.
  bool get _monthly => widget.task.isMonthly;

  /// 지금 붙은 입력 칸에서 시작한다 (2026-08-31)
  late var _fields = [...widget.task.fields];

  bool get _isEdit => widget.type == MyTaskRequestType.edit;

  /// 도는 차례를 바꿨나 — 차례를 맞춰 견준다 (서버도 정렬해서 준다)
  bool get _daysChanged {
    if (_monthly) {
      final now = _monthdays.toList()..sort();
      return now.join(',') != (widget.task.monthdays ?? const []).join(',');
    }
    final now = _days.toList()..sort();
    return now.join(',') != widget.task.weekdays.join(',');
  }

  /// 입력 칸을 바꿨나
  bool get _fieldsChanged {
    final was = widget.task.fields;
    if (_fields.length != was.length) return true;
    for (var i = 0; i < _fields.length; i++) {
      if (_fields[i] != was[i]) return true;
    }
    return false;
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
    return next != widget.task.content || _daysChanged || _fieldsChanged;
  }

  void _submit() {
    if (!_ready) return;
    // 월 단위인데 날짜를 다 빼면 **영영 안 뜨는 업무**가 된다
    if (_isEdit && _monthly && _monthdays.isEmpty) {
      return AppToast.show(context, '도는 날짜를 하나 이상 골라주세요');
    }
    // 하나도 안 고르면 매일 — 추가 화면과 같은 규칙이다
    final days = _days.toList()..sort();
    final month = _monthdays.toList()..sort();
    Navigator.pop(
      context,
      _RequestResult(
        reason: _reason.text.trim(),
        content: _isEdit ? _content.text.trim() : null,
        weekdays: _isEdit ? (days.isEmpty ? everyWeekday : days) : null,
        // 월 단위 업무만 싣는다 — 주 단위에 보내면 갈래가 바뀐다
        monthdays: _isEdit && _monthly ? month : null,
        fields: _isEdit ? _fields : null,
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
        // 만들 때 고른 갈래를 그대로 따라간다 — 여기서는 값만 고친다
        if (_monthly) ...[
          _Label('돌아오는 날짜'),
          _MonthdayPicker(
            selected: _monthdays,
            onChanged: () => setState(() {}),
          ),
        ] else ...[
          _Label('돌아오는 요일'),
          WeekdayPicker(
            selected: _days,
            onChanged: () => setState(() {}),
            note: '고른 요일에만 목록에 떠요',
          ),
        ],
        const SizedBox(height: 14),
        _Label('입력 칸'),
        _FieldsEditor(
          fields: _fields,
          onChanged: (next) => setState(() => _fields = next),
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
    this.number = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  /// 회색 면 없이 글자만 — 바깥에서 이미 칸을 그렸을 때
  final bool bare;

  /// 숫자만 받는가 — 숫자 자판이 뜨고 다른 글자는 안 들어간다
  final bool number;

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
      keyboardType: number ? TextInputType.number : null,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
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
