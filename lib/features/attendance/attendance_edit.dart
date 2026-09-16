part of 'attendance_screen.dart';

/// 출퇴근을 손으로 고치는 화면 — **대표·관리자만** (2026-09-16 대표 요청)
///
/// 바코드를 못 찍었거나 시각이 틀린 날이 매주 나오는데 앞에서 고칠 길이 없어서,
/// 그동안 사람이 서버 DB 를 직접 만졌다. 그러면 **자동 점수가 조용히 빠진다** —
/// 9월에 실제로 60점(오현종 50 · 민중기 10)이 그렇게 비어 있었다.
///
/// **서버가 점수를 다시 맞춘다** (`PUT /attendance`). 정시로 고치면 지각 차감이
/// 사라지고, 늦게 고치면 초과근무가 붙는다 — 앱이 따로 셀 것이 없다.
class _AttendanceEditSheet extends StatefulWidget {
  _AttendanceEditSheet({this.date});

  /// 달력에서 날짜를 눌러 들어왔으면 그날로 시작한다
  final DateTime? date;

  @override
  State<_AttendanceEditSheet> createState() => _AttendanceEditSheetState();
}

class _AttendanceEditSheetState extends State<_AttendanceEditSheet>
    with SkeletonDelay<_AttendanceEditSheet> {
  /// 고를 수 있는 사람 — **대표·관리자는 뺀다.** 근태를 안 남기는 쪽이라
  /// (`Role.boss`) 목록에 두면 고칠 수 없는 사람이 절반이다
  late final List<Employee> _people = [
    for (final e in StaffDirectory.instance.employees)
      if (!e.role.boss && e.status == EmployeeStatus.active) e,
  ]..sort((a, b) => a.name.compareTo(b.name));

  Employee? _who;
  late DateTime _date = widget.date ?? DateTime.now();
  TimeOfDay? _in;
  TimeOfDay? _out;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 들어오면 아직 고른 사람이 없어 받을 것이 없다 — 뼈대 없이 시작한다
    skipFirstSkeleton();
    if (_people.length == 1) {
      _who = _people.first;
      _load();
    }
  }

  /// 고른 사람·날짜의 기록을 받아 칸을 채운다
  ///
  /// **기록이 없으면 빈 칸이다** — 그게 곧 결근으로 찍힌 날이고, 여기서
  /// 만들어 주면 된다.
  Future<void> _load() async {
    final who = _who;
    if (who == null) return;
    setState(beginLoad);
    try {
      final rows = await AttendanceApi.list(
        employeeId: who.id,
        month: '${_date.year}-${_two(_date.month)}',
      );
      final hit = rows.where((r) => _sameDay(r.date, _date)).firstOrNull;
      if (!mounted) return;
      setState(() {
        _in = hit?.checkIn == null
            ? null
            : TimeOfDay.fromDateTime(hit!.checkIn!);
        _out = hit?.checkOut == null
            ? null
            : TimeOfDay.fromDateTime(hit!.checkOut!);
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _wire(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  Future<void> _pickPerson() async {
    final picked = await showAppDialog<Employee>(
      context,
      (context) => _PersonPicker(people: _people, selected: _who),
    );
    if (picked == null || !mounted || picked.id == _who?.id) return;
    setState(() => _who = picked);
    await _load();
  }

  Future<void> _pickDate() async {
    // 아이폰은 아래에서 올라오는 시트다 ([native_picker.dart])
    final picked = await pickDate(
      context,
      initial: _date,
      first: DateTime(_date.year - 2),
      // **앞날은 못 고른다** — 아직 오지 않은 날의 출퇴근을 적을 일이 없다
      last: DateTime.now(),
      title: '근무일',
    );
    // **같은 날이면 아무것도 안 한다.** 아이폰 시트는 닫는 것이 곧 고르는
    // 것이라, 안 고르고 내려도 값이 돌아온다 — 그대로 다시 받으면 뼈대가
    // 깔렸다 지워져 **아래가 통째로 깜빡인다** (2026-09-16 대표 보고)
    if (picked == null || !mounted || _sameDay(picked, _date)) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await pickTime(
      context,
      // 안 찍힌 칸은 **본인 근무시간**에서 시작한다 — 09:00·18:00 을 박아 두면
      // 야간 근무인 사람이 매번 한참을 굴려야 한다
      initial:
          (start ? _in : _out) ??
          _shiftTime(start) ??
          TimeOfDay(hour: start ? 9 : 18, minute: 0),
      title: start ? '출근' : '퇴근',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _in = picked;
      } else {
        _out = picked;
      }
    });
  }

  Future<void> _save() async {
    final who = _who;
    if (who == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AttendanceApi.edit(
        employeeId: who.id,
        date: _date,
        checkIn: _in == null ? null : _wire(_in!),
        checkOut: _out == null ? null : _wire(_out!),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.show(context, '${who.name}님 근태를 고쳤어요');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 설정 근무시간의 시·분 — 안 찍힌 칸의 고르개가 여기서 시작한다
  TimeOfDay? _shiftTime(bool start) {
    final raw = start ? _who?.shiftStart : _who?.shiftEnd;
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// 그 사람이 설정한 근무시간 — **무엇이 정상인지 알고 고쳐야 한다**
  String? get _shiftLabel {
    final who = _who;
    if (who?.shiftStart == null || who?.shiftEnd == null) return null;
    return '${who!.shiftStart} ~ ${who.shiftEnd}';
  }

  @override
  Widget build(BuildContext context) {
    final who = _who;
    final ready = who != null && !showSkeleton;
    return PhoneDetailScaffold(
      title: '근태 수정',
      // 일정 폼과 같은 틀 — 흰 배경에 카드 없이 앉히고 주 동작은 하단 글래스
      background: AppColors.surface,
      bottomBar: ready
          ? GlassBottomButton(label: '저장', onPressed: _save)
          : null,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          ready ? GlassBottomButton.inset(context) : 40,
        ),
        children: [
          Text('누구의', style: AppTextStyles.label),
          SizedBox(height: 8),
          _PersonRow(person: who, onTap: _pickPerson),
          SizedBox(height: 24),

          Text('어느 날', style: AppTextStyles.label),
          SizedBox(height: 8),
          _PickRow(
            icon: Icons.calendar_today_rounded,
            value: _dateLabel,
            onTap: _pickDate,
          ),
          SizedBox(height: 24),

          if (who == null)
            _Hint('먼저 직원을 골라 주세요.')
          else ...[
            Row(
              children: [
                Text('출퇴근 시각', style: AppTextStyles.label),
                if (_shiftLabel case final shift?) ...[
                  Spacer(),
                  // 설정값을 옆에 둔다 — 이게 없으면 몇 시가 정상인지 모른 채 고친다
                  Text(
                    '설정 $shift',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),
            if (showSkeleton)
              _TimeSkeleton()
            else ...[
              _PickRow(
                icon: Icons.login_rounded,
                label: '출근',
                value: _in == null ? '안 찍힘' : _wire(_in!),
                dim: _in == null,
                onTap: () => _pickTime(start: true),
                onClear: _in == null ? null : () => setState(() => _in = null),
              ),
              SizedBox(height: 8),
              _PickRow(
                icon: Icons.logout_rounded,
                label: '퇴근',
                value: _out == null ? '안 찍힘' : _wire(_out!),
                dim: _out == null,
                onTap: () => _pickTime(start: false),
                onClear: _out == null
                    ? null
                    : () => setState(() => _out = null),
              ),
              SizedBox(height: 14),
              // **점수가 같이 움직인다는 것을 적는다.** 안 적으면 시각만 바뀌는
              // 줄 알고, 나중에 점수가 달라진 것을 보고 놀란다
              _Hint(
                '고치면 지각 차감·조기 출근·초과 근무 점수가 그 날짜만 다시 매겨져요.\n'
                '시각을 비우면 그 기록이 지워져요.',
              ),
            ],
          ],
        ],
      ),
    );
  }

  String get _dateLabel {
    const week = ['월', '화', '수', '목', '금', '토', '일'];
    return '${_date.year}년 ${_date.month}월 ${_date.day}일 '
        '(${week[_date.weekday - 1]})';
  }
}

/// 고른 직원 — 아바타와 이름, 없으면 고르라고 말한다
class _PersonRow extends StatelessWidget {
  _PersonRow({required this.person, required this.onTap});

  final Employee? person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final who = person;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: EdgeInsets.fromLTRB(14, 0, 14, 0),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (who == null)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              )
            else
              Avatar(name: who.name, size: 34),
            SizedBox(width: 12),
            Expanded(
              child: who == null
                  ? Text(
                      '직원 고르기',
                      style: AppTextStyles.body1.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          who.name,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          who.rank.label,
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 누르면 고르개가 뜨는 줄 — 날짜·시각이 같은 모양을 쓴다
class _PickRow extends StatelessWidget {
  _PickRow({
    required this.icon,
    required this.value,
    required this.onTap,
    this.label,
    this.dim = false,
    this.onClear,
  });

  final IconData icon;

  /// 왼쪽에 붙는 이름 (`출근`·`퇴근`) — 날짜 줄은 안 쓴다
  final String? label;
  final String value;
  final VoidCallback onTap;

  /// 값이 비었을 때 — 흐리게 그린다
  final bool dim;

  /// 값을 지우는 길 — **잘못 찍은 퇴근을 되돌리는 자리다**
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.fromLTRB(16, 0, 10, 0),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textTertiary),
            SizedBox(width: 10),
            if (label case final name?) ...[
              Text(name, style: AppTextStyles.label),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                value,
                textAlign: label == null ? TextAlign.left : TextAlign.right,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dim ? AppColors.textTertiary : AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (onClear case final clear?)
              Pressable(
                onTap: clear,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// 받아오는 동안 — **줄 높이를 그대로 잡는다** (오면 화면이 안 밀린다)
class _TimeSkeleton extends StatelessWidget {
  _TimeSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      children: [
        Skeleton(height: 56, radius: 14),
        SizedBox(height: 8),
        Skeleton(height: 56, radius: 14),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 2),
    child: Text(text, style: AppTextStyles.caption.copyWith(height: 1.6)),
  );
}

/// 직원 고르개 — 목록이 길어서 검색 없이 훑는다 (스무 명 남짓)
class _PersonPicker extends StatelessWidget {
  _PersonPicker({required this.people, required this.selected});

  final List<Employee> people;
  final Employee? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 320),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Text('직원 고르기', style: AppTextStyles.title3),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                for (final person in people)
                  Pressable(
                    onTap: () => Navigator.pop(context, person),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Avatar(name: person.name, size: 30),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              person.name,
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (person.id == selected?.id)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
