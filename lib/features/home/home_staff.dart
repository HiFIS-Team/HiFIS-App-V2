part of 'home_screen.dart';

/// 오늘 출근 — 대표·관리자 홈 오른쪽 카드
///
/// **요청을 안 보낸다.** 명단(`StaffDirectory`)에 서버가 판정한 오늘 상태
/// (`Employee.todayStatus`)가 같이 실려 오므로 그걸 그대로 센다.
class _TodayStaffCard extends StatelessWidget {
  _TodayStaffCard({required this.fill, this.onOpenAll});

  final bool fill;
  final VoidCallback? onOpenAll;

  /// 카드에 세우는 줄 수 — 폰은 네 장을 같게 맞춘다
  int get _max => isDesktop ? 4 : phoneCardRows;

  /// 재직자만 — 퇴사·비활성은 오늘 나올 사람이 아니다
  List<Employee> get _staff => [
    for (final employee in StaffDirectory.instance.employees)
      if (employee.status == EmployeeStatus.active) employee,
  ];

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    // 나와 있는 사람 → 휴가 → 나머지. 카드에 몇 줄만 서므로 순서가 곧 중요도다
    int rank(Employee e) => switch (e.todayStatus) {
      final s? when s.working => 0,
      AttendanceStatus.onLeave => 1,
      _ => 2,
    };
    final sorted = [...staff]
      ..sort((a, b) {
        final gap = rank(a).compareTo(rank(b));
        return gap != 0 ? gap : a.name.compareTo(b.name);
      });
    final working = staff.where((e) => e.todayStatus?.working ?? false).length;

    final rows = [for (final e in sorted.take(_max)) _StaffRow(employee: e)];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '오늘 출근',
            count: working,
            total: staff.length,
            onOpenAll: onOpenAll,
          ),
          SizedBox(height: 14),
          if (rows.isEmpty)
            // 여기가 비는 건 명단을 못 받은 것이라 빈 목록과 다르다 —
            // 아이콘 카드 대신 사정을 적어 준다
            _EmptyRoster()
          else if (fill)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          // 폰은 내용이 적어도 카드가 안 줄어들게 세 줄 높이를 잡아 둔다
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: isDesktop ? 0 : phoneCardBody,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) SizedBox(height: 14),
                    rows[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  _StaffRow({required this.employee});

  final Employee employee;

  /// 서버 판정을 화면 말로 — **null 은 아직 출근 전이다** (결근이 아니다)
  (String, Color) get _badge => switch (employee.todayStatus) {
    final s? when s.working => ('근무중', AppColors.success),
    AttendanceStatus.onLeave => ('휴가', AppColors.primary),
    AttendanceStatus.dayOff => ('휴무', AppColors.gray400),
    AttendanceStatus.absent => ('결근', AppColors.error),
    null => ('출근 전', AppColors.gray400),
    _ => ('퇴근', AppColors.gray400),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _badge;
    return Row(
      children: [
        Avatar(name: employee.name, size: 34),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1),
              Text(
                employee.rank.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// 명단을 못 받았을 때 — **빈 목록이 아니라 사정이 있는 것**이라 문구로 알린다
class _EmptyRoster extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: isDesktop ? 0 : phoneCardBody),
    child: Center(
      child: Text(
        '명단을 아직 못 받았어요',
        style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
      ),
    ),
  );
}
