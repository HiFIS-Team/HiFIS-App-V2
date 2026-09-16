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

class _AttendanceEditSheetState extends State<_AttendanceEditSheet> {
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

  /// 그날 기록을 받아오는 중 — 받아야 무엇을 고치는지 보인다
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
    setState(() => _loading = true);
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
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _wire(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

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

  Future<void> _pickPerson() async {
    final picked = await showAppDialog<Employee>(
      context,
      (context) => _PersonPicker(people: _people, selected: _who),
    );
    if (picked == null || !mounted) return;
    setState(() => _who = picked);
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      // **앞날은 못 고른다** — 아직 오지 않은 날의 출퇴근을 적을 일이 없다
      lastDate: DateTime.now(),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (start ? _in : _out) ?? TimeOfDay(hour: start ? 9 : 18, minute: 0),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
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

  @override
  Widget build(BuildContext context) {
    final who = _who;
    return PhoneDetailScaffold(
      title: '근태 고치기',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          40,
        ),
        children: [
          _EditRow(
            label: '직원',
            value: who?.name ?? '고르기',
            dim: who == null,
            onTap: _pickPerson,
          ),
          SizedBox(height: 10),
          _EditRow(
            label: '날짜',
            value: '${_date.year}.${_date.month}.${_date.day}',
            onTap: _pickDate,
          ),
          SizedBox(height: 18),
          if (who == null)
            _EditHint('먼저 직원을 골라 주세요')
          else if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.gray200,
                  ),
                ),
              ),
            )
          else ...[
            _EditRow(
              label: '출근',
              value: _in == null ? '없음' : _wire(_in!),
              dim: _in == null,
              onTap: () => _pickTime(start: true),
              onClear: _in == null ? null : () => setState(() => _in = null),
            ),
            SizedBox(height: 10),
            _EditRow(
              label: '퇴근',
              value: _out == null ? '없음' : _wire(_out!),
              dim: _out == null,
              onTap: () => _pickTime(start: false),
              onClear: _out == null ? null : () => setState(() => _out = null),
            ),
            SizedBox(height: 14),
            // **점수가 같이 움직인다는 것을 적는다.** 안 적으면 시각만 바뀌는
            // 줄 알고, 나중에 점수가 달라진 것을 보고 놀란다
            _EditHint('고치면 지각 차감·조기 출근·초과 근무 점수가 그 날짜만 다시 매겨져요.'),
            SizedBox(height: 20),
            AppButton(label: '저장', filled: true, busy: _saving, onTap: _save),
          ],
        ],
      ),
    );
  }
}

/// 라벨 + 값 한 줄 — 누르면 고르개가 뜬다
class _EditRow extends StatelessWidget {
  _EditRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.dim = false,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// 값이 비어 '고르기'·'없음' 일 때 — 흐리게 그린다
  final bool dim;

  /// 값을 지우는 길 — **퇴근을 잘못 찍은 날을 되돌리는 자리다**
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.label),
            Spacer(),
            Text(
              value,
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: dim ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
            if (onClear case final clear?) ...[
              SizedBox(width: 6),
              Pressable(
                onTap: clear,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ] else
              SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _EditHint extends StatelessWidget {
  _EditHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
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
