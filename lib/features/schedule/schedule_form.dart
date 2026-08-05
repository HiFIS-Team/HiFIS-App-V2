part of 'schedule_screen.dart';

// ── 일정 입력 폼 ──

/// 일정 추가·수정 폼.
/// [origin]을 주면 수정 모드가 되고, 삭제를 누르면 deleted가 켜진 값이 돌아온다.
Future<Event?> showEventDialog(
  BuildContext context, {
  required DateTime date,
  Event? origin,
}) {
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
    // 잠긴 폼에 커서를 세우면 고칠 수 있는 것처럼 보인다
    if (!_locked) _titleFocus.requestFocus();
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

  /// 참석자 알약 — 한 줄에 [_perRow]개씩 **같은 폭**으로 세운다
  ///
  /// 이름 길이대로 흘려 보내면(Wrap) 줄 끝이 들쭉날쭉해 오른쪽이 비어 보인다.
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
          if (row > 0) SizedBox(height: 6),
          Row(
            children: [
              for (var col = 0; col < _perRow; col++) ...[
                if (col > 0) SizedBox(width: 6),
                Expanded(
                  child: switch (row * _perRow + col) {
                    // 마지막 줄의 빈칸 — 자리를 차지해야 폭이 안 늘어난다
                    final i when i >= people.length => SizedBox.shrink(),
                    final i => _PersonChip(
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

  void _delete() {
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

  @override
  Widget build(BuildContext context) {
    final empty = _title.text.trim().isEmpty;

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
                Text(
                  _locked
                      ? '일정'
                      : _editing
                      ? '일정 수정'
                      : '새 일정',
                  style: AppTextStyles.title2,
                ),
                if (_locked) ...[
                  SizedBox(width: 8),
                  Text('만든 사람만 고칠 수 있어요', style: AppTextStyles.caption),
                ],
              ],
            ),
            SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
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
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final kind in Kind.values)
                          // 잠겼으면 고른 것만 남긴다 — 못 누르는 칩이 줄줄이
                          // 남아 있으면 고를 수 있는 것처럼 보인다
                          if (!_locked || kind == _kind)
                            Pressable(
                              onTap: _tap(() => setState(() => _kind = kind)),
                              scale: 0.96,
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: kind == _kind
                                      ? kind.color.withValues(alpha: 0.14)
                                      : AppColors.gray50,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  kind.label,
                                  style: AppTextStyles.body2.copyWith(
                                    fontSize: 13,
                                    color: kind == _kind
                                        ? kind.color
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 62,
                          child: Text('날짜', style: AppTextStyles.label),
                        ),
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
                        SizedBox(
                          width: 62,
                          child: Text('시간', style: AppTextStyles.label),
                        ),
                        Pressable(
                          onTap: _tap(() => setState(() => _allDay = !_allDay)),
                          scale: 0.96,
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _allDay
                                  ? AppColors.primaryLight
                                  : AppColors.gray50,
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
                    _Field(
                      controller: _place,
                      hint: '장소 (선택)',
                      readOnly: _locked,
                    ),
                    SizedBox(height: 14),
                    Text('참석자', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    ScrollBox(maxHeight: kChipBoxHeight, child: _personGrid()),
                    SizedBox(height: 14),
                    _Field(
                      controller: _memo,
                      hint: '메모 (선택)',
                      lines: 2,
                      readOnly: _locked,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                // 대기 중인 신청은 삭제 대신 결재를 낸다 — 반려가 곧 지우는 것이다
                if (_deciding) ...[
                  _TextButton(
                    label: '반려',
                    color: AppColors.error,
                    onTap: _reject,
                  ),
                  _TextButton(
                    label: '승인',
                    color: AppColors.primary,
                    onTap: _approve,
                  ),
                ] else if (_editing && !_locked)
                  _TextButton(
                    label: '삭제',
                    color: AppColors.error,
                    onTap: _delete,
                  ),
                Spacer(),
                Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
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
                    scale: 0.97,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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
            ),
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
      scale: 0.97,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
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
      scale: 0.97,
      pressedColor: AppColors.gray100,
      borderRadius: BorderRadius.circular(10),
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

/// 일정 신청을 승인·반려할 수 있는 사람 — 승인 없이 올릴 수 있는 사람과 같다
bool get _canDecide => myRole == Role.master || myRole == Role.admin;

/// 폼이 들고 나오는 결재 — 반려는 서버가 일정을 지운다
enum EventDecision { approve, reject }

/// 반려 사유 입력칸의 예시 — 줄에서 누르든 폼에서 누르든 같은 문구를 쓴다
const _rejectHint = '예) 그날은 이미 다른 행사가 있어요';

/// 참석자 알약을 한 줄에 몇 개 세울지 (폼 폭 440 기준)
const _perRow = 3;

/// 참석자 고르는 알약
class _PersonChip extends StatelessWidget {
  _PersonChip({required this.staff, required this.joined, required this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Avatar(name: staff.name, size: 22),
            SizedBox(width: 6),
            // 칸 폭이 정해져 있어 긴 이름은 말줄임으로 자른다
            Expanded(
              child: Text(
                staff.name == me ? '나' : staff.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: joined ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
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
