import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';

/// 일정 화면 (목업)
///
/// 데스크톱은 화면을 꽉 채우는 월 달력 한 장으로 보여준다.
/// 날짜 칸을 누르면 그 날 일정이 열리고, 거기서 추가·수정·삭제한다.
/// 모바일 화면은 아직 준비 중 — PC를 먼저 다듬는다.
class ScheduleScreen extends StatefulWidget {
  ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// 보고 있는 달 (1일로 맞춰 둔다)
  late DateTime _month = _monthOf(DateTime.now());

  static DateTime _monthOf(DateTime time) => DateTime(time.year, time.month);

  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _openDay(DateTime date) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DayDialog(date: date),
    );
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final now = DateTime.now();
    // 이번 달을 보고 있으면 오늘, 다른 달이면 그 달 1일을 기본값으로
    final base = _monthOf(now) == _month
        ? DateTime(now.year, now.month, now.day)
        : _month;
    final created = await showEventDialog(context, date: base);
    if (created == null || !mounted) return;
    setState(() => events.add(created));
    AppToast.show(context, '일정을 추가했어요');
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '📅', title: '일정');

    // 그 달 1일이 낀 주의 일요일부터 채운다
    final first = _month.subtract(Duration(days: _month.weekday % 7));
    final last = DateTime(_month.year, _month.month + 1, 0);
    final weeks = ((last.difference(first).inDays + 1) / 7).ceil();
    final monthCount = events
        .where(
          (e) => e.date.year == _month.year && e.date.month == _month.month,
        )
        .length;

    // 배경은 다른 화면과 같은 회색, 달력은 그 위에 얹힌 흰 카드로 둔다
    return Scaffold(
      body: Column(
        children: [
          // 상단 글래스 헤더 버튼 영역만큼 비워둔다
          SizedBox(height: 64),
          Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 28, 14),
            child: Row(
              children: [
                Text(
                  '${_month.year}년 ${_month.month}월',
                  style: AppTextStyles.title1,
                ),
                SizedBox(width: 10),
                Text('일정 $monthCount', style: AppTextStyles.caption),
                SizedBox(width: 14),
                _RoundButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _move(-1),
                ),
                SizedBox(width: 6),
                _RoundButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _move(1),
                ),
                SizedBox(width: 8),
                Pressable(
                  onTap: () =>
                      setState(() => _month = _monthOf(DateTime.now())),
                  scale: 0.95,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(100),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    '오늘',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacer(),
                Pressable(
                  onTap: _add,
                  scale: 0.96,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(12, 9, 16, 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 17, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '일정 추가',
                          style: AppTextStyles.body2.copyWith(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 요일 머리
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: Text(
                          _weekdays[i],
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i == 0
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray100),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var d = 0; d < 7; d++)
                              Expanded(
                                child: _DayCell(
                                  date: first.add(Duration(days: w * 7 + d)),
                                  month: _month.month,
                                  lastWeek: w == weeks - 1,
                                  lastColumn: d == 6,
                                  onTap: _openDay,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 헤더의 달 이동 버튼
class _RoundButton extends StatelessWidget {
  _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

/// 날짜 한 칸 — 날짜 숫자와 그날 일정 칩
class _DayCell extends StatefulWidget {
  _DayCell({
    required this.date,
    required this.month,
    required this.lastWeek,
    required this.lastColumn,
    required this.onTap,
  });

  final DateTime date;

  /// 보고 있는 달 (다른 달 날짜는 흐리게)
  final int month;
  final bool lastWeek;
  final bool lastColumn;
  final ValueChanged<DateTime> onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final inMonth = date.month == widget.month;
    final today = _isSameDay(date, DateTime.now());
    final list = eventsOn(date);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(date),
        child: Container(
          decoration: BoxDecoration(
            // 이번 달이 아닌 칸은 한 톤 죽여서 달 경계를 알아보게 한다
            color: !inMonth
                ? AppColors.gray20
                : (_hover ? AppColors.gray50 : Colors.transparent),
            border: Border(
              right: BorderSide(
                color: widget.lastColumn
                    ? Colors.transparent
                    : AppColors.gray100,
              ),
              bottom: BorderSide(
                color: widget.lastWeek ? Colors.transparent : AppColors.gray100,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: today
                        ? Colors.white
                        : !inMonth
                        ? AppColors.gray300
                        : date.weekday == DateTime.sunday
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 3),
              // 남는 높이만큼만 칩을 넣고 나머지는 +N으로 접는다
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fit = (constraints.maxHeight / 21).floor();
                    final show = list.length <= fit
                        ? list.length
                        : (fit - 1).clamp(0, list.length);
                    final rest = list.length - show;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < show; i++) _Chip(event: list[i]),
                        if (rest > 0)
                          Padding(
                            padding: EdgeInsets.only(left: 4, top: 2),
                            child: Text(
                              '+$rest',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 달력 칸 안의 일정 한 줄
class _Chip extends StatelessWidget {
  _Chip({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 19,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: event.kind.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        event.allDay ? event.title : '${_time(event.start!)} ${event.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: event.kind.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── 하루 일정 ──

/// 날짜 칸을 누르면 뜨는 그날 일정 목록
class _DayDialog extends StatefulWidget {
  _DayDialog({required this.date});

  final DateTime date;

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  Future<void> _add() async {
    final created = await showEventDialog(context, date: widget.date);
    if (created == null) return;
    setState(() => events.add(created));
  }

  Future<void> _edit(Event event) async {
    final edited = await showEventDialog(
      context,
      date: event.date,
      origin: event,
    );
    if (edited == null) return;
    // 폼이 돌려준 값으로 갈아끼운다 (삭제면 목록에서 뺀다)
    setState(() {
      final index = events.indexOf(event);
      if (index < 0) return;
      if (edited.deleted) {
        events.removeAt(index);
      } else {
        events[index] = edited;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final list = eventsOn(date);

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 400,
          padding: EdgeInsets.fromLTRB(24, 22, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${date.month}월 ${date.day}일',
                    style: AppTextStyles.title2,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_weekdays[date.weekday % 7]}요일',
                    style: AppTextStyles.caption,
                  ),
                  Spacer(),
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    scale: 0.9,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '이 날은 일정이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  // 일정이 많으면 목록만 스크롤한다
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final event in list)
                          _EventRow(event: event, onTap: () => _edit(event)),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 6),
              Pressable(
                onTap: _add,
                scale: 0.99,
                pressedColor: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      '일정 추가',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 하루 목록의 일정 한 줄
class _EventRow extends StatelessWidget {
  _EventRow({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: event.kind.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  [
                    event.timeLabel,
                    event.kind.label,
                    if (event.place.isNotEmpty) event.place,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (event.members.isNotEmpty) ...[
            SizedBox(width: 8),
            AvatarStack(names: event.members, size: 22),
          ],
        ],
      ),
    );
  }
}

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
  late Kind _kind = widget.origin?.kind ?? Kind.meeting;
  late bool _allDay = widget.origin?.allDay ?? false;
  late TimeOfDay _start =
      widget.origin?.start ?? TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _end = widget.origin?.end ?? TimeOfDay(hour: 11, minute: 0);
  late final _members = <String>[...?widget.origin?.members];

  bool get _editing => widget.origin != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _titleFocus.requestFocus();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 3),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked != null) setState(() => _date = picked);
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
    if (!_allDay && _minutes(_end) <= _minutes(_start)) {
      AppToast.show(context, '종료 시간이 시작보다 빨라요');
      return;
    }
    Navigator.pop(
      context,
      Event(
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
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

  void _delete() {
    Navigator.pop(context, widget.origin!..deleted = true);
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
            Text(_editing ? '일정 수정' : '새 일정', style: AppTextStyles.title2),
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
                      onSubmitted: _submit,
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final kind in Kind.values)
                          Pressable(
                            onTap: () => setState(() => _kind = kind),
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
                          label:
                              '${_date.month}.${_date.day} (${_weekdays[_date.weekday % 7]})',
                          onTap: _pickDate,
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
                          onTap: () => setState(() => _allDay = !_allDay),
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
                            onTap: () => _pickTime(start: true),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('~', style: AppTextStyles.caption),
                          ),
                          _PickButton(
                            label: _time(_end),
                            onTap: () => _pickTime(start: false),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 12),
                    _Field(controller: _place, hint: '장소 (선택)'),
                    SizedBox(height: 14),
                    Text('참석자', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final staff in staffList)
                          _PersonChip(
                            staff: staff,
                            joined: _members.contains(staff.name),
                            onTap: () => setState(() {
                              if (_members.contains(staff.name)) {
                                _members.remove(staff.name);
                              } else {
                                _members.add(staff.name);
                              }
                            }),
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _Field(controller: _memo, hint: '메모 (선택)', lines: 2),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                if (_editing)
                  Pressable(
                    onTap: _delete,
                    scale: 0.97,
                    pressedColor: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Text(
                      '삭제',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Spacer(),
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
            ),
          ],
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: staff.name, size: 22),
            SizedBox(width: 6),
            Text(
              staff.name == me ? '나' : staff.name,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: joined ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
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
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final bool bold;
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

// ── 데이터 (목업) ──

/// 일정 종류 — 색으로 종류를 구분한다
enum Kind {
  meeting('회의'),
  lesson('수업'),
  event('이벤트'),
  off('휴무'),
  etc('기타');

  const Kind(this.label);

  final String label;

  Color get color => switch (this) {
    Kind.meeting => AppColors.primary,
    Kind.lesson => AppColors.success,
    Kind.event => AppColors.warning,
    Kind.off => AppColors.gray400,
    Kind.etc => const Color(0xFF7C5CFC),
  };
}

/// 일정 한 건
class Event {
  Event({
    required this.title,
    required this.date,
    this.kind = Kind.meeting,
    this.start,
    this.end,
    this.place = '',
    this.memo = '',
    this.members = const [],
  });

  final String title;

  /// 날짜만 담는다 (시각은 start/end)
  final DateTime date;
  final Kind kind;

  /// null이면 종일 일정
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String place;
  final String memo;
  final List<String> members;

  /// 수정 폼에서 삭제를 눌렀다는 표시
  bool deleted = false;

  bool get allDay => start == null;

  String get timeLabel =>
      allDay ? '종일' : '${_time(start!)} ~ ${_time(end ?? start!)}';
}

/// 등록된 일정 (목업). 달을 옮겨도 유지되도록 모듈 전역으로 둔다.
final events = <Event>[..._seed()];

/// 그날 일정 — 종일이 먼저, 그다음 시작 시각순
List<Event> eventsOn(DateTime date) =>
    events.where((e) => _isSameDay(e.date, date)).toList()..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      if (a.allDay) return 0;
      return _minutes(a.start!).compareTo(_minutes(b.start!));
    });

List<Event> _seed() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
  TimeOfDay at(int hour, [int minute = 0]) =>
      TimeOfDay(hour: hour, minute: minute);

  return [
    Event(
      title: '주간 운영 회의',
      date: day(0),
      kind: Kind.meeting,
      start: at(10),
      end: at(11),
      place: '2층 회의실',
      members: [me, '민중기', '이준승', '전상현'],
      memo: '이번 주 매출과 이벤트 진행 상황 공유',
    ),
    Event(
      title: 'GX 필라테스',
      date: day(0),
      kind: Kind.lesson,
      start: at(19),
      end: at(20),
      place: 'GX룸',
      members: ['유찬빈'],
    ),
    Event(
      title: '신규 회원 상담',
      date: day(1),
      kind: Kind.etc,
      start: at(14),
      end: at(15),
      place: '상담실',
      members: ['전상현'],
    ),
    Event(
      title: '여름 이벤트 오픈',
      date: day(2),
      kind: Kind.event,
      place: '센터 전체',
      members: [me, '민중기', '박준현'],
    ),
    Event(
      title: '기구 정기 점검',
      date: day(3),
      kind: Kind.etc,
      start: at(9),
      end: at(12),
      place: '헬스장',
      members: ['박준현'],
    ),
    Event(title: '박준현 트레이너 휴무', date: day(4), kind: Kind.off, members: ['박준현']),
    Event(
      title: 'PT 신규 등록 상담',
      date: day(5),
      kind: Kind.etc,
      start: at(16),
      end: at(17),
      members: [me],
    ),
    Event(
      title: '월간 전체 회의',
      date: day(7),
      kind: Kind.meeting,
      start: at(9, 30),
      end: at(11),
      place: '2층 회의실',
      members: [me, '이준승', '민중기', '박준현', '유찬빈', '전상현'],
    ),
    Event(
      title: '트레이너 교육',
      date: day(-2),
      kind: Kind.lesson,
      start: at(15),
      end: at(17),
      place: '2층 회의실',
      members: [me, '유찬빈'],
    ),
  ];
}

// ── 표시용 계산 ──

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// '09:30' 형태
String _time(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
