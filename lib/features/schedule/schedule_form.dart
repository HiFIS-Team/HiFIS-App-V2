part of 'schedule_screen.dart';

// ── 일정 입력 폼 ──

/// 일정 추가·수정 폼.
/// [origin]을 주면 수정 모드가 되고, 삭제를 누르면 deleted가 켜진 값이 돌아온다.
///
/// **폰은 옆에서 밀려 들어오는 페이지**로 연다 — 창은 폭 440 이라 폰에 안 들어간다.
/// PC 는 달력 위에 뜨는 창 그대로다.
Future<Event?> showEventDialog(
  BuildContext context, {
  required DateTime date,
  Event? origin,
}) {
  if (!isDesktop) {
    return Navigator.push<Event>(
      context,
      CupertinoPageRoute(
        builder: (_) => _EventDialog(date: date, origin: origin),
      ),
    );
  }
  return showDialog<Event>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _EventDialog(date: date, origin: origin),
      ),
    ),
  );
}

class _EventDialog extends StatefulWidget {
  _EventDialog({required this.date, this.origin});

  final DateTime date;
  final Event? origin;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final _title = TextEditingController(text: widget.origin?.title ?? '');
  late final _place = TextEditingController(text: widget.origin?.place ?? '');
  late final _memo = TextEditingController(text: widget.origin?.memo ?? '');
  final _titleFocus = FocusNode();

  late DateTime _date = widget.origin?.date ?? widget.date;

  /// 끝나는 날 — 하루짜리면 [_date]와 같다
  late DateTime _until = widget.origin?.until ?? widget.date;

  late Kind _kind = widget.origin?.kind ?? Kind.meeting;
  late bool _allDay = widget.origin?.allDay ?? false;
  late TimeOfDay _start =
      widget.origin?.start ?? TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _end = widget.origin?.end ?? TimeOfDay(hour: 11, minute: 0);
  late final _members = <String>[...?widget.origin?.members];

  bool get _editing => widget.origin != null;

  /// 남이 만든 일정은 열어서 보기만 한다 — 저장하면 서버가 403 을 준다
  bool get _locked => !(widget.origin?.canEdit ?? true);

  /// 잠겼으면 눌러도 아무 일 없게 한다.
  ///
  /// 폼 전체를 `IgnorePointer` 로 덮는 게 짧지만 그러면 **스크롤도 같이 막혀서**
  /// 참석자 아래 메모를 못 읽는다. 그래서 누르는 자리만 하나씩 막는다.
  VoidCallback _tap(VoidCallback action) => _locked ? _ignore : action;

  static void _ignore() {}

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    // 잠긴 폼에 커서를 세우면 고칠 수 있는 것처럼 보인다.
    // 폰은 페이지가 밀려 들어오는 중에 키보드가 같이 올라오면 어수선해서
    // 자동 포커스를 두지 않는다 (새 프로젝트와 같다)
    if (!_locked && isDesktop) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  ThemeData _pickerTheme(BuildContext context) => Theme.of(context).copyWith(
    colorScheme:
        (AppColors.isDark
                ? ColorScheme.dark(surface: AppColors.surface)
                : ColorScheme.light(surface: AppColors.surface))
            .copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
  );

  Future<void> _pickDate({required bool start}) async {
    final base = start ? _date : _until;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      // 종료일은 시작일보다 앞을 못 고르게 막는다
      firstDate: start ? DateTime(base.year - 2) : _date,
      lastDate: DateTime(base.year + 3),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _date = picked;
        // 시작이 끝을 넘어가면 끝도 같이 옮긴다 (시간 고르개와 같은 방식)
        if (_until.isBefore(picked)) _until = picked;
      } else {
        _until = picked;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        // 시작이 끝을 넘어가면 끝도 한 시간 뒤로 밀어준다
        if (_minutes(_end) <= _minutes(_start)) {
          _end = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        }
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '일정 이름을 입력해주세요');
      _titleFocus.requestFocus();
      return;
    }
    // 날이 갈리면 끝 시각이 시작보다 일러도 된다 (10일 18시 ~ 12일 09시)
    if (!_allDay &&
        _isSameDay(_date, _until) &&
        _minutes(_end) <= _minutes(_start)) {
      AppToast.show(context, '종료 시간이 시작보다 빨라요');
      return;
    }
    Navigator.pop(
      context,
      Event(
        // 수정이면 어느 일정을 고친 것인지 들고 나가야 서버에 보낼 수 있다
        id: widget.origin?.id,
        ownerId: widget.origin?.ownerId,
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
        until: DateTime(_until.year, _until.month, _until.day),
        kind: _kind,
        start: _allDay ? null : _start,
        end: _allDay ? null : _end,
        place: _place.text.trim(),
        memo: _memo.text.trim(),
        members: [
          for (final staff in staffList)
            if (_members.contains(staff.name)) staff.name,
        ],
      ),
    );
  }

  /// 참석자 한 칸 — 아바타 위, 이름 아래 (프로젝트 `_MemberCard` 와 같은 모양)
  ///
  /// **알약이 아니라 카드다** (2026-08-28). 알약은 이름 길이만큼 폭이 달라서
  /// 줄이 들쭉날쭉했다 — 칸을 고정하면 세로 줄이 맞는다.
  /// 한 줄에 [_perRow]개씩 **같은 폭**으로 세운다
  ///
  /// 이름 길이대로 흘려 보내면(Wrap) 줄 끝이 들쭉날쭉해 오른쪽이 비어 보인다.
  /// 종류 고르개 — 한 줄에 셋, 마지막 줄 빈칸은 자리만 차지한다
  ///
  /// 잠겼으면(남의 일정) 고른 것 하나만 남긴다 — 못 누르는 카드가 줄줄이
  /// 남아 있으면 고를 수 있는 것처럼 보인다.
  Widget _kindCards() {
    final kinds = [
      for (final kind in Kind.values)
        if (!_locked || kind == _kind) kind,
    ];

    return Column(
      children: [
        for (var row = 0; row * _perRow < kinds.length; row++) ...[
          if (row > 0) SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < _perRow; col++) ...[
                if (col > 0) SizedBox(width: 8),
                Expanded(
                  child: switch (row * _perRow + col) {
                    // 마지막 줄의 빈칸 — 자리를 차지해야 폭이 안 늘어난다
                    final i when i >= kinds.length => SizedBox(height: 72),
                    final i => _KindCard(
                      kind: kinds[i],
                      selected: kinds[i] == _kind,
                      onTap: _tap(() => setState(() => _kind = kinds[i])),
                    ),
                  },
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _personGrid() {
    final people = [
      for (final staff in staffList)
        // 잠겼으면 고른 사람만 남긴다 — 못 누르는 알약이 줄줄이 남으면
        // 고를 수 있는 것처럼 보인다
        if (!_locked || _members.contains(staff.name)) staff,
    ];

    return Column(
      children: [
        for (var row = 0; row * _perRow < people.length; row++) ...[
          if (row > 0) SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < _perRow; col++) ...[
                if (col > 0) SizedBox(width: 8),
                Expanded(
                  child: switch (row * _perRow + col) {
                    // 마지막 줄의 빈칸 — 자리를 차지해야 폭이 안 늘어난다
                    final i when i >= people.length => SizedBox.shrink(),
                    final i => PersonCard(
                      staff: people[i],
                      joined: _members.contains(people[i].name),
                      onTap: _tap(
                        () => setState(() {
                          final name = people[i].name;
                          if (_members.contains(name)) {
                            _members.remove(name);
                          } else {
                            _members.add(name);
                          }
                        }),
                      ),
                    ),
                  },
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _delete() async {
    // 전사 달력에서 사라지는 일이라 한 번 더 묻는다 (공지·회의록·문서함과 같다)
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: '이 일정을 지울까요?',
      message: '지우면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    Navigator.pop(context, widget.origin!..deleted = true);
  }

  /// 승인 대기 중인 남의 신청을 결재할 수 있는 자리인지
  bool get _deciding => (widget.origin?.pending ?? false) && _canDecide;

  void _approve() {
    Navigator.pop(context, widget.origin!..decision = EventDecision.approve);
  }

  Future<void> _reject() async {
    final reason = await askRejectReason(context, hint: '예) 그날은 이미 다른 행사가 있어요');
    if (reason == null || !mounted) return;
    Navigator.pop(
      context,
      widget.origin!
        ..decision = EventDecision.reject
        ..rejectReason = reason,
    );
  }

  /// 창 제목 · 폰 페이지 제목 — 같은 말을 쓴다
  String get _heading => _locked
      ? '일정'
      : _editing
      ? '일정 수정'
      : '새 일정';

  /// 입력칸들 — 창이든 페이지든 같은 것이 선다
  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          controller: _title,
          focusNode: _titleFocus,
          hint: '일정 이름',
          bold: true,
          readOnly: _locked,
          onSubmitted: _submit,
        ),
        SizedBox(height: 14),
        // **전자결재 신청과 같은 카드로 고른다** (2026-08-28 대표 결정).
        //
        // 예전에는 작은 알약 다섯 개가 흘러 있었다 — 종류가 이 폼에서 제일
        // 먼저 정하는 값인데 제목 밑에 조용히 붙어 있어서 눈에 안 들어왔다.
        // 아이콘이 붙으면 글자를 안 읽어도 무엇인지 보인다.
        //
        // 결재는 두 칸씩인데(`지출결의`·`외근·출장` 처럼 라벨이 길다)
        // 여기는 두 글자라 **셋씩**이 맞는다 — 참석자 카드와 같은 칸 수다.
        _kindCards(),
        SizedBox(height: 16),
        Row(
          children: [
            SizedBox(width: 62, child: Text('날짜', style: AppTextStyles.label)),
            _PickButton(
              icon: Icons.calendar_today_rounded,
              label: _dayLabel(_date),
              onTap: _tap(() => _pickDate(start: true)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('~', style: AppTextStyles.caption),
            ),
            _PickButton(
              label: _dayLabel(_until),
              onTap: _tap(() => _pickDate(start: false)),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 62, child: Text('시간', style: AppTextStyles.label)),
            Pressable(
              onTap: _tap(() => setState(() => _allDay = !_allDay)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _allDay ? AppColors.primaryLight : AppColors.gray50,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '종일',
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 13,
                    color: _allDay
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!_allDay) ...[
              SizedBox(width: 6),
              _PickButton(
                icon: Icons.schedule_rounded,
                label: _time(_start),
                onTap: _tap(() => _pickTime(start: true)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('~', style: AppTextStyles.caption),
              ),
              _PickButton(
                label: _time(_end),
                onTap: _tap(() => _pickTime(start: false)),
              ),
            ],
          ],
        ),
        SizedBox(height: 12),
        _Field(controller: _place, hint: '장소 (선택)', readOnly: _locked),
        SizedBox(height: 14),
        // 프로젝트 참여 멤버와 **같은 카드**다 — 사람을 고르는 자리가 앱에
        // 둘인데 모양이 다르면 같은 일인지 모른다
        Row(
          children: [
            Text('참석자', style: AppTextStyles.label),
            SizedBox(width: 6),
            Text(
              '${_members.length}',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // 안쪽 스크롤을 안 쓴다 — 카드는 키가 커서 140 안에 두 줄밖에 안
        // 들어간다. 다 펼치고 페이지가 스크롤한다 (프로젝트와 같다)
        _personGrid(),
        SizedBox(height: 14),
        _Field(controller: _memo, hint: '메모 (선택)', lines: 2, readOnly: _locked),
      ],
    );
  }

  /// 아래 버튼 줄 — 삭제·결재 / 취소 · 저장
  Widget _footer() {
    final empty = _title.text.trim().isEmpty;
    return Row(
      children: [
        // 대기 중인 신청은 삭제 대신 결재를 낸다 — 반려가 곧 지우는 것이다
        if (_deciding) ...[
          _TextButton(label: '반려', color: AppColors.error, onTap: _reject),
          _TextButton(label: '승인', color: AppColors.primary, onTap: _approve),
        ] else if (_editing && !_locked)
          _TextButton(label: '삭제', color: AppColors.error, onTap: _delete),
        Spacer(),
        Pressable(
          onTap: () => Navigator.pop(context),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            _locked ? '닫기' : '취소',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (!_locked) ...[
          SizedBox(width: 8),
          Pressable(
            onTap: _submit,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                // 이름을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                color: empty ? AppColors.gray200 : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _editing ? '저장' : '추가',
                style: AppTextStyles.body2.copyWith(
                  color: empty ? AppColors.gray500 : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 카드 끝에 붙는 곁버튼 — 삭제 · 결재 (폰)
  ///
  /// 창에서는 버튼 줄 왼쪽에 서던 것들이다. 폰은 주 동작(추가·저장)이
  /// 아래 글래스 버튼으로 내려가서 여기가 이것들의 자리가 된다.
  Widget? _sideActions() {
    // 대기 중인 신청은 삭제 대신 결재를 낸다 — 반려가 곧 지우는 것이다
    if (_deciding) {
      return Row(
        children: [
          _TextButton(label: '반려', color: AppColors.error, onTap: _reject),
          _TextButton(label: '승인', color: AppColors.primary, onTap: _approve),
        ],
      );
    }
    if (_editing && !_locked) {
      return Row(
        children: [
          _TextButton(label: '삭제', color: AppColors.error, onTap: _delete),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 폰은 옆에서 밀려 들어온 페이지 — 제목은 껍데기가 그리고,
    // 주 동작은 하단 탭바 자리의 글래스 버튼이 받는다 (새 프로젝트와 같은 틀)
    if (!isDesktop) {
      final side = _sideActions();
      return PhoneDetailScaffold(
        title: _heading,
        background: AppColors.surface,
        // 남의 일정을 열어 본 것이면 저장할 게 없어 버튼을 안 낸다
        bottomBar: _locked
            ? null
            : GlassBottomButton(
                label: _editing ? '저장' : '추가',
                active: _title.text.trim().isNotEmpty,
                onPressed: _submit,
              ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            _locked
                ? bottomBarInset(context)
                : GlassBottomButton.inset(context),
          ),
          children: [
            // 창에서는 제목 옆에 붙던 줄 — 제목이 껍데기로 가서 여기로 내린다
            if (_locked) ...[
              Text('만든 사람만 고칠 수 있어요', style: AppTextStyles.caption),
              SizedBox(height: 12),
            ],
            // 배경이 흰색이라 카드 없이 그대로 앉는다 — 예전에는 폼 전체를
            // 흰 카드에 넣었는데 화면이 모달처럼 보였다 (2026-08-28)
            _body(),
            if (side != null) ...[SizedBox(height: 6), side],
          ],
        ),
      );
    }

    return Container(
      width: 440,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_heading, style: AppTextStyles.title2),
                if (_locked) ...[
                  SizedBox(width: 8),
                  Text('만든 사람만 고칠 수 있어요', style: AppTextStyles.caption),
                ],
              ],
            ),
            SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _body())),
            SizedBox(height: 18),
            _footer(),
          ],
        ),
      ),
    );
  }
}

/// 폼 아래쪽 글자 버튼 (삭제·반려·승인)
class _TextButton extends StatelessWidget {
  _TextButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        label,
        style: AppTextStyles.body2.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 날짜·시간 고르는 버튼
class _PickButton extends StatelessWidget {
  _PickButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 일정 신청을 승인·반려할 수 있는 사람 — **MASTER 만이다**
///
/// **승인 없이 올릴 수 있는 사람과 다르다.** 그쪽은 MASTER·ADMIN 이고
/// (서버 `_OVERSEERS`), 결재는 대표만 한다. 예전에는 둘을 같은 값으로 봐서
/// ADMIN 이 남의 일정을 결재했다 (2026-08-14 에 갈랐다).
bool get _canDecide => myRole.canApprove;

/// 폼이 들고 나오는 결재 — 반려는 서버가 일정을 지운다
enum EventDecision { approve, reject }

/// 반려 사유 입력칸의 예시 — 줄에서 누르든 폼에서 누르든 같은 문구를 쓴다
const _rejectHint = '예) 그날은 이미 다른 행사가 있어요';

/// 참석자 알약을 한 줄에 몇 개 세울지 (폼 폭 440 기준)
/// 일정 종류 카드 — 아이콘 위, 이름 아래. 고르면 그 종류 색으로 찬다
///
/// 전자결재의 같은 이름 위젯과 **모양은 같고 색만 다르다.** 결재는 종류가
/// 다 같은 성격이라 파랑 하나로 칠하는데, 일정은 종류마다 색이 정해져 있고
/// (`Kind.color`) 그 색이 달력 칩에도 그대로 쓰인다 — 여기서 파랑으로
/// 칠하면 고르고 나서 달력에 뜨는 색과 달라진다.
class _KindCard extends StatelessWidget {
  _KindCard({required this.kind, required this.selected, required this.onTap});

  final Kind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? kind.color.withValues(alpha: 0.12)
              : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kind.color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              kind.icon,
              size: 20,
              color: selected ? kind.color : AppColors.textSecondary,
            ),
            SizedBox(height: 6),
            Text(
              kind.label,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                color: selected ? kind.color : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _perRow = 3;

/// 폼 입력칸
class _Field extends StatelessWidget {
  _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.lines = 1,
    this.bold = false,
    this.readOnly = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final bool bold;

  /// 남이 만든 일정을 열어 볼 때 — 읽히기만 한다
  final bool readOnly;

  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDecorations.fieldPadding,
      decoration: AppDecorations.field(),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
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
