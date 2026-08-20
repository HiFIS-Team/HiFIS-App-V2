part of 'attendance_screen.dart';

// ── 달 요약 ──

/// 보고 있는 달의 근무일·근무시간·지각·결근
///
/// 대표는 출퇴근을 안 찍어서 이 값이 전부 0이다. 그래서 대표 화면에서는
/// 같은 자리에 **오늘 누가 어떤지**를 이름으로 띄운다 ([_TodayBoard]).
class _MonthSummary extends StatelessWidget {
  _MonthSummary({required this.days, required this.month});

  final List<_Day> days;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    if (_isBoss) return _TodayBoard();

    final worked = days.where((d) => d.status.worked).length;
    final total = days.fold(Duration.zero, (sum, d) => sum + d.worked);
    final late = days.where((d) => d.status == _DayStatus.late).length;
    final absent = days.where((d) => d.status == _DayStatus.absent).length;
    final early = days.where((d) => d.status == _DayStatus.early).length;
    final leave = days.where((d) => d.status == _DayStatus.leave).length;
    final off = days.where((d) => d.status == _DayStatus.off).length;
    final average = worked == 0
        ? Duration.zero
        : Duration(minutes: total.inMinutes ~/ worked);
    final now = DateTime.now();
    final thisMonth = month.year == now.year && month.month == now.month;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${month.month}월 근무', style: AppTextStyles.label),
              ),
              Text(
                // 이번 달은 아직 안 끝났다는 걸 알려준다
                thisMonth ? '오늘까지' : '한 달 전체',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '$worked일', AppColors.textPrimary),
              _divider(),
              // 폰은 칸이 좁아 네 개면 숫자가 줄어든다.
              // 총 근무는 아래 날짜별 목록에서 다시 볼 수 있어 여기서 뺀다
              if (isDesktop) ...[
                _stat('총 근무', _duration(total), AppColors.primary),
                _divider(),
              ],
              _stat(
                '지각',
                '$late회',
                late > 0 ? AppColors.warning : AppColors.textPrimary,
              ),
              _divider(),
              _stat(
                '결근',
                '$absent회',
                absent > 0 ? AppColors.error : AppColors.textPrimary,
              ),
            ],
          ),
          // 데스크톱은 옆 월차 카드에 높이를 맞추느라 아래가 비어서,
          // 그 자리를 한 줄 더 채운다 (폰은 카드가 세로로 쌓여 필요 없다)
          if (isDesktop) ...[
            SizedBox(height: 16),
            Spacer(),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 16),
            Row(
              children: [
                _stat('평균 근무', _duration(average), AppColors.textPrimary),
                _divider(),
                _stat(
                  '조기 퇴근',
                  '$early회',
                  early > 0 ? AppColors.warning : AppColors.textPrimary,
                ),
                _divider(),
                _stat(
                  '월차',
                  '$leave일',
                  leave > 0 ? AppColors.primary : AppColors.textPrimary,
                ),
                _divider(),
                _stat('휴무', '$off일', AppColors.textPrimary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

/// 대표 화면이 쓰는 상태 차례와 색 — 달력 칸·날짜 상세가 같이 쓴다
///
/// 출근·퇴근 먼저, 챙길 것 나중. 마지막 값은 '평범한 하루인가' —
/// 이것만 있는 날은 달력 칸에서 `전원 출근` 한 줄로 줄인다.
const _workStatusOrder = <(AttendanceStatus, String, Color, bool)>[
  (AttendanceStatus.inProgress, '출근', AppColors.workIn, true),
  (AttendanceStatus.normal, '퇴근', AppColors.workOut, true),
  (AttendanceStatus.overtime, '야근', AppColors.workOvertime, false),
  (AttendanceStatus.earlyLeave, '조기퇴근', AppColors.workEarly, false),
  (AttendanceStatus.lateAndEarly, '지각·조퇴', AppColors.workLateEarly, false),
  (AttendanceStatus.late, '지각', AppColors.workLate, false),
  // 퇴근 스캔이 없는 날도 여기로 온다 — 서버가 새벽 5시를 넘기면 미출근으로
  // 넘겨준다 (예전에는 `퇴근누락` 알약이 따로 섰다)
  (AttendanceStatus.notIn, '미출근', AppColors.workNone, false),
  (AttendanceStatus.absent, '결근', AppColors.workAbsent, false),
  (AttendanceStatus.onLeave, '월차', AppColors.workLeave, false),
];

/// 대표가 보는 오늘 근무 — 숫자 대신 **누가** 그런지를 띄운다
///
/// 대표는 자기 출퇴근이 없어서 달 요약이 빈 껍데기다. 칸 모양은 달 요약과
/// 그대로 두고 값만 이름으로 바꾼다. 판정은 서버가 명단에 얹어 주는
/// `Employee.todayStatus` 를 쓴다 (근태 달력·홈과 같은 기준).
///
/// **자정이 지나면 저절로 전원 미출근으로 돌아간다** — 날짜가 바뀌면 그날
/// 기록이 아직 없고, 결근 판정도 '퇴근 시간이 지났나'를 보므로 새벽에는 안 걸린다.
class _TodayBoard extends StatelessWidget {
  _TodayBoard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 지각·조기퇴근을 같이 한 사람은 두 칸에 다 선다 (판정 값은 하나뿐이라)
    final both = _todayWith(AttendanceStatus.lateAndEarly);
    // 색은 달력 칸과 같은 토큰을 쓴다 — 두 자리에서 같은 상태가 다른 색이면 안 된다
    //
    // 마지막 값은 **스캔이 없을 때 근무 시간을 대신 보여줄지**다.
    // 월차는 원래 안 나오는 날이라 '근무 09:00~18:00' 이 뜨면 안 온 것처럼 읽힌다.
    final cells = <(String, Color, List<Employee>, bool)>[
      ('출근', AppColors.workIn, _todayWith(AttendanceStatus.inProgress), true),
      ('퇴근', AppColors.workOut, _todayWith(AttendanceStatus.normal), true),
      (
        '야근',
        AppColors.workOvertime,
        _todayWith(AttendanceStatus.overtime),
        true,
      ),
      (
        '조기퇴근',
        AppColors.workEarly,
        [..._todayWith(AttendanceStatus.earlyLeave), ...both],
        true,
      ),
      (
        '지각',
        AppColors.workLate,
        [..._todayWith(AttendanceStatus.late), ...both],
        true,
      ),
      ('결근', AppColors.workAbsent, _todayWith(AttendanceStatus.absent), true),
      ('월차', AppColors.workLeave, _todayWith(AttendanceStatus.onLeave), false),
      ('미출근', AppColors.workNone, _todayWith(null), true),
    ];
    // 폰은 칸이 좁아 두 개씩 네 줄, 데스크톱은 네 개씩 두 줄
    final perRow = isDesktop ? 4 : 2;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('오늘 근무', style: AppTextStyles.label)),
              Text(
                '${now.month}월 ${now.day}일 (${_weekday(now)})',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          for (var start = 0; start < cells.length; start += perRow) ...[
            if (start > 0) ...[
              SizedBox(height: 16),
              Container(height: 1, color: AppColors.gray100),
              SizedBox(height: 16),
            ],
            Row(
              children: [
                for (var i = start; i < start + perRow; i++) ...[
                  if (i > start) _divider(),
                  _cell(context, cells[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 달 요약의 `_stat` 과 같은 칸 — 숫자 자리에 이름이 들어간다
  ///
  /// **누르면 그 칸 사람들이 시각과 함께 펼쳐진다** (2026-08-20 대표 요청).
  /// 칸에는 `하이여 외 2명` 까지만 들어가서 나머지가 누구인지 알 길이 없었다.
  /// 아무도 없는 칸은 열어 봐야 빈 목록이라 안 눌린다.
  Widget _cell(
    BuildContext context,
    (String, Color, List<Employee>, bool) cell,
  ) {
    final (label, color, people, showShift) = cell;
    final body = Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _names(people),
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(
              fontSize: 17,
              // 아무도 없는 칸은 색까지 빼서 눈이 안 가게 한다
              color: people.isEmpty ? AppColors.gray300 : color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );

    if (people.isEmpty) return Expanded(child: body);
    return Expanded(
      child: Pressable(
        scale: 0.96,
        onTap: () => showAppDialog<void>(
          context,
          (_) => _TodayCellCard(
            label: label,
            color: color,
            people: people,
            showShift: showShift,
          ),
        ),
        child: body,
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);

  /// 없으면 `-`, 한 명이면 이름, 여럿이면 `김트레이너 외 2명`
  String _names(List<Employee> people) {
    if (people.isEmpty) return '-';
    if (people.length == 1) return people.first.name;
    return '${people.first.name} 외 ${people.length - 1}명';
  }
}

/// '오늘 근무' 칸을 눌렀을 때 — 그 상태인 사람과 **찍힌 시각**
///
/// 카드에는 `하이여 외 2명` 까지만 들어가서 나머지가 누구인지, 몇 시에
/// 왔는지를 알 길이 없었다. 여기가 그걸 편다.
///
/// 시각은 [_todayRecords] 에서 온다 — 명단(`Employee.todayStatus`)은 판정
/// 한 글자뿐이라 시각을 모른다.
class _TodayCellCard extends StatelessWidget {
  _TodayCellCard({
    required this.label,
    required this.color,
    required this.people,
    required this.showShift,
  });

  final String label;
  final Color color;
  final List<Employee> people;

  /// 스캔이 없을 때 **설정된 근무 시간**을 대신 보여줄지.
  /// 월차는 원래 안 나오는 날이라 끈다 — 안 그러면 안 온 것처럼 읽힌다.
  final bool showShift;

  /// 그 사람의 오늘 한 줄 — 상황에 따라 나오는 값이 다르다
  ///
  /// | 언제 | 무엇 |
  /// |---|---|
  /// | 출근·퇴근 다 찍음 | `09:00 ~ 18:10` |
  /// | 출근만 찍음 | `09:02 출근` |
  /// | 스캔 없음 | `근무 09:00~18:00` (설정된 시간) |
  /// | 근무 시간도 없음 | `-` |
  String _line(Employee person) {
    final record = _todayRecords[person.id];
    final inAt = record?.checkIn;
    final outAt = record?.checkOut;
    if (inAt != null && outAt != null) {
      return '${_clock(inAt)} ~ ${_clock(outAt)}';
    }
    if (inAt != null) return '${_clock(inAt)} 출근';
    final start = person.shiftStart;
    final end = person.shiftEnd;
    if (showShift && start != null && end != null) return '근무 $start~$end';
    return '-';
  }

  /// 아래에 붙는 근무 시간 — 퇴근을 찍은 사람만 나온다
  String? _worked(Employee person) {
    final minutes = _todayRecords[person.id]?.workMinutes;
    if (minutes == null || minutes <= 0) return null;
    return _duration(Duration(minutes: minutes));
  }

  @override
  Widget build(BuildContext context) => Container(
    width: dialogWidth(context, 320),
    padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Text(
              '${people.length}명',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ),
        SizedBox(height: 14),
        // 사람이 많아도 창이 화면을 넘지 않게 — 넘으면 안에서 스크롤된다
        ScrollBox(
          maxHeight: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < people.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.divider),
                _TodayPersonRow(
                  person: people[i],
                  line: _line(people[i]),
                  worked: _worked(people[i]),
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// 상세의 한 줄 — 아바타 · 이름/직군 · 오른쪽에 시각
class _TodayPersonRow extends StatelessWidget {
  _TodayPersonRow({
    required this.person,
    required this.line,
    required this.worked,
    required this.color,
  });

  final Employee person;
  final String line;
  final String? worked;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Avatar(name: person.name, size: 34),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                person.rank.label,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              line,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (worked case final total?) ...[
              SizedBox(height: 2),
              Text(total, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ],
        ),
      ],
    ),
  );
}
