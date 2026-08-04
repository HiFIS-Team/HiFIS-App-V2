import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/approval_api.dart';
import '../../core/api/attendance_api.dart';
import '../../core/api/event_api.dart';
import '../../core/api/home_api.dart';
import '../../core/api/payroll_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/mini_button.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reject_reason_dialog.dart';
import '../../core/widgets/see_all_button.dart';
import '../notice/notice_screen.dart';
import '../notifications/notification_screen.dart';
import '../project/project_screen.dart';

/// 홈 화면 — 모든 직원이 처음 보는 화면
///
/// 오늘 근무는 `/me/home` 에서 온다. 지점 집계인 `/dashboard` 와 달리
/// 권한 없이 본인 것만 주는 요약이라 직급에 상관없이 열린다.
///
/// 프로젝트·공지 카드는 각 탭 화면과 **같은 목록**을 읽는다. 그 목록은 탭을
/// 열어야 채워지므로, 홈에서도 요약과 나란히 받아 둔다
/// (`loadNoticesIfNeeded`·`loadProjectsIfNeeded`). 안 그러면 홈부터 본 사람은
/// 카드가 비어 보인다.
/// 요약의 `monthScore` 는 지금 놓을 자리가 없어 안 쓴다 — 화면을 늘리지 않는다.
class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    this.onOpenProjects,
    this.onOpenNotices,
    this.onOpen,
    this.onOpenStaff,
  });

  /// 카드의 '전체'를 눌렀을 때 해당 탭으로 옮겨달라고 셸에 알린다
  final VoidCallback? onOpenProjects;
  final VoidCallback? onOpenNotices;

  /// 결재 대기 카드가 쓰는 통로 — 갈 곳이 셋이라 하나로 받는다
  final void Function(NotificationTarget)? onOpen;

  /// 조직도로 — **데스크톱에만 있는 화면이라** 폰에서는 안 넘어온다
  final VoidCallback? onOpenStaff;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// 오늘 요약 — 도착 전에는 null 이라 근무 카드가 '미출근'으로 그려진다
  ///
  /// 첫 화면이라 통째로 로딩을 돌리면 앱을 열 때마다 빈 화면을 보게 된다.
  /// 인사말·시계는 기기에서 바로 나오므로 그대로 두고 값만 채운다.
  HomeSummary? _summary;

  /// 마지막으로 받아온 시각 — 창을 옮길 때마다 다시 부르지 않게 막는다
  DateTime? _loadedAt;

  /// 다시 받기까지 두는 최소 간격
  ///
  /// macOS 는 **창이 포커스만 잃어도** inactive → resumed 가 오간다.
  /// 그대로 두면 다른 앱을 잠깐 볼 때마다 요청이 나간다 (실제로 몇 초 간격으로
  /// 나갔다). 오늘 근태는 그렇게 자주 바뀌지 않는다.
  static const _minReloadGap = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱을 다시 열면 다시 받는다 — 배경에 둔 사이 출퇴근이나 날짜가 바뀐다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < _minReloadGap) return;
    _load();
  }

  Future<void> _load() async {
    if (currentUser == null) return;
    // 실패해도 찍어 둔다 — 서버가 죽어 있을 때 포커스마다 재시도하지 않게
    _loadedAt = DateTime.now();
    try {
      // 공지·프로젝트 카드가 목록을 그대로 읽는다 — 요약과 같이 받아 둔다.
      // 알림은 카드에 안 쓰지만 헤더 종 배지가 여기서 받은 수를 본다
      final summary =
          (await Future.wait([
                HomeApi.summary(),
                loadNoticesIfNeeded(),
                loadProjectsIfNeeded(),
                loadNotificationsIfNeeded(),
              ])).first
              as HomeSummary;
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(context, messageOf(error));
    }
  }

  /// 상세를 보고 돌아오면 진행률·읽음 표시가 바뀌어 있을 수 있다
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 데스크톱은 화면이 넓어서 프로젝트·공지를 나란히 배치한다
    final desktop = isDesktop;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 64, 20, bottomBarInset(context)),
              children: [
                _GreetingCard(),
                SizedBox(height: 16),
                // 대표·관리자는 출근을 안 해서 근무 카드가 늘 비어 있다.
                // 그 자리에 결재 대기와 오늘 출근을 아래 프로젝트·공지와 같은
                // 두 칸으로 놓는다.
                if (myRole == Role.master || myRole == Role.admin) ...[
                  if (desktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _InboxCard(onOpen: widget.onOpen)),
                          SizedBox(width: 16),
                          Expanded(
                            child: _TodayStaffCard(
                              fill: true,
                              onOpenAll: widget.onOpenStaff,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _InboxCard(onOpen: widget.onOpen),
                    SizedBox(height: 16),
                    _TodayStaffCard(fill: false),
                  ],
                ] else
                  _HeroStatusCard(attendance: _summary?.attendance),
                SizedBox(height: 16),
                if (desktop)
                  // 두 카드의 높이를 큰 쪽에 맞춰 같게 만든다
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ProjectsCard(
                            count: 5,
                            fill: true,
                            onOpenAll: widget.onOpenProjects,
                            onChanged: _refresh,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _NoticeCard(
                            onOpenAll: widget.onOpenNotices,
                            onChanged: _refresh,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _ProjectsCard(
                    onOpenAll: widget.onOpenProjects,
                    onChanged: _refresh,
                  ),
                  SizedBox(height: 16),
                  _NoticeCard(
                    onOpenAll: widget.onOpenNotices,
                    onChanged: _refresh,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  _GreetingCard();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_todayLabel, style: AppTextStyles.caption),
          SizedBox(height: 4),
          Text('좋은 아침이에요 👋', style: AppTextStyles.title1),
          // 이름에만 브랜드 그라데이션 포인트
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppColors.primary, Color(0xFF7C5CFC)],
            ).createShader(bounds),
            child: Text('$me님', style: AppTextStyles.title1),
          ),
        ],
      ),
    );
  }
}

/// 결재 대기 — 대표·관리자 홈 왼쪽 카드 (근무 카드 자리)
///
/// 급여·월차·전자결재가 **한 목록으로** 선다. 셋을 따로 받아 합치면 홈에서만
/// 요청이 세 개 더 나가서 서버(`/me/inbox`)가 합쳐 준다.
///
/// **ADMIN 은 버튼이 없다.** 지켜보는 자리라 목록은 같이 보되 승인·반려는
/// MASTER 만 누른다 (급여·월차 결재 화면과 같은 기준 — 눌러도 403 날 버튼은 안 낸다).
class _InboxCard extends StatefulWidget {
  _InboxCard({this.onOpen});

  final void Function(NotificationTarget)? onOpen;

  @override
  State<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<_InboxCard> {
  List<InboxItem> _items = const [];
  bool _loading = true;

  /// 데스크톱은 나란히 선 프로젝트 카드와 줄 수를 맞춘다
  static const _max = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await HomeApi.inbox();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 버튼을 낼지 — 눌러도 403 날 버튼은 안 낸다
  ///
  /// **일정만 ADMIN 도 누른다.** 승인 없이 일정을 올릴 수 있는 사람이
  /// 남의 신청도 결재한다 (서버 `_DECIDERS`). 나머지는 MASTER 뿐이다.
  bool _canDecideOn(InboxItem item) => item.kind == InboxKind.event
      ? myRole == Role.master || myRole == Role.admin
      : myRole.canApprove;

  /// 종류마다 부르는 곳이 다르다 — id 는 그 테이블의 것이다
  Future<void> _approve(InboxItem item) => _run(item, () async {
    switch (item.kind) {
      case InboxKind.payslip:
        await PayrollApi.approve(item.id);
      case InboxKind.leave:
        await AttendanceApi.approveLeave(item.id);
      case InboxKind.approval:
        await ApprovalApi.approve(item.id);
      case InboxKind.event:
        await EventApi.approve(item.id);
    }
  }, '승인했어요');

  Future<void> _reject(InboxItem item) async {
    final reason = await askRejectReason(
      context,
      hint: switch (item.kind) {
        InboxKind.payslip => '예) 추가 근무 시간이 기록과 달라요',
        InboxKind.leave => '예) 그날은 인원이 모자라요',
        InboxKind.approval => '예) 금액 근거를 더 적어주세요',
        InboxKind.event => '예) 그날은 이미 다른 행사가 있어요',
      },
    );
    if (reason == null || !mounted) return;
    await _run(item, () async {
      switch (item.kind) {
        case InboxKind.payslip:
          await PayrollApi.reject(item.id, reason);
        case InboxKind.leave:
          await AttendanceApi.rejectLeave(item.id, reason);
        case InboxKind.approval:
          await ApprovalApi.reject(item.id, comment: reason);
        case InboxKind.event:
          await EventApi.reject(item.id, reason: reason);
      }
    }, '반려했어요');
  }

  /// 처리하고 목록을 다시 받는다 — 한 건만 빼면 다른 기기에서 바뀐 게 안 맞는다
  Future<void> _run(
    InboxItem item,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// '전체'는 종류가 섞여 있어 한 화면으로 못 보낸다 — 제일 많은 쪽으로 보낸다
  VoidCallback? get _openAll {
    if (_items.isEmpty || widget.onOpen == null) return null;
    final counts = <InboxKind, int>{};
    for (final item in _items) {
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final target = switch (top) {
      InboxKind.payslip => NotificationTarget.salary,
      InboxKind.leave => NotificationTarget.attendance,
      InboxKind.approval => NotificationTarget.approval,
      InboxKind.event => NotificationTarget.schedule,
    };
    // 전자결재·일정은 폰에 탭이 아예 없다
    if (!isDesktop &&
        (target == NotificationTarget.approval ||
            target == NotificationTarget.schedule)) {
      return null;
    }
    return () => widget.onOpen!.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _items.take(_max).toList();
    final rows = [
      for (final item in shown)
        _InboxRow(
          item: item,
          onApprove: _canDecideOn(item) ? () => _approve(item) : null,
          onReject: _canDecideOn(item) ? () => _reject(item) : null,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '결재 대기',
            count: _items.length,
            onOpenAll: _openAll,
          ),
          SizedBox(height: 14),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '결재할 게 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            // 줄 간격은 늘 14로 둔다. 남는 높이를 나눠 가지면(spaceBetween)
            // 승인·반려로 줄이 줄었을 때 두 줄이 카드 위아래로 갈라진다.
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  _InboxRow({required this.item, this.onApprove, this.onReject});

  final InboxItem item;

  /// null 이면 버튼을 안 그린다 (ADMIN)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String get _name =>
      StaffDirectory.instance.byId(item.employeeId)?.name ?? '알 수 없음';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(name: _name, size: 34),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),
              Text(
                item.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        if (onApprove != null && onReject != null) ...[
          SizedBox(width: 8),
          MiniButton(label: '승인', onTap: onApprove!, filled: true),
          SizedBox(width: 6),
          MiniButton(label: '반려', onTap: onReject!, filled: false),
        ],
      ],
    );
  }
}

/// 오늘 출근 — 대표·관리자 홈 오른쪽 카드
///
/// **요청을 안 보낸다.** 명단(`StaffDirectory`)에 서버가 판정한 오늘 상태
/// (`Employee.todayStatus`)가 같이 실려 오므로 그걸 그대로 센다.
class _TodayStaffCard extends StatelessWidget {
  _TodayStaffCard({required this.fill, this.onOpenAll});

  final bool fill;
  final VoidCallback? onOpenAll;

  static const _max = 4;

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
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '명단을 아직 못 받았어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else if (fill)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
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

  @override
  void initState() {
    super.initState();
    // 실시간 시계 갱신
    _timer = Timer.periodic(Duration(seconds: 1), (_) => setState(() {}));
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

class _CardHeader extends StatelessWidget {
  _CardHeader({
    required this.title,
    required this.count,
    this.total,
    this.onOpenAll,
  });

  final String title;
  final int count;

  /// 있으면 `12/23` 으로 — 출근 카드처럼 분모가 있어야 뜻이 생기는 자리
  final int? total;

  /// 눌리면 해당 탭으로 이동한다
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.title3),
        SizedBox(width: 6),
        Text(
          '$count',
          style: AppTextStyles.title3.copyWith(color: AppColors.gray400),
        ),
        Spacer(),
        if (onOpenAll != null) SeeAllButton(onTap: onOpenAll!),
      ],
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  _ProjectsCard({
    this.count = 3,
    this.fill = false,
    this.onOpenAll,
    required this.onChanged,
  });

  /// 표시할 프로젝트 수 (데스크톱은 5개까지)
  final int count;

  /// true면 카드 높이에 맞춰 행 간격을 고르게 벌린다 (데스크톱 나란히 배치용)
  final bool fill;

  final VoidCallback? onOpenAll;

  /// 상세를 보고 돌아왔을 때 홈을 갱신한다
  final VoidCallback onChanged;

  /// 폰은 상세를 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, ProjectBrief brief) async {
    if (isDesktop) {
      requestedProject.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 진행 중인 프로젝트를 마감 임박순으로
    final briefs = projectBriefs(count);

    final rows = [
      for (final brief in briefs)
        _ProjectRow(brief: brief, onTap: () => _open(context, brief)),
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '프로젝트', count: rows.length, onOpenAll: onOpenAll),
          SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '진행 중인 프로젝트가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else if (fill)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  _ProjectRow({required this.brief, required this.onTap});

  final ProjectBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Row(
        children: [
          // 일정 카드 스타일의 세로 색 막대
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: brief.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(brief.members, style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brief.ddayColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              brief.dday,
              style: AppTextStyles.caption.copyWith(
                color: brief.ddayColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  _NoticeCard({this.onOpenAll, required this.onChanged});

  final VoidCallback? onOpenAll;

  /// 본문을 보고 돌아왔을 때 홈을 갱신한다 (읽음 표시)
  final VoidCallback onChanged;

  /// 폰은 본문을 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, NoticeBrief brief) async {
    if (isDesktop) {
      requestedNotice.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 고정 공지가 위, 그다음 최신순으로 5개
    final briefs = noticeBriefs(5);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '공지', count: noticeCount, onOpenAll: onOpenAll),
          SizedBox(height: 4),
          if (briefs.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(0, 18, 0, 26),
              child: Center(
                child: Text(
                  '올라온 공지가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < briefs.length; i++) ...[
              if (i > 0) Divider(),
              _NoticeRow(
                brief: briefs[i],
                onTap: () => _open(context, briefs[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  _NoticeRow({required this.brief, required this.onTap});

  final NoticeBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = brief.title;
    final pinned = brief.pinned;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PIN',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 아직 안 읽은 공지는 목록과 같은 파란 점으로 표시한다
                if (brief.unread) ...[
                  SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              '${brief.author} · ${brief.time}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
