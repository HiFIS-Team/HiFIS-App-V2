import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/event_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reject_reason_dialog.dart';
import '../../core/widgets/scroll_box.dart';

/// 일정 화면
///
/// 데스크톱은 화면을 꽉 채우는 월 달력 한 장으로 보여준다.
/// 날짜 칸을 누르면 그 날 일정이 열리고, 거기서 추가·수정·삭제한다.
/// 모바일 화면은 아직 준비 중 — PC를 먼저 다듬는다.
///
/// 일정은 **보고 있는 달만** 받는다. 한 번 받은 달은 다시 안 받으므로
/// 달을 오가도 요청이 늘지 않는다.
class ScheduleScreen extends StatefulWidget {
  ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// 보고 있는 달 (1일로 맞춰 둔다)
  late DateTime _month = _monthOf(DateTime.now());

  bool _loading = true;

  static DateTime _monthOf(DateTime time) => DateTime(time.year, time.month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 보고 있는 달을 받는다 — 이미 받은 달이면 바로 끝난다
  Future<void> _load() async {
    try {
      await _loadMonth(_month);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _goToday() {
    setState(() => _month = _monthOf(DateTime.now()));
    _load();
  }

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
    final draft = await showEventDialog(context, date: base);
    if (draft == null || !mounted) return;
    try {
      final created = await _createEvent(draft);
      if (!mounted) return;
      setState(() => events.add(created));
      AppToast.show(context, created.pending ? '일정을 신청했어요' : '일정을 추가했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '📅', title: '일정');

    // 그 달 1일이 낀 주의 일요일부터 채운다
    final first = _month.subtract(Duration(days: _month.weekday % 7));
    final last = DateTime(_month.year, _month.month + 1, 0);
    final weeks = ((last.difference(first).inDays + 1) / 7).ceil();
    // 걸치는 일정은 지난달에 시작했어도 이 달에 보이므로 겹치면 센다
    final monthCount = events
        .where((e) => !e.date.isAfter(last) && !e.until.isBefore(_month))
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
                // 받아오는 중에는 개수를 감춘다 — 0에서 튀어 오르는 게 보인다
                if (_loading)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.gray400),
                    ),
                  )
                else
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
                  onTap: _goToday,
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
        // 대기 중인 것은 옅게 깔고 테두리로 가른다 — 아직 확정이 아니다
        color: event.kind.color.withValues(alpha: event.pending ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: event.pending
            ? Border.all(color: event.kind.color.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        event.allDay ? event.title : '${_time(event.start!)} ${event.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: event.kind.color.withValues(alpha: event.pending ? 0.6 : 1),
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
    final draft = await showEventDialog(context, date: widget.date);
    if (draft == null || !mounted) return;
    try {
      final created = await _createEvent(draft);
      if (mounted) setState(() => events.add(created));
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _edit(Event event) async {
    final edited = await showEventDialog(
      context,
      date: event.date,
      origin: event,
    );
    if (edited == null || !mounted) return;

    final id = event.id;
    try {
      if (edited.deleted) {
        if (id != null) await EventApi.delete(id);
        if (mounted) setState(() => events.remove(event));
        return;
      }
      // 반려는 서버가 일정을 지운다 — 되돌릴 게 없어서 목록에서도 뺀다
      if (edited.decision == EventDecision.reject) {
        if (id != null) {
          await EventApi.reject(id, reason: edited.rejectReason);
        }
        if (!mounted) return;
        setState(() => events.remove(event));
        AppToast.show(context, '반려했어요');
        return;
      }
      if (edited.decision == EventDecision.approve) {
        if (id == null) return;
        final ok = _fromServer(await EventApi.approve(id));
        if (!mounted) return;
        setState(() {
          final index = events.indexOf(event);
          if (index >= 0) events[index] = ok;
        });
        AppToast.show(context, '승인했어요');
        return;
      }
      // 서버가 돌려준 값으로 갈아끼운다 — 앱이 계산한 값과 어긋나지 않게
      final saved = id == null ? edited : await _updateEvent(id, edited);
      if (!mounted) return;
      setState(() {
        final index = events.indexOf(event);
        if (index >= 0) events[index] = saved;
      });
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
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
                    if (event.pending) '승인 대기',
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

// ── 데이터 ──

/// 일정 종류 — 색으로 종류를 구분한다
///
/// 서버는 종류를 enum 이 아니라 **자유 문자열**로 받는다. [label] 을 그대로
/// 주고받으므로 라벨을 고치면 이미 쌓인 일정이 '기타'로 떨어진다.
enum Kind {
  meeting('회의'),
  lesson('수업'),
  event('이벤트'),
  off('휴무'),
  etc('기타');

  const Kind(this.label);

  final String label;

  static Kind parse(String? value) =>
      Kind.values.firstWhere((k) => k.label == value, orElse: () => Kind.etc);

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
    DateTime? until,
    this.id,
    this.ownerId,
    this.kind = Kind.meeting,
    this.start,
    this.end,
    this.place = '',
    this.memo = '',
    this.members = const [],
    this.pending = false,
  }) : until = until ?? date;

  /// 서버 uuid — null 이면 아직 안 올린 것 (폼이 막 돌려준 값)
  final String? id;

  /// 만든 사람 — 본인이나 관리자만 고칠 수 있다 ([canEdit])
  final String? ownerId;

  final String title;

  /// 시작하는 날 (시각은 start/end)
  final DateTime date;

  /// 끝나는 날 — 하루짜리면 [date]와 같다
  final DateTime until;

  final Kind kind;

  /// null이면 종일 일정
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// 장소 (회의실·GX룸 같은 것)
  final String place;

  /// 참석자 **이름** — 서버에는 uuid 로 오간다 (`_idsOf` · `_namesOf`)
  final List<String> members;

  final String memo;

  /// 승인 대기 중인지 — MASTER·ADMIN 이 아닌 사람이 올리면 켜진다.
  /// 서버가 걸러 주므로 **올린 사람과 MASTER·ADMIN 에게만** 온다.
  final bool pending;

  /// 수정 폼에서 삭제를 눌렀다는 표시
  bool deleted = false;

  /// 수정 폼에서 승인·반려를 눌렀다는 표시 ([deleted] 와 같은 전달용 값)
  EventDecision? decision;

  /// 반려 사유 — 신청자에게 알림으로 간다
  String? rejectReason;

  bool get allDay => start == null;

  /// 여러 날에 걸치는지
  bool get spans => !_isSameDay(date, until);

  /// 하루짜리는 예전 그대로 시각만, 걸치는 것만 날짜를 붙인다
  String get timeLabel {
    if (!spans) {
      return allDay ? '종일' : '${_time(start!)} ~ ${_time(end ?? start!)}';
    }
    final from = '${date.month}.${date.day}';
    final to = '${until.month}.${until.day}';
    if (allDay) return '$from ~ $to';
    return '$from ${_time(start!)} ~ $to ${_time(end ?? start!)}';
  }

  /// 고치거나 지울 수 있는지 — 서버 `_get_owned` 와 같은 기준이다
  bool get canEdit =>
      id == null ||
      ownerId == null ||
      ownerId == currentUser?.id ||
      myRole.strong;
}

/// 받아 둔 일정. 달을 옮겨도 유지되도록 모듈 전역으로 둔다.
final events = <Event>[];

/// 받아 본 달 (`2026-8`) — 오갈 때마다 다시 받지 않는다
final _loadedMonths = <String>{};

/// 그 달 달력에 그려질 것들을 받는다 — 한 번 받은 달은 넘어간다
///
/// 달력이 **그 달 1일이 낀 주부터** 그려서 앞뒤 달 며칠이 같이 보인다.
/// 그 칸이 비지 않게 앞뒤로 한 주씩 넓혀 받는다.
Future<void> _loadMonth(DateTime month) async {
  final key = '${month.year}-${month.month}';
  if (_loadedMonths.contains(key)) return;
  final rows = await EventApi.list(
    from: DateTime(month.year, month.month).subtract(Duration(days: 7)),
    to: DateTime(
      month.year,
      month.month + 1,
      0,
      23,
      59,
      59,
    ).add(Duration(days: 7)),
  );
  // 넓혀 받은 만큼 옆 달과 겹친다 — 같은 걸 두 번 넣지 않게 id 로 거른다
  final known = {for (final event in events) ?event.id};
  events.addAll([
    for (final row in rows)
      if (!known.contains(row.id)) _fromServer(row),
  ]);
  _loadedMonths.add(key);
}

/// 서버 일정 → 화면 모델
///
/// 색은 서버 값을 안 쓴다 — 앱은 종류에서 색을 뽑는다
Event _fromServer(CalendarEvent row) {
  final start = row.startAt;
  final end = row.endAt;
  return Event(
    id: row.id,
    ownerId: row.ownerId,
    title: row.title,
    date: DateTime(start.year, start.month, start.day),
    until: DateTime(end.year, end.month, end.day),
    kind: Kind.parse(row.category),
    start: row.allDay ? null : TimeOfDay.fromDateTime(start),
    end: row.allDay ? null : TimeOfDay.fromDateTime(end),
    place: row.place ?? '',
    members: _namesOf(row.attendeeIds),
    memo: row.memo ?? '',
    pending: row.pending,
  );
}

/// 참석자 uuid → 이름
///
/// 폼과 아바타 줄이 아직 이름을 사람 키로 쓴다 (backend-gap.md 10번).
/// 명단에 없는 사람(퇴사 등)은 뺀다 — 이름을 모르면 아바타를 못 그린다.
List<String> _namesOf(List<String> ids) => [
  for (final id in ids) ?StaffDirectory.instance.byId(id)?.name,
];

/// 이름 → 참석자 uuid
///
/// 서버 명단에 없는 이름(목업으로 남은 사람)은 보낼 id 가 없어서 빠진다.
List<String> _idsOf(List<String> names) => [
  for (final name in names) ?StaffDirectory.instance.byName(name)?.id,
];

/// 화면 모델 → 서버가 받는 시작·끝
///
/// 종일은 `allDay` 로 따로 보내지만 시각 자체는 여전히 있어야 한다
/// (서버가 `startAt`·`endAt` 을 필수로 받고, 달력도 그날에 그린다).
(DateTime, DateTime) _range(Event event) {
  final from = event.date;
  final to = event.until;
  if (event.allDay) {
    return (
      DateTime(from.year, from.month, from.day),
      DateTime(to.year, to.month, to.day, 23, 59),
    );
  }
  final start = event.start!;
  final end = event.end ?? start;
  return (
    DateTime(from.year, from.month, from.day, start.hour, start.minute),
    DateTime(to.year, to.month, to.day, end.hour, end.minute),
  );
}

/// 서버는 색을 `#RRGGBB` 로 받는다
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 공개 범위 — 앱에 아직 개념이 없다. 서버가 필수로 받아서 한 값으로만 보낸다
const _scope = '전사';

/// 새 일정을 올린다
Future<Event> _createEvent(Event draft) async {
  final (startAt, endAt) = _range(draft);
  final created = await EventApi.create(
    title: draft.title,
    startAt: startAt,
    endAt: endAt,
    allDay: draft.allDay,
    category: draft.kind.label,
    scope: _scope,
    color: _hexOf(draft.kind.color),
    place: draft.place.isEmpty ? null : draft.place,
    attendeeIds: _idsOf(draft.members),
    memo: draft.memo.isEmpty ? null : draft.memo,
  );
  return _fromServer(created);
}

/// 고친 내용을 올린다 — 서버가 돌려준 값으로 갈아끼운다
Future<Event> _updateEvent(String id, Event edited) async {
  final (startAt, endAt) = _range(edited);
  final saved = await EventApi.update(
    id,
    title: edited.title,
    startAt: startAt,
    endAt: endAt,
    allDay: edited.allDay,
    category: edited.kind.label,
    color: _hexOf(edited.kind.color),
    // 비운 장소·메모도 넘겨야 지워진다 (안 넘기면 서버가 그대로 둔다)
    place: edited.place,
    attendeeIds: _idsOf(edited.members),
    memo: edited.memo,
  );
  return _fromServer(saved);
}

/// 그날 일정 — 종일이 먼저, 그다음 시작 시각순
///
/// 여러 날에 걸치는 일정은 **걸치는 날마다** 나온다.
List<Event> eventsOn(DateTime date) =>
    events.where((e) => _covers(e, date)).toList()..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      if (a.allDay) return 0;
      return _minutes(a.start!).compareTo(_minutes(b.start!));
    });

// ── 표시용 계산 ──

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 그 일정이 이 날을 덮는지 — 시작일과 종료일 사이(양끝 포함)
bool _covers(Event event, DateTime day) {
  final target = _dayOf(day);
  return !target.isBefore(_dayOf(event.date)) &&
      !target.isAfter(_dayOf(event.until));
}

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// '8.10 (월)' 형태 — 폼의 날짜 버튼
String _dayLabel(DateTime date) =>
    '${date.month}.${date.day} (${_weekdays[date.weekday % 7]})';

/// '09:30' 형태
String _time(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
