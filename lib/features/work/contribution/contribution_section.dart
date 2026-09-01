import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/util/skeleton_delay.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/contribution_api.dart';
import '../../../core/api/work/score_api.dart';
import '../../../core/data/branch_scope.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/input/person_picker.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
import '../work_skeleton.dart';
part 'contribution_summary.dart';
part 'contribution_history.dart';
part 'contribution_grant.dart';

/// 센터 기여도 탭 콘텐츠
///
/// 네 가지가 이번 달 기여 점수로 쌓인다.
/// - **창의적 아이디어 · 자발적 목표 업무**: 대표·관리자·점장이 보고 직접 준다
/// - **근무 외 출근**: 근무 시간 밖에 출퇴근을 찍으면 자동으로 들어온다
///   (기록이 빠졌을 때 사람이 직접 줄 수도 있다)
/// - **매출 성과**: 급여 마감 때 그달 매출에서 계산돼 들어온다
///
/// 그래서 두 곳에서 받아 합친다 — 부여 내역은 `/contributions`,
/// 자동으로 쌓인 것은 점수 원장(`/scores`)에만 있다.
class ContributionSection extends StatefulWidget {
  ContributionSection({super.key});

  @override
  State<ContributionSection> createState() => _ContributionSectionState();
}

class _ContributionSectionState extends State<ContributionSection>
    with SkeletonDelay<ContributionSection> {
  /// 화면에 그리는 목록 — 받아 둔 것을 지점 필터까지 걸러 세운 결과
  List<_Contribution> _items = const [];

  /// 받아 둔 원본 — 지점을 바꿀 때 다시 요청하지 않으려고 들고 있는다
  List<ContributionGrant> _received = const [];
  List<ContributionGrant> _given = const [];
  List<ScoreEvent> _events = const [];

  /// 깎인 점수 — 지각·업무 누락처럼 **볼 자리가 없던 것들** (2026-08-28)
  List<ScoreEvent> _penalties = const [];

  @override
  void initState() {
    super.initState();
    branchScope.addListener(_onBranchScope);
    _load();
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다 — 받아 둔 것만 다시 거른다 (요청은 안 나간다)
  void _onBranchScope() {
    if (mounted) setState(_rebuild);
  }

  void _rebuild() => _items = _merge(_received, _given, _events, _penalties);

  /// 받는 쪽이 아니라 **주는 쪽만** 보는 사람인가 — 대표·관리자
  ///
  /// 기여도는 자기보다 아래에만 주는 것이라(서버 `GRANTABLE`) 그 둘은 받을
  /// 일이 없다. 본인 것으로 거르면 늘 비어서, 대신 **내가 준 내역**을 본다.
  /// 점장은 주기도 받기도 해서 둘을 한 목록에 담는다.
  static bool get _givenOnly => myRole.boss;

  Future<void> _load() async {
    final me = currentUser;
    if (me == null) {
      setState(endLoad);
      return;
    }
    final period = periodKey(DateTime.now());
    const noGrants = <ContributionGrant>[];
    try {
      // 셋 다 이번 달만. 안 쓰는 것은 아예 안 부른다.
      final givenRequest = myRole.canGrant
          ? ContributionApi.list(grantedById: me.id, period: period)
          : Future.value(noGrants);
      final receivedRequest = _givenOnly
          ? Future.value(noGrants)
          : ContributionApi.list(employeeId: me.id, period: period);
      // 자동으로 쌓인 점수 — **대표·관리자는 전 직원 것을 본다** (2026-08-13 결정).
      //
      // 근무 외 출근 점수는 사람이 주는 게 아니라 스캔이 붙여서, 예전에는
      // "누가 받았는지"를 볼 자리가 아무 데도 없었다. 본인만 자기 것을 봤다.
      // [employeeId] 를 안 주면 서버가 볼 수 있는 만큼 다 준다 (그 둘은 전 지점).
      // 지점 고르개는 **앱이 건다** — 서버 스코프는 권한에서 나오는 값이라
      // 헤더에서 고른 지점과 다르다.
      final eventRequest = ScoreApi.events(
        employeeId: _givenOnly ? null : me.id,
        category: ScoreCategory.contrib,
        period: period,
      );
      // 깎인 점수 — **어디에도 안 보이던 것들이다** (2026-08-28 대표 요청).
      //
      // 지각(`LATE`)·업무 누락(`TASK_MISS`)은 랭킹 어느 탭에도 안 서고
      // 종합 점수만 조용히 깎았다. 여기 `+` 옆에 같이 세운다.
      //
      // **카테고리로 안 부른다** — 그러면 요청이 종류만큼 늘고, 프로젝트
      // 평가나 운영자 감점처럼 음수가 될 수 있는 나머지를 빠뜨린다.
      // 서버가 부호로 잘라 준다 (`negativeOnly`).
      final penaltyRequest = ScoreApi.events(
        employeeId: _givenOnly ? null : me.id,
        period: period,
        negativeOnly: true,
      );
      final given = await givenRequest;
      final received = await receivedRequest;
      final events = await eventRequest;
      final penalties = await penaltyRequest;
      if (!mounted) return;
      setState(() {
        _received = received;
        _given = given;
        _events = events;
        _penalties = penalties;
        _rebuild();
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 부여 내역과 자동 점수를 한 줄기로 합친다
  ///
  /// 부여분은 `/contributions` 에 항목 종류가 있고, 자동분은 점수 원장에만
  /// 있으므로 원장에서 **사람이 준 게 아닌 것**만 골라 붙인다.
  /// 둘을 다 원장에서 뽑으면 아이디어인지 목표 업무인지 알 수 없다.
  ///
  /// 대표·관리자가 볼 때는 자동분이 **남의 것도 섞여 오므로** 지점 고르개로
  /// 거르고 받은 사람 이름을 붙인다. 본인 것만 보는 사람은 예전 그대로다.
  static List<_Contribution> _merge(
    List<ContributionGrant> received,
    List<ContributionGrant> given,
    List<ScoreEvent> events,
    List<ScoreEvent> penalties,
  ) {
    // **남의 것이 섞여 올 때만 거른다.** 그 밖에는 원장이 이미 `employeeId=나` 라
    // 여기서 지점을 또 걸면 내가 다른 지점을 보는 동안 **내 자동 점수가 통째로
    // 사라진다** (점장이 지점을 고를 수 있게 되면서 걸린 자리 — 2026-08-14).
    final scope = _givenOnly ? branchScopeId : null;
    final me = currentUser?.id;
    return [
      for (final grant in received)
        _Contribution(
          kind: grant.type,
          title: grant.reason,
          points: grant.points,
          date: grant.createdAt,
          person: StaffDirectory.instance.byId(grant.grantedById)?.name,
        ),
      for (final grant in given)
        _Contribution(
          kind: grant.type,
          title: grant.reason,
          points: grant.points,
          date: grant.createdAt,
          // 준 목록에서는 상대가 **받은 사람**이다
          person: StaffDirectory.instance.byId(grant.employeeId)?.name,
          given: true,
        ),
      for (final event in events)
        if (event.automatic && (scope == null || event.branchId == scope))
          _Contribution(
            kind: _autoKindOf(event),
            title: event.reason ?? _autoKindOf(event).label,
            points: event.points,
            date: event.createdAt,
            // 내 것에는 이름을 안 붙인다 — 내 화면에서 내 이름을 부를 이유가 없다
            person: event.employeeId == me
                ? null
                : StaffDirectory.instance.byId(event.employeeId)?.name,
          ),
      // 깎인 것 — `kind` 가 없다. 항목 네 칸(`_KindGrid`)에는 안 서고
      // 내역 목록에만 선다 (기여 항목이 아니라 그 반대다)
      for (final event in penalties)
        if (scope == null || event.branchId == scope)
          _Contribution(
            kind: null,
            eventId: event.id,
            penalty: event.category,
            title: event.reason ?? event.category.label,
            points: event.points,
            date: event.createdAt,
            person: event.employeeId == me
                ? null
                : StaffDirectory.instance.byId(event.employeeId)?.name,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 자동으로 들어온 점수가 어느 항목인지 — 원본 표시로 가른다
  static ContribType _autoKindOf(ScoreEvent event) {
    final ref = event.sourceRefId ?? '';
    // 매출 성과는 `sales:2026-07`, 근무 외 출근은 `offhours:...`
    return ref.startsWith('sales:') ? ContribType.sales : ContribType.extraWork;
  }

  /// 기여 점수 주기 — 권한이 있는 사람만 보인다
  Future<void> _grant() async {
    final granted = await showFullPage<bool>(context, (_) => _GrantScreen());
    if (granted == true && mounted) await _load();
  }

  /// 이 사람이 되돌릴 수 있는가 — **MASTER 만이다**
  ///
  /// 깎은 것을 없던 일로 하는 자리라 프로젝트 점수 부여·사유서 승인과 같은
  /// 종류다. `canGrant`(점장 이상)와 헷갈리면 안 된다 — 주는 것과 깎은 것을
  /// 무르는 것은 다른 판단이다.
  static bool get _canRevert => myRole == Role.master;

  /// 깎인 점수 한 줄을 되돌린다 — 한 번 더 묻는다
  ///
  /// **되돌렸으면 true.** 부르는 쪽(내역 화면)이 이 값을 보고 줄을 뺀다 —
  /// 안 돌려주면 확인창을 띄우는 사이에 줄이 먼저 사라진다.
  Future<bool> _revert(_Contribution item) async {
    final id = item.eventId;
    if (id == null) return false;
    final who = item.person == null ? '' : '${item.person}님의 ';
    final ok = await showConfirmDialog(
      context,
      icon: Icons.restore_rounded,
      title: '점수를 되돌릴까요?',
      message:
          '$who${item.label} ${item.points}점이 없던 일이 돼요.\n'
          '되돌리면 다시 깎을 수 없어요.',
      confirmLabel: '되돌리기',
    );
    if (!ok || !mounted) return false;
    try {
      await ScoreApi.revert(id);
      if (!mounted) return true;
      // 목록에서 바로 빼고 조용히 다시 받는다 — 지운 줄이 남아 있으면
      // 한 번 더 누르게 되고 그때는 404 다
      setState(() {
        _penalties = [
          for (final event in _penalties)
            if (event.id != id) event,
        ];
        _rebuild();
      });
      AppToast.show(context, '${item.points.abs()}점을 되돌렸어요');
      return true;
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
      return false;
    }
  }

  void _openHistory() {
    showFullPage<void>(
      context,
      (_) => _ContributionHistoryScreen(
        items: _items,
        onRevert: _canRevert ? _revert : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return WorkSectionSkeleton();

    // 폰은 기여마다 카드 하나 (다른 업무 목록과 같은 결).
    // 데스크톱은 2단 화면이라 카드가 과해서 기존 줄 목록을 그대로 쓴다.
    if (!isDesktop) {
      // 목록에는 최근 5건만 — 나머지는 전체 보기 화면에서
      final recent = _items.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 항목 넷 — 무엇으로 점수가 쌓였는지
          _KindGrid(items: _items),
          if (myRole.canGrant) ...[
            SizedBox(height: 16),
            _GrantBanner(onTap: _grant),
          ],
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '기여 내역',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Text('${_items.length}', style: AppTextStyles.caption),
                Spacer(),
                SeeAllButton(onTap: _openHistory),
              ],
            ),
          ),
          SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(
              icon: Icons.workspace_premium_rounded,
              text: '이번 달 기여 기록이 없어요',
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _ContributionCard(
                item: recent[i],
                onRevert: _canRevert ? () => _revert(recent[i]) : null,
              ),
            ],
        ],
      );
    }

    return Column(
      children: [
        // 항목 넷 — 무엇으로 점수가 쌓였는지
        _KindGrid(items: _items),
        if (myRole.canGrant) ...[
          SizedBox(height: 16),
          _GrantBanner(onTap: _grant),
        ],
        SizedBox(height: 16),
        _HistoryCard(
          items: _items.take(5).toList(),
          total: _items.length,
          onOpenAll: _openHistory,
          onRevert: _canRevert ? _revert : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 모델
// ---------------------------------------------------------------------------

/// 화면에서 항목마다 쓰는 아이콘과 색
extension _KindStyle on ContribType {
  IconData get icon => switch (this) {
    ContribType.idea => CupertinoIcons.lightbulb_fill,
    ContribType.goal => CupertinoIcons.flag_fill,
    ContribType.extraWork => CupertinoIcons.clock_fill,
    ContribType.sales => CupertinoIcons.chart_bar_fill,
  };

  Color get color => switch (this) {
    ContribType.idea => AppColors.warning,
    ContribType.goal => AppColors.primary,
    ContribType.extraWork => AppColors.success,
    ContribType.sales => AppColors.violet,
  };

  /// 앱에서 사람이 직접 주는 항목인지
  ///
  /// 서버는 근무 외 출근도 부여를 받지만, 근태에서 자동으로 들어오는 게
  /// 정상 경로라 앱은 아이디어·목표 업무만 준다 (이중 지급 방지).
  bool get grantedInApp => this == ContribType.idea || this == ContribType.goal;
}

/// 기여 한 건 — 부여받은 것과 자동으로 쌓인 것을 같은 모양으로 다룬다
class _Contribution {
  const _Contribution({
    required this.kind,
    required this.title,
    required this.points,
    required this.date,
    this.eventId,
    this.penalty,
    this.person,
    this.given = false,
  });

  /// 점수 원장 줄 id — **깎인 것만 채워진다** (되돌릴 때 이 값을 쓴다)
  final String? eventId;

  /// 어느 기여 항목인가 — **null 이면 깎인 것**이다 ([penalty] 를 본다)
  final ContribType? kind;

  /// 무엇 때문에 깎였나 — 지각·업무 누락 등 ([kind] 가 null 일 때만 채워진다)
  final ScoreCategory? penalty;

  /// 무엇으로 받았는지 (자동 항목은 집계 근거가 들어간다)
  final String title;
  final int points;
  final DateTime date;

  /// 상대 이름 — 받은 것은 **준 사람**, 준 것은 **받은 사람**.
  ///
  /// 자동으로 쌓인 점수는 준 사람이 없어서 보통 비어 있는데, **대표·관리자가
  /// 남의 것을 볼 때는 받은 사람**이 들어간다 (누가 받았는지가 그 화면의 요점이다).
  final String? person;

  /// 내가 준 것인가 — 점장은 준 것과 받은 것을 한 목록에서 본다
  final bool given;

  /// 깎인 것인가 — 화면은 이걸로 색과 부호를 가른다
  bool get isPenalty => kind == null;

  /// 카드에 그릴 아이콘 — 깎인 것은 종류마다 다르게 둔다
  IconData get icon => switch ((kind, penalty)) {
    (final ContribType type?, _) => type.icon,
    (_, ScoreCategory.late) => CupertinoIcons.alarm_fill,
    (_, ScoreCategory.taskMiss) => CupertinoIcons.xmark_circle_fill,
    _ => CupertinoIcons.minus_circle_fill,
  };

  /// 깎인 것은 **전부 빨강**이다 — 종류를 색으로 또 가르면 목록이 알록달록해진다
  Color get color => kind?.color ?? AppColors.error;

  String get label => kind?.label ?? '${penalty?.label ?? '점수'} 차감';

  /// `+3` · `-20` — 부호를 붙여 준다
  String get pointsLabel => points < 0 ? '$points' : '+$points';

  /// 카드 한 줄의 상대 표시 — 조사로 방향을 가른다
  String? get personLabel => person == null
      ? null
      : given
      ? '$person님께'
      : '$person님이';
}

int _sum(List<_Contribution> items) =>
    items.fold(0, (total, c) => total + c.points);

/// '7월 4일'
String _dayLabel(DateTime date) => monthDayLabel(date);
