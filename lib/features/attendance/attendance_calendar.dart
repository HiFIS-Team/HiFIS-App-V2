part of 'attendance_screen.dart';

// ── 달력 ──

/// 상태 한 줄이 잡아먹는 높이 — 위 여백 2 + 안쪽 위아래 4 + 글자 13(10 × 1.3)
const _rosterLineHeight = 19.0;

/// 줄이 서기 전에 이미 나간 높이 — 칸 위아래 여백 11 + 날짜 동그라미 22
const _rosterChrome = 33.0;

/// 그날 칸에 설 상태 줄 — `이름 외 N명 상태`
///
/// 다들 제때 오고 갔으면 줄을 늘어놓지 않고 `전원 출근`(+`전원 퇴근`)으로 접는다.
/// **칸 높이를 재는 쪽과 그리는 쪽이 같은 걸 봐야** 해서 밖으로 빼 뒀다 —
/// 따로 세면 한쪽이 틀려서 칸이 넘친다.
///
/// **한 사람이라도 미출근·결근이면 안 접는다** (2026-08-19 대표 지적).
/// 예전에는 아직 안 온 사람이 서버 명단에서 통째로 빠져서, 남은 사람만 보고
/// `전원 출근` 으로 접혔다 — 전원이 온 게 아닌데 그렇게 떴다.
List<(String, Color)> _rosterLines(DateTime date) {
  final groups = _rosterOf(date);
  if (groups.isEmpty) return const [];

  final lines = <(String, Color)>[];
  var onlyPlain = true;
  for (final (status, label, color, plain) in _workStatusOrder) {
    final names = groups[status];
    if (names == null || names.isEmpty) continue;
    if (!plain) onlyPlain = false;
    lines.add(('${_whoIn(names)} $label', color));
  }
  if (lines.isEmpty) return const [];
  if (!onlyPlain) return lines;

  // 아직 센터에 있는 사람이 하나도 없어야 `전원 퇴근` 까지 붙는다 —
  // 다 왔지만 아직 일하는 중이면 `전원 출근` 한 줄이다
  final working = groups[AttendanceStatus.inProgress] ?? const <String>[];
  return [
    ('전원 출근', AppColors.workIn),
    if (working.isEmpty) ('전원 퇴근', AppColors.workOut),
  ];
}

/// `김트레이너` · `김트레이너 외 3명`
String _whoIn(List<String> names) =>
    names.length == 1 ? names.first : '${names.first} 외 ${names.length - 1}명';

/// 화면의 주인공 — 칸마다 그날의 근무나 월차가 바로 보인다
class _MonthCalendar extends StatelessWidget {
  _MonthCalendar({
    required this.month,
    required this.days,
    required this.leaves,
    required this.onMove,
    required this.onPick,
  });

  final DateTime month;
  final List<_Day> days;
  final List<_Leave> leaves;
  final ValueChanged<int> onMove;
  final ValueChanged<DateTime> onPick;

  _Day? _dayOf(DateTime date) {
    for (final day in days) {
      if (_sameDay(day.date, date)) return day;
    }
    return null;
  }

  _Leave? _leaveOf(DateTime date) {
    for (final leave in leaves) {
      if (leave.covers(date) && leave.status.counted) {
        return leave;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    // 1일이 무슨 요일인지에 따라 앞을 비운다 (일요일 시작)
    final lead = month.weekday % 7;
    final rows = ((lead + lastDay) / 7).ceil();
    // 칸 안에 근무 시간까지 들어가야 해서 넉넉히 잡는다.
    // 대표 칸은 상태마다 한 줄씩 들어가서 더 높다
    final cellHeight = _isBoss
        ? _bossCellHeight(month, lastDay)
        : (isDesktop ? 84.0 : 62.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _arrow(CupertinoIcons.chevron_left, () => onMove(-1)),
                SizedBox(width: 10),
                Text(
                  '${month.year}년 ${month.month}월',
                  style: AppTextStyles.title3,
                ),
                SizedBox(width: 10),
                _arrow(CupertinoIcons.chevron_right, () => onMove(1)),
                Spacer(),
                // 폰은 자리가 좁아 범례를 뺀다
                if (isDesktop)
                  for (final status in [
                    _DayStatus.normal,
                    _DayStatus.late,
                    _DayStatus.absent,
                    _DayStatus.leave,
                  ]) ...[_legend(status), SizedBox(width: 9)],
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          for (var row = 0; row < rows; row++)
            // 칸이 스스로 높이를 정하므로 stretch를 쓰면 안 된다
            // (세로가 무한대인 스크롤 안에서는 높이를 못 정해 터진다)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + col - lead + 1;
                        if (dayNumber < 1 || dayNumber > lastDay) {
                          return SizedBox(height: cellHeight);
                        }
                        final date = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        return _DayCell(
                          date: date,
                          day: _dayOf(date),
                          leave: _leaveOf(date),
                          today: _sameDay(date, now),
                          height: cellHeight,
                          onTap: () => onPick(date),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// 대표 칸 높이 — **그 달에서 제일 바쁜 날**에 맞춘다
  ///
  /// 상태가 여러 가지 나온 날은 줄이 그만큼 늘어나는데 칸이 고정이면 넘친다
  /// (폰은 4줄부터 5px, PC 는 6줄부터 15px — 실제로 났다).
  ///
  /// 줄을 잘라서 맞추지 않는다. 이 화면은 **그날 누가 어땠는지**를 보는 자리라
  /// 잘린 상태는 아예 없던 일처럼 보인다. 칸이 자라는 쪽이 낫다.
  ///
  /// 조용한 달은 지금까지의 높이 그대로다 — 폰 3줄·PC 5줄까지는 안 자란다.
  double _bossCellHeight(DateTime month, int lastDay) {
    var most = 0;
    for (var day = 1; day <= lastDay; day++) {
      final count = _rosterLines(DateTime(month.year, month.month, day)).length;
      if (count > most) most = count;
    }
    final base = isDesktop ? 132.0 : 104.0;
    final needed = _rosterChrome + most * _rosterLineHeight;
    return needed > base ? needed : base;
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    ),
  );

  Widget _legend(_DayStatus status) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
      ),
      SizedBox(width: 3),
      Text(status.label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
    ],
  );
}

/// 달력 칸 하나 — 날짜 + 그날의 한 줄 요약
class _DayCell extends StatefulWidget {
  _DayCell({
    required this.date,
    required this.day,
    required this.leave,
    required this.today,
    required this.height,
    required this.onTap,
  });

  final DateTime date;
  final _Day? day;
  final _Leave? leave;
  final bool today;
  final double height;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final day = widget.day;
    final leave = widget.leave;
    final sunday = date.weekday == DateTime.sunday;
    // 기록도 월차도 없는 앞날
    final empty = day == null && leave == null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.96,
        child: Container(
          height: widget.height,
          margin: EdgeInsets.all(2),
          padding: EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: BoxDecoration(
            // 잡아둔 월차는 칸 전체를 옅게 물들여 앞으로의 일정이 눈에 띈다
            color: leave != null
                ? AppColors.primary.withValues(alpha: 0.08)
                : _hover
                ? AppColors.gray50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.today ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 12,
                    fontWeight: widget.today
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.today
                        ? Colors.white
                        : empty
                        ? AppColors.gray300
                        : sunday
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isBoss)
                // 대표는 자기 기록이 아니라 그날 전 직원이 어땠는지를 본다
                Expanded(child: _roster(date))
              else ...[
                Spacer(),
                if (leave != null)
                  _tag(
                    // 갈래마다 제 이름으로 — 병가·기타가 `반차` 로 뜨면 안 된다
                    switch (leave.kind) {
                      _LeaveKind.full => '월차',
                      _LeaveKind.morning || _LeaveKind.afternoon => '반차',
                      _LeaveKind.sick => '병가',
                      _LeaveKind.etc => '휴가',
                    },
                    AppColors.primary,
                    faded: leave.status == _LeaveStatus.pending,
                  )
                else if (day != null)
                  switch (day.status) {
                    // 정상 근무는 배지 대신 근무 시간만 담백하게 보여준다
                    _DayStatus.normal => _hours(day),
                    _DayStatus.late => _tag('지각', AppColors.warning),
                    _DayStatus.early => _tag('조퇴', AppColors.warning),
                    _DayStatus.noCheckout => _tag(
                      '퇴근누락',
                      AppColors.workNoCheckout,
                    ),
                    _DayStatus.absent => _tag('결근', AppColors.error),
                    _DayStatus.leave => _tag('월차', AppColors.primary),
                    _DayStatus.off => SizedBox(),
                  },
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 대표 칸 — 상태마다 `이름 외 N명 상태` 한 줄
  ///
  /// 줄을 세는 건 [_rosterLines] 가 한다 — 칸 높이도 그걸 보고 잡는다.
  Widget _roster(DateTime date) {
    final lines = _rosterLines(date);
    if (lines.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // 줄이 하나든 넷이든 칸 가운데에 모인다 — 위나 아래로 붙으면 날짜와 떨어져 보인다
      mainAxisAlignment: MainAxisAlignment.center,
      children: [for (final (text, color) in lines) _line(text, color)],
    );
  }

  /// 상태 한 줄 — 옅은 바탕에 같은 색 글씨 (앱의 알약과 같은 방식)
  Widget _line(String text, Color color) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 2),
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        height: 1.3,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _hours(_Day day) => Row(
    children: [
      Container(
        width: 5,
        height: 5,
        margin: EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _shortDuration(day.worked),
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ],
  );

  /// 지각·결근·월차처럼 눈에 띄어야 하는 것만 알약으로
  Widget _tag(String label, Color color, {bool faded = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: faded ? 0.1 : 0.16),
      borderRadius: BorderRadius.circular(6),
      // 아직 결재 전인 월차는 테두리만 둘러 예정임을 알린다
      border: faded ? Border.all(color: color.withValues(alpha: 0.4)) : null,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// 대표·관리자 **폰** 달력 — 한 주를 세로 일곱 줄로 본다
///
/// 대표 칸에는 그날 누가 어땠는지가 이름으로 들어가서, 한 칸이 폰 폭의 7분의 1
/// (약 53)이면 `김트레이너 외 3명 출근` 이 들어갈 자리가 없다. 게다가 칸이
/// 상태 줄만큼 자라서([_bossCellHeight]) 한 달을 세우면 화면이 한참 길어진다.
/// 그래서 폰에서만 주 단위로 접고, **PC 는 폭이 남아 달 그대로**다.
///
/// 하루가 가로로 긴 줄 하나라 지금 칸에 들어가던 이름 줄을 그대로 쓴다.
class _WeekCalendar extends StatelessWidget {
  _WeekCalendar({
    required this.start,
    required this.onMove,
    required this.onPick,
  });

  /// 그 주의 일요일 — 달력이 일요일 시작이라 여기에 맞춘다
  final DateTime start;

  /// -1 이면 지난 주, 1 이면 다음 주
  final ValueChanged<int> onMove;
  final ValueChanged<DateTime> onPick;

  /// 그 주에 걸치는 날짜 일곱 개
  List<DateTime> get _dates => [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];

  /// `8.3(일) ~ 8.9(토)` — 달을 넘어가도 어느 주인지 바로 보인다
  String get _title {
    final end = _dates.last;
    return '${start.month}.${start.day}(${_weekday(start)})'
        ' ~ ${end.month}.${end.day}(${_weekday(end)})';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dates = _dates;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 18, 14, 8),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _arrow(CupertinoIcons.chevron_left, () => onMove(-1)),
                SizedBox(width: 10),
                Expanded(
                  child: Center(
                    child: Text(_title, style: AppTextStyles.title3),
                  ),
                ),
                SizedBox(width: 10),
                _arrow(CupertinoIcons.chevron_right, () => onMove(1)),
              ],
            ),
          ),
          SizedBox(height: 8),
          // 기록이 없는 날도 줄은 세운다 — 주말이 어디인지가 보여야 한다
          for (final date in dates)
            _WeekRow(
              date: date,
              today: _sameDay(date, now),
              onTap: () => onPick(date),
            ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    ),
  );
}

/// 주 달력의 하루 — 날짜 + 그날 상태 줄들
class _WeekRow extends StatelessWidget {
  _WeekRow({required this.date, required this.today, required this.onTap});

  final DateTime date;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lines = _rosterLines(date);
    final sunday = date.weekday % 7 == 0;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 칸 — 오늘은 달력 칸과 같은 파란 동그라미
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: today
                  ? BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${date.day}',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: today
                      ? Colors.white
                      : sunday
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 6),
            SizedBox(
              width: 20,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  _weekday(date),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: sunday ? AppColors.error : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 5),
                child: lines.isEmpty
                    ? Text(
                        '—',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.gray300,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < lines.length; i++) ...[
                            if (i > 0) SizedBox(height: 3),
                            Text(
                              lines[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: lines[i].$2,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 받아오는 동안의 뼈대 — 요약 · 월차 잔여 · 달력 순서를 그대로 잡아 둔다
///
/// 달력 칸 높이(62)와 카드 안쪽 여백이 진짜 달력과 같다. 요청이 일곱 개라
/// 첫 로딩이 제일 긴 화면이어서, 여기가 비어 있으면 유난히 오래 느껴진다.
class _AttendanceSkeleton extends StatelessWidget {
  _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: PhoneListScaffold(
      title: '근태·월차',
      children: [
        // 이번 달 요약
        SkeletonCard(
          children: [
            Skeleton(width: 96, height: 14),
            SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Skeleton(width: 34, height: 20),
                        SizedBox(height: 8),
                        Skeleton(width: 44, height: 11),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        // 남은 월차
        SkeletonCard(
          children: [
            Row(
              children: [
                Skeleton(width: 72, height: 14),
                Spacer(),
                Skeleton(width: 76, height: 34, radius: 10),
              ],
            ),
            SizedBox(height: 16),
            Skeleton(height: 8, radius: 4),
          ],
        ),
        SizedBox(height: 12),
        // 달력 — 칸 높이 62 는 _MonthCalendar 와 같은 값이다
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(14, 18, 14, 14),
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    SkeletonCircle(size: 18),
                    SizedBox(width: 10),
                    Skeleton(width: 96, height: 16),
                    SizedBox(width: 10),
                    SkeletonCircle(size: 18),
                    Spacer(),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(child: Skeleton(width: 12, height: 9)),
                    ),
                ],
              ),
              SizedBox(height: 8),
              for (var row = 0; row < 5; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: SizedBox(
                          height: 62,
                          child: Center(
                            child: Skeleton(width: 22, height: 22, radius: 8),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
