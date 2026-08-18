import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/project/event_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/scroll_box.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../core/widgets/input/mini_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/util/layout.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/screen_refresh.dart';
part 'schedule_phone.dart';
part 'schedule_day.dart';
part 'schedule_form.dart';
part 'schedule_data.dart';

/// 일정 화면
///
/// PC 는 화면을 꽉 채우는 월 달력 한 장, **폰은 한 주를 세로 일곱 줄**로 본다
/// ([_SchedulePhone]). 날짜를 누르면 그 날 일정이 열리고, 거기서 추가·수정·삭제한다.
///
/// **폰은 탭이 없어 홈 왼쪽 위 바로가기로 들어온다.**
///
/// 일정은 **보고 있는 달만** 받는다. 한 번 받은 달은 다시 안 받으므로
/// 달을 오가도 요청이 늘지 않는다. 폰도 달 단위로 받는다 — 주가 달을 걸쳐도
/// [_loadMonth] 가 앞뒤로 한 주씩 넓혀 받아서 빈 날이 안 생긴다.
class ScheduleScreen extends StatefulWidget {
  ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with ScreenRefresh<ScheduleScreen> {
  /// 보고 있는 달 (1일로 맞춰 둔다) — PC 달력이 쓴다
  late DateTime _month = _monthOf(DateTime.now());

  /// 보고 있는 주의 일요일 — 폰 달력이 쓴다
  late DateTime _week = _sundayOf(DateTime.now());

  bool _loading = true;

  static DateTime _monthOf(DateTime time) => DateTime(time.year, time.month);

  /// 그 날이 낀 주의 일요일 — 달력이 일요일 시작이라 여기에 맞춘다
  static DateTime _sundayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day - time.weekday % 7);

  /// 받아야 하는 달 — 폰은 보고 있는 주가 낀 달이다
  DateTime get _visibleMonth => isDesktop ? _month : _monthOf(_week);

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 보고 있는 달을 받는다 — 이미 받은 달이면 바로 끝난다
  Future<void> _load() async {
    try {
      await _loadMonth(_visibleMonth);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _moveWeek(int delta) {
    setState(
      () => _week = DateTime(_week.year, _week.month, _week.day + delta * 7),
    );
    _load();
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = _monthOf(now);
      _week = _sundayOf(now);
    });
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

  /// 갈래를 옮긴다 — 받아 둔 걸 버리고 다시 받는다
  void _pickScope(int index) {
    final next = ScheduleScope.values[index];
    if (next == scheduleScope) return;
    setState(() {
      scheduleScope = next;
      // 공통으로 돌아가면 보던 사람을 놓는다 — 다시 개인으로 올 때
      // 남의 달력이 그대로 떠 있으면 자기 것으로 착각한다
      if (next == ScheduleScope.company) personalOwnerId = null;
      _resetLoaded();
      _loading = true;
    });
    _load();
  }

  /// 누구의 개인 일정을 볼지 — **MASTER·ADMIN 만 부른다**
  Future<void> _pickPerson() async {
    final picked = await showAppDialog<String>(
      context,
      (_) => _PersonPicker(selected: personalOwnerId ?? currentUser?.id),
    );
    if (picked == null || !mounted) return;
    setState(() {
      personalOwnerId = picked == currentUser?.id ? null : picked;
      _resetLoaded();
      _loading = true;
    });
    _load();
  }

  /// 지금 보고 있는 사람 이름 — 개인 칸의 이름 버튼에 뜬다
  String get _personLabel =>
      StaffDirectory.instance.byId(personalOwnerId ?? '')?.name ?? '내 일정';

  /// 남의 개인 일정을 보고 있는가 — 그때는 추가를 막는다
  bool get _viewingOther =>
      scheduleScope == ScheduleScope.personal &&
      personalOwnerId != null &&
      personalOwnerId != currentUser?.id;

  Future<void> _add() async {
    // 남의 달력에 내 일정을 만들게 되는 자리라 아예 안 연다
    // (서버는 늘 **부른 사람** 것으로 만든다 — owner_id=current.id)
    if (_viewingOther) {
      AppToast.show(context, '$_personLabel님 일정은 볼 수만 있어요');
      return;
    }
    final now = DateTime.now();
    // 오늘이 보이는 자리면 오늘, 아니면 보고 있는 달·주의 첫날을 기본값으로
    final start = isDesktop ? _month : _week;
    final base = (isDesktop ? _monthOf(now) : _sundayOf(now)) == start
        ? DateTime(now.year, now.month, now.day)
        : start;
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
    if (!isDesktop) {
      return _SchedulePhone(
        week: _week,
        loading: _loading,
        onMove: _moveWeek,
        onToday: _goToday,
        onAdd: _add,
        onPick: _openDay,
        onScope: _pickScope,
        onPerson: _pickPerson,
        personLabel: _personLabel,
      );
    }

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
          Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 28, 14),
            child: _ScopeBar(
              onScope: _pickScope,
              onPerson: _pickPerson,
              personLabel: _personLabel,
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
/// 남의 개인 일정을 볼 수 있는 권한 — **MASTER·ADMIN 만** (서버와 같은 기준)
bool get _canSeeOthers => myRole == Role.master || myRole == Role.admin;

/// `공통 일정 / 개인 일정` 목록바 — 달력 위 한 줄
///
/// 업무 화면의 `공통 업무 / 내 업무` 와 **같은 물건**이다 (`SegmentedTabs`).
/// 한 화면 안에서 칸을 가르는 모양이 둘로 갈리면 안 된다.
///
/// 오른쪽 이름 버튼은 **개인 칸이고 MASTER·ADMIN 일 때만** 나온다.
/// 직원에게는 고를 것이 자기밖에 없어서 자리만 차지한다.
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.onScope,
    required this.onPerson,
    required this.personLabel,
  });

  final ValueChanged<int> onScope;
  final VoidCallback onPerson;
  final String personLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SegmentedTabs(
        labels: [for (final scope in ScheduleScope.values) scope.label],
        selected: scheduleScope.index,
        onSelect: onScope,
        expand: false,
      ),
      if (scheduleScope == ScheduleScope.personal && _canSeeOthers) ...[
        SizedBox(width: 12),
        Pressable(
          onTap: onPerson,
          scale: 0.96,
          pressedColor: AppColors.gray100,
          borderRadius: BorderRadius.circular(100),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                personLabel,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// 누구의 개인 일정을 볼지 고르는 시트 — **본인이 맨 위**
class _PersonPicker extends StatelessWidget {
  const _PersonPicker({required this.selected});

  /// 지금 보고 있는 사람
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final me = currentUser?.id;
    final people = [
      for (final person in StaffDirectory.instance.employees)
        if (person.id != me) person,
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('누구의 일정을 볼까요', style: AppTextStyles.title3),
          SizedBox(height: 14),
          ScrollBox(
            maxHeight: 320,
            child: Column(
              children: [
                if (me != null)
                  _PersonRow(
                    name: '내 일정',
                    picked: selected == me,
                    onTap: () => Navigator.pop(context, me),
                  ),
                for (final person in people)
                  _PersonRow(
                    name: person.name,
                    picked: selected == person.id,
                    onTap: () => Navigator.pop(context, person.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.picked,
    required this.onTap,
  });

  final String name;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.98,
    borderRadius: BorderRadius.circular(12),
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        Avatar(
          name: name == '내 일정' ? (currentUser?.name ?? '') : name,
          size: 32,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(
              fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
              color: picked ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
        if (picked)
          Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
      ],
    ),
  );
}

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
  _Chip({required this.event, this.big = false});

  final Event event;

  /// 폰 주 달력용 — 줄이 가로로 길어서 칩도 크게 잡는다.
  /// PC 달 격자는 칸이 좁아 예전 크기 그대로다
  /// (칸에 몇 개 들어가는지 재는 `_DayCell` 의 21 이 그 크기를 본다).
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: big ? 26 : 19,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: big ? 4 : 2),
      padding: EdgeInsets.symmetric(horizontal: big ? 10 : 6),
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
          fontSize: big ? 13 : 11,
          color: event.kind.color.withValues(alpha: event.pending ? 0.6 : 1),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
