part of 'home_screen.dart';

/// 오늘 근무 카드 — 실시간 시계 + 서버가 판정한 오늘 근태
class _HeroStatusCard extends StatefulWidget {
  _HeroStatusCard({required this.attendance});

  /// 아직 안 왔으면 null — 시계는 돌고 스캔 기록은 `--:--` 로 그린다
  final HomeAttendance? attendance;

  @override
  State<_HeroStatusCard> createState() => _HeroStatusCardState();
}

class _HeroStatusCardState extends State<_HeroStatusCard> {
  late final Timer _timer;

  /// 홈 탭이 지금 보이는가 ([LazyIndexedStack] 이 알려준다)
  ///
  /// **안 보이면 시계를 멈춘다.** IndexedStack 이 탭을 살려 두기 때문에,
  /// 이 가드가 없으면 홈을 한 번 연 뒤로 다른 탭에 있어도 앱을 끌 때까지
  /// 매초 이 카드가 다시 그려진다. 다시 보이면 그 순간 리빌드가 걸려
  /// 시각이 바로 맞춰지므로 화면에는 차이가 없다.
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // 실시간 시계 갱신
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_visible) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// 근무 시간 대비 진행률 (0.0~1.0)
  ///
  /// 출근을 안 찍었으면 0, 퇴근을 찍었으면 그 시각까지, 아니면 지금까지로 잰다.
  /// 근무 시간이 설정 안 된 사람은 기준이 없어 0 에 머문다.
  double get _rate {
    final start = _minutesOf(currentUser?.shiftStart);
    final end = _minutesOf(currentUser?.shiftEnd);
    if (start == null || end == null || end <= start) return 0;

    final attendance = widget.attendance;
    if (attendance?.checkIn == null) return 0;

    final at = attendance!.checkOut ?? DateTime.now();
    final elapsed = at.hour * 60 + at.minute - start;
    return (elapsed / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // 탭이 바뀌면 이 값이 뒤집히면서 리빌드가 걸린다 (InheritedWidget)
    _visible = TickerMode.valuesOf(context).enabled;

    final now = DateTime.now();
    final timeText =
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';

    final attendance = widget.attendance;
    final badge = _statusBadge(attendance);
    final rate = _rate;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('오늘 근무', style: AppTextStyles.label)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.all(Radius.circular(100)),
                ),
                child: Text(
                  badge.label,
                  style: AppTextStyles.caption.copyWith(
                    color: badge.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            timeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 20),
          _WorkGauge(rate: rate),
          SizedBox(height: 10),
          // 근무 시작 시간 — 진행률 — 종료 시간
          Row(
            children: [
              Text(
                currentUser?.shiftStart ?? '--:--',
                style: AppTextStyles.caption,
              ),
              Spacer(),
              Text(
                '${(rate * 100).round()}%',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                currentUser?.shiftEnd ?? '--:--',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          SizedBox(height: 18),
          // 실제 출퇴근 스캔 기록
          Row(
            children: [
              _ScanRecord(label: '출근', time: _hhmm(attendance?.checkIn)),
              Spacer(),
              _ScanRecord(label: '퇴근', time: _hhmm(attendance?.checkOut)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 오늘 근태를 배지 한 줄로 옮긴다 — 아직 안 왔으면 배지를 안 그린다
///
/// 서버가 열 가지를 판정해 주는데 홈은 지금 어떤 상태인지만 보면 되므로
/// 라벨을 짧게 줄인다. 어느 날 무슨 일이 있었는지는 근태 화면에서 본다.
({String label, Color color}) _statusBadge(HomeAttendance? attendance) {
  final status = attendance?.status;
  // 기록이 없거나 아직 응답이 안 온 상태.
  // 근무 시간이 다 지나도록 안 찍히면 그때 서버가 결근으로 바꿔 준다.
  if (status == null) return (label: '미출근', color: AppColors.gray500);
  return switch (status) {
    AttendanceStatus.inProgress => (label: '출근', color: AppColors.success),
    // 야근도 '퇴근'으로 둔다 — 이 배지는 지금 상태를 알리는 자리라 문구를 늘리지 않는다
    AttendanceStatus.normal ||
    AttendanceStatus.overtime => (label: '퇴근', color: AppColors.gray500),
    AttendanceStatus.late => (label: '지각', color: AppColors.warning),
    AttendanceStatus.earlyLeave => (label: '조기 퇴근', color: AppColors.warning),
    AttendanceStatus.lateAndEarly => (
      label: '지각·조기 퇴근',
      color: AppColors.warning,
    ),
    AttendanceStatus.noCheckout => (label: '퇴근 누락', color: AppColors.error),
    AttendanceStatus.absent => (label: '결근', color: AppColors.error),
    AttendanceStatus.onLeave => (
      // 반차면 오전·오후까지, 아니면 연차·병가 같은 종류를 그대로 쓴다
      label:
          attendance?.halfPeriod?.label ?? attendance?.leaveType?.label ?? '휴가',
      color: AppColors.primary,
    ),
    AttendanceStatus.dayOff => (label: '휴무', color: AppColors.gray500),
    AttendanceStatus.unknown => (label: '판정 불가', color: AppColors.gray500),
  };
}

/// `09:00` → 분. 형식이 다르거나 비어 있으면 null
int? _minutesOf(String? hhmm) {
  final parts = hhmm?.split(':');
  if (parts == null || parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

/// 스캔 시각 — 안 찍혔으면 `--:--`
String _hhmm(DateTime? at) =>
    at == null ? '--:--' : '${_pad(at.hour)}:${_pad(at.minute)}';

String _pad(int value) => value.toString().padLeft(2, '0');

class _ScanRecord extends StatelessWidget {
  _ScanRecord({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final recorded = time != '--:--';
    return Row(
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(width: 8),
        Text(
          time,
          style: AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.w600,
            color: recorded ? AppColors.textPrimary : AppColors.gray300,
          ),
        ),
      ],
    );
  }
}

class _WorkGauge extends StatelessWidget {
  _WorkGauge({required this.rate});

  /// 0.0(출근 전) ~ 1.0(퇴근)
  final double rate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbX = (constraints.maxWidth - 14) * rate;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // 트랙
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              // 채워진 게이지
              FractionallySizedBox(
                widthFactor: rate,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              // 현재 위치 썸
              Positioned(
                left: thumbX,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33101828),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
