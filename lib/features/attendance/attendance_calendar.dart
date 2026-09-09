part of 'attendance_screen.dart';

// ── 달력 ──

/// 칸에 찍히는 점 하나 — 지름과 사이 간격
///
/// **글자를 안 쓴다** (2026-09-09 대표 요청). 폰 칸이 폭의 7분의 1(약 44)이라
/// `테스트 점장 외 1명 결근` 은 물론 `결근 2` 도 넘쳐서, 줄이거나 자르거나
/// 둘 중 하나였다 — 줄이면 깨알이 되고 자르면 무슨 상태인지 사라진다.
/// 색만 찍고 **누가 어땠는지는 그날을 눌러서** 본다 ([_DayDialog]).
const _dotSize = 5.0;
const _dotGap = 3.0;

/// 그날 칸에 찍을 점 — **상태마다 하나씩**, [_workStatusOrder] 차례대로
///
/// 여기서 세는 무리가 곧 그날을 눌렀을 때 서는 줄이다 ([_DayDialog]).
/// **없는 상태를 지어내지 않는다** — 예전에는 다들 제때 오고 간 날을
/// `전원 출근` + `전원 퇴근` 두 줄로 늘렸는데, 서버가 준 무리는 `퇴근`
/// 하나뿐이라 **달력에는 점이 둘인데 눌러 보면 줄이 하나**였다
/// (2026-09-09 대표 지적). 글자였을 때는 문장으로 읽혀 티가 안 났다.
///
/// 그래서 지금은 이렇게 뜬다 — 다 가고 없으면 진회색 하나,
/// 아직 일하는 사람이 있으면 초록 + 진회색 둘.
List<Color> _rosterDots(DateTime date) {
  final groups = _rosterOf(date);
  if (groups.isEmpty) return const [];
  return [
    for (final (status, _, color) in _workStatusOrder)
      if (groups[status]?.isNotEmpty ?? false) color,
  ];
}

/// 범례 — **아홉 가지를 늘 다 세운다** (2026-09-09 대표 지적)
///
/// 처음에는 그 달에 나온 상태만 세웠는데, **그러면 안 나온 색은 무슨 뜻인지
/// 알 길이 없다.** 대표 달력에 미출근·결근·월차 셋만 뜬 달이면 범례도 셋이라,
/// 다음 달에 보라색 점이 떠도 그게 야근인지 모른다.
///
/// 칸의 점과 같은 차례다 — 눈이 왼쪽부터 짝지어 읽는다.
List<(String, Color)> get _bossLegend => [
  for (final (_, label, color) in _workStatusOrder) (label, color),
];

/// 개인 달력의 범례 — 이쪽도 **늘 다 세운다**
///
/// `휴무` 는 뺀다 — 점을 안 찍는 상태라 범례에 세우면 없는 색을 설명하는 셈이다.
const _myLegend = <(String, Color)>[
  ('정상', AppColors.success),
  ('지각', AppColors.workLate),
  ('조기 퇴근', AppColors.workEarly),
  ('퇴근 누락', AppColors.workNoCheckout),
  ('결근', AppColors.workAbsent),
  ('월차', AppColors.workLeave),
];

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
    // **대표 칸도 같은 높이다** (2026-09-09). 예전에는 상태마다 글자 한 줄이
    // 들어가서 그 달에서 제일 바쁜 날에 맞춰 칸이 자랐는데, 점은 여러 개가
    // 한 줄에 서므로 자랄 이유가 없다
    final cellHeight = isDesktop ? 84.0 : 62.0;
    final legend = _isBoss ? _bossLegend : _myLegend;

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
                // 범례는 달력 **아래** 한 줄이다 — 여기 두면 상태가 넷을
                // 넘길 때 달 이름을 밀어낸다 (아홉 가지까지 난다)
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
          // **일정 달력과 같은 격자다** (2026-09-09 대표 요청). 예전에는 칸마다
          // 여백을 두고 둥글렸는데, 한 화면 안에서 달력이 두 모양이면 안 된다
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
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
                              final last = row == rows - 1;
                              if (dayNumber < 1 || dayNumber > lastDay) {
                                // 빈 칸도 선은 그린다 — 안 그리면 달 끝에서
                                // 격자가 이 빠진 것처럼 보인다
                                return _EmptyCell(
                                  height: cellHeight,
                                  lastRow: last,
                                  lastColumn: col == 6,
                                );
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
                                lastRow: last,
                                lastColumn: col == 6,
                                onTap: () => onPick(date),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          // 점이 무슨 뜻인지 알 수 있는 곳이 여기뿐이라 **다 세운다**
          if (legend.isNotEmpty) ...[
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final (label, color) in legend) _legend(label, color),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
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

  /// 범례 한 칸 — 칸에 찍히는 점과 **같은 크기·같은 색**이다
  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 4),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
    ],
  );
}

/// 격자에서 빈 자리 — 앞뒤 달 날짜가 놓일 칸
///
/// **선은 그린다.** 아예 비우면 달 첫 주·끝 주에서 격자가 이 빠져 보인다.
class _EmptyCell extends StatelessWidget {
  const _EmptyCell({
    required this.height,
    required this.lastRow,
    required this.lastColumn,
  });

  final double height;
  final bool lastRow;
  final bool lastColumn;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: _cellBorder(lastRow: lastRow, lastColumn: lastColumn),
  );
}

/// 칸을 가르는 선 — 마지막 줄·마지막 칸은 바깥 테두리가 대신한다
BoxDecoration _cellBorder({
  required bool lastRow,
  required bool lastColumn,
  Color? color,
}) => BoxDecoration(
  color: color,
  border: Border(
    right: BorderSide(
      color: lastColumn ? Colors.transparent : AppColors.gray100,
    ),
    bottom: BorderSide(color: lastRow ? Colors.transparent : AppColors.gray100),
  ),
);

/// 달력 칸 하나 — 날짜 + 그날 상태를 나타내는 점
///
/// **글자를 안 쓴다** (2026-09-09 대표 요청). 무슨 상태인지는 달력 아래
/// 범례가 알려주고, 누가 어땠는지는 그날을 누르면 나온다 ([_DayDialog]).
class _DayCell extends StatefulWidget {
  _DayCell({
    required this.date,
    required this.day,
    required this.leave,
    required this.today,
    required this.height,
    required this.lastRow,
    required this.lastColumn,
    required this.onTap,
  });

  final DateTime date;
  final _Day? day;
  final _Leave? leave;
  final bool today;
  final double height;
  final bool lastRow;
  final bool lastColumn;
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
        child: Container(
          height: widget.height,
          padding: EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: _cellBorder(
            lastRow: widget.lastRow,
            lastColumn: widget.lastColumn,
            // 잡아둔 월차는 칸 전체를 옅게 물들여 앞으로의 일정이 눈에 띈다
            color: leave != null
                ? AppColors.primary.withValues(alpha: 0.08)
                : _hover
                ? AppColors.gray50
                : null,
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
              SizedBox(height: 4),
              // 대표는 자기 기록이 아니라 그날 전 직원이 어땠는지를 본다
              Expanded(
                child: _isBoss ? _rosterDotRow(date) : _myDot(day, leave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 대표 칸 — 그날 나온 상태마다 점 하나
  ///
  /// **`Wrap` 이라 넘치면 다음 줄로 간다.** 폰 칸이 좁아서 한 줄에 서너 개고,
  /// 아홉 가지가 다 나온 날은 세 줄이 된다 — 칸 높이(62) 안에 든다.
  Widget _rosterDotRow(DateTime date) {
    final dots = _rosterDots(date);
    if (dots.isEmpty) return SizedBox();
    return Wrap(
      spacing: _dotGap,
      runSpacing: _dotGap,
      children: [for (final color in dots) _dot(color)],
    );
  }

  /// 개인 칸 — 그날 상태는 하나뿐이라 점도 하나다
  ///
  /// **아직 결재 안 난 월차는 속을 비운다** — 예전 알약이 테두리만 둘러
  /// '예정' 임을 알리던 것과 같은 뜻이다.
  Widget _myDot(_Day? day, _Leave? leave) {
    if (leave != null) {
      return _dot(
        AppColors.primary,
        hollow: leave.status == _LeaveStatus.pending,
      );
    }
    if (day == null || day.status == _DayStatus.off) return SizedBox();
    return _dot(day.status.color);
  }

  Widget _dot(Color color, {bool hollow = false}) => Container(
    width: _dotSize,
    height: _dotSize,
    decoration: BoxDecoration(
      color: hollow ? Colors.transparent : color,
      shape: BoxShape.circle,
      border: hollow ? Border.all(color: color, width: 1.2) : null,
    ),
  );
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
