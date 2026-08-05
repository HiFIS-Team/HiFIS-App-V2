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
  (AttendanceStatus.noCheckout, '퇴근누락', AppColors.workNoCheckout, false),
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
    final cells = <(String, Color, List<Employee>)>[
      ('출근', AppColors.workIn, _todayWith(AttendanceStatus.inProgress)),
      ('퇴근', AppColors.workOut, _todayWith(AttendanceStatus.normal)),
      ('야근', AppColors.workOvertime, _todayWith(AttendanceStatus.overtime)),
      (
        '조기퇴근',
        AppColors.workEarly,
        [..._todayWith(AttendanceStatus.earlyLeave), ...both],
      ),
      (
        '지각',
        AppColors.workLate,
        [..._todayWith(AttendanceStatus.late), ...both],
      ),
      ('결근', AppColors.workAbsent, _todayWith(AttendanceStatus.absent)),
      ('월차', AppColors.workLeave, _todayWith(AttendanceStatus.onLeave)),
      ('미출근', AppColors.workNone, _todayWith(null)),
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
                  _cell(cells[i].$1, cells[i].$2, cells[i].$3),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 달 요약의 `_stat` 과 같은 칸 — 숫자 자리에 이름이 들어간다
  Widget _cell(String label, Color color, List<Employee> people) => Expanded(
    child: Column(
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
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);

  /// 없으면 `-`, 한 명이면 이름, 여럿이면 `김트레이너 외 2명`
  String _names(List<Employee> people) {
    if (people.isEmpty) return '-';
    if (people.length == 1) return people.first.name;
    return '${people.first.name} 외 ${people.length - 1}명';
  }
}
