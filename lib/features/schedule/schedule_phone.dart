part of 'schedule_screen.dart';

// ── 폰 화면 ──

/// 폰: 한 주를 세로 일곱 줄로 본다. 날짜를 누르면 그날 일정이 열린다.
///
/// 달 격자를 폰에 그리면 칸 하나가 폭의 7분의 1(약 45)이라 일정 칩에 제목이
/// 두어 글자밖에 안 들어가고, 나머지는 `+N` 으로 접혀서 **뭐가 있는지 알 수 없다.**
/// 하루가 가로로 긴 줄이 되면 제목이 그대로 보인다.
/// **PC 는 폭이 남아 달 그대로**다 (근태 달력과 같은 갈래다).
///
/// **폰에는 일정 탭이 없다** — 홈 왼쪽 위 바로가기로만 들어온다. 그래서
/// 뒤로가기가 있어야 해서 [PhoneDetailScaffold] 를 쓴다
/// (왼쪽 `<` · 가운데 제목 · 오른쪽 `+` — 알림 화면과 같은 머리 모양).
class _SchedulePhone extends StatelessWidget {
  _SchedulePhone({
    required this.week,
    required this.loading,
    required this.onMove,
    required this.onToday,
    required this.onAdd,
    required this.onPick,
    required this.onScope,
    required this.onPerson,
    required this.personLabel,
  });

  /// 보고 있는 주의 일요일
  final DateTime week;
  final bool loading;

  /// -1 이면 지난 주, 1 이면 다음 주
  final ValueChanged<int> onMove;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onPick;

  /// 공통 ↔ 개인 목록바 — PC 와 같은 위젯을 쓴다
  final ValueChanged<int> onScope;

  /// 개인 칸에서 사람 고르기 (MASTER·ADMIN 만 버튼이 뜬다)
  final VoidCallback onPerson;
  final String personLabel;

  /// 그 주에 걸치는 날짜 일곱 개
  List<DateTime> get _dates => [
    for (var i = 0; i < 7; i++) DateTime(week.year, week.month, week.day + i),
  ];

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    // 걸치는 일정은 지난주에 시작했어도 이 주에 보이므로 겹치면 센다
    final count = events
        .where((e) => !e.date.isAfter(dates.last) && !e.until.isBefore(week))
        .length;

    final page = PhoneDetailScaffold(
      title: '일정',
      actions: [GlassIconButton(symbol: 'plus', onPressed: onAdd)],
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMove(-1),
              ),
              SizedBox(width: 6),
              // 달을 넘어가는 주도 있어서 양끝을 다 적는다
              Text(
                '${dates.first.month}.${dates.first.day}'
                ' ~ ${dates.last.month}.${dates.last.day}',
                style: AppTextStyles.title3,
              ),
              SizedBox(width: 6),
              _RoundButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMove(1),
              ),
              Spacer(),
              // 받아오는 중에는 개수를 감춘다 — 0에서 튀어 오르는 게 보인다
              if (loading)
                Skeleton(width: 46, height: 12)
              else
                Text('일정 $count', style: AppTextStyles.caption),
              SizedBox(width: 10),
              Pressable(
                onTap: onToday,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  '오늘',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _ScopeBar(
            onScope: onScope,
            onPerson: onPerson,
            personLabel: personLabel,
          ),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              children: [
                // 일정이 없는 날도 줄은 세운다 — 주말이 어디인지가 보여야 한다
                for (final date in dates)
                  _DayRow(date: date, onTap: onPick, skeleton: loading),
              ],
            ),
          ),
        ],
      ),
    );

    // 뼈대가 뜰 때만 감싼다 (PC 달력과 같은 사정 — 반짝임 컨트롤러를 늘 굴리지 않는다)
    return loading ? SkeletonGroup(child: page) : page;
  }
}

/// 주 달력의 하루 — 날짜 + 그날 일정 칩
class _DayRow extends StatelessWidget {
  _DayRow({required this.date, required this.onTap, this.skeleton = false});

  final DateTime date;
  final ValueChanged<DateTime> onTap;

  /// 아직 받아오는 중 — 일정 자리에 회색 칩을 깐다 (날짜·요일은 그대로 둔다)
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    final list = skeleton ? const <Event>[] : eventsOn(date);
    final chips = skeleton ? _skeletonChips(date) : 0;
    final today = _isSameDay(date, DateTime.now());
    final sunday = date.weekday == DateTime.sunday;

    return Pressable(
      onTap: () => onTap(date),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 오늘은 달 달력 칸과 같은 파란 동그라미
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
                  _weekdays[date.weekday % 7],
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
                // 첫 칩 가운데를 날짜 동그라미 가운데에 맞춘다 (2 + 26/2 = 15 = 30/2)
                padding: EdgeInsets.only(
                  top: (skeleton ? chips == 0 : list.isEmpty) ? 5 : 2,
                ),
                child: skeleton
                    // 빈 날은 뼈대도 비운다 — 칸마다 깔면 '매일 일정이 있다'가 된다
                    ? Column(
                        children: [
                          for (var i = 0; i < chips; i++)
                            _SkeletonChip(big: true),
                        ],
                      )
                    : list.isEmpty
                    ? Text(
                        '—',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.gray300,
                        ),
                      )
                    // 줄이 가로로 길어서 접을 것이 없다 — 그날 것을 다 세운다
                    : Column(
                        children: [
                          for (final event in list)
                            _Chip(event: event, big: true),
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
