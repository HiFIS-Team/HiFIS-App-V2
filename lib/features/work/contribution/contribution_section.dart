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
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/nav/month_bar.dart';
import '../../../core/widgets/nav/pick_filter_button.dart';
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

  /// 원장에서 온 줄 — **기여로 치는 것만** 온다 (서버 `contribBoard`).
  ///
  /// 예전에는 둘로 나눠 받았다 (기여 갈래 + 음수 전부). 그러면 프로젝트 평가나
  /// 방문 경로처럼 **더해지는데 기여 갈래가 아닌 것**이 어디에도 안 섰다.
  /// 이제 한 번에 받고 부호는 줄마다 본다 (2026-09-16 요청).
  List<ScoreEvent> _events = const [];

  /// 보고 있는 달 — 달마다 끝나는 점수라 지난달을 돌아볼 일이 있다
  ///
  /// 예전에는 이번 달로 박혀 있어서, 달이 바뀌는 순간 지난달에 받은 기여가
  /// 통째로 안 보였다 (2026-09-06 요청).
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// 달을 옆기는 중인가 — 건수가 깜빡이지 않게 넣어 둔다
  bool _turning = false;

  /// 다음 달로 갈 수 있는가 — 이번 달보다 앞으로는 안 간다
  bool get _canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  Future<void> _goMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _turning = true;
    });
    await _load();
    if (mounted) setState(() => _turning = false);
  }

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

  void _rebuild() => _items = _merge(_received, _given, _events);

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
    final period = periodKey(_month);
    const noGrants = <ContributionGrant>[];
    try {
      // 셋 다 이번 달만. 안 쓰는 것은 아예 안 부른다.
      final givenRequest = myRole.canGrant
          ? ContributionApi.list(grantedById: me.id, period: period)
          : Future.value(noGrants);
      final receivedRequest = _givenOnly
          ? Future.value(noGrants)
          : ContributionApi.list(employeeId: me.id, period: period);
      // 점수 원장 — **대표·관리자는 전 직원 것을 본다** (2026-08-13 결정).
      //
      // 근무 외 출근 점수는 사람이 주는 게 아니라 스캔이 붙여서, 예전에는
      // "누가 받았는지"를 볼 자리가 아무 데도 없었다. 본인만 자기 것을 봤다.
      // [employeeId] 를 안 주면 서버가 볼 수 있는 만큼 다 준다 (그 둘은 전 지점).
      // 지점 고르개는 **앱이 건다** — 서버 스코프는 권한에서 나오는 값이라
      // 헤더에서 고른 지점과 다르다.
      //
      // **한 번만 부른다** (2026-09-16). 예전에는 기여 갈래와 음수를 따로
      // 받았는데, 그러면 프로젝트 평가나 방문 경로처럼 **더해지는데 기여
      // 갈래가 아닌 것**이 어디에도 안 섰다. 무엇이 기여인지는 서버가 가른다
      // (`contribBoard`) — 환경정비·수업 싸인·회원 친절도는 안 온다.
      final eventRequest = ScoreApi.events(
        employeeId: _givenOnly ? null : me.id,
        period: period,
        contribBoard: true,
      );
      final given = await givenRequest;
      final received = await receivedRequest;
      final events = await eventRequest;
      if (!mounted) return;
      setState(() {
        _received = received;
        _given = given;
        _events = events;
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
  ) {
    // **남의 것이 섞여 올 때만 거른다.** 그 밖에는 원장이 이미 `employeeId=나` 라
    // 여기서 지점을 또 걸면 내가 다른 지점을 보는 동안 **내 자동 점수가 통째로
    // 사라진다** (점장이 지점을 고를 수 있게 되면서 걸린 자리 — 2026-08-14).
    final scope = _givenOnly ? branchScopeId : null;
    final me = currentUser?.id;

    // 부여 줄 ↔ 원장 줄 짝짓기 — **되돌리려면 원장 줄 id 가 있어야 한다.**
    //
    // 기여 부여는 `/contributions` 와 원장 **둘 다**에 남는데, 화면에 그리는
    // 것은 앞의 것이다 (항목 종류가 거기에만 있다). 뒤의 것을 안 찾아 두면
    // 부여받은 줄에는 되돌리기 아이콘을 못 단다.
    final ledgerOfGrant = {
      for (final event in events)
        if (event.sourceRefId != null) event.sourceRefId!: event.id,
    };

    /// 남의 것이 섞여 올 때만 지점으로 거른다 — 원장이 이미 `employeeId=나` 인
    /// 화면에서 또 걸면 내가 다른 지점을 보는 동안 **내 점수가 통째로 사라진다**
    bool inScope(ScoreEvent event) => scope == null || event.branchId == scope;

    /// 내 것에는 이름을 안 붙인다 — 내 화면에서 내 이름을 부를 이유가 없다
    String? whose(ScoreEvent event) => event.employeeId == me
        ? null
        : StaffDirectory.instance.byId(event.employeeId)?.name;

    return [
      for (final grant in received)
        _Contribution(
          kind: grant.type,
          title: grant.reason,
          points: grant.points,
          date: grant.createdAt,
          eventId: ledgerOfGrant[grant.id],
          grantId: grant.id,
          person: StaffDirectory.instance.byId(grant.grantedById)?.name,
          granted: true,
        ),
      for (final grant in given)
        _Contribution(
          kind: grant.type,
          title: grant.reason,
          points: grant.points,
          date: grant.createdAt,
          eventId: ledgerOfGrant[grant.id],
          grantId: grant.id,
          person: StaffDirectory.instance.byId(grant.employeeId)?.name,
          given: true,
          granted: true,
        ),
      for (final event in events)
        if (inScope(event))
          // 기여 부여는 **바로 위에서 이미 세웠다** — 원장 줄로 한 번 더
          // 세우면 한 부여가 두 줄이 된다. 부여 줄이 없는 기여(근무 외 출근·
          // 매출성과)만 여기서 선다
          if (event.category != ScoreCategory.contrib)
            _Contribution(
              kind: null,
              eventId: event.id,
              category: event.category,
              title: event.reason ?? event.category.label,
              points: event.points,
              date: event.createdAt,
              person: whose(event),
            )
          else if (event.automatic)
            _Contribution(
              kind: _autoKindOf(event),
              eventId: event.id,
              title: event.reason ?? _autoKindOf(event).label,
              points: event.points,
              date: event.createdAt,
              person: whose(event),
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
  /// 오간 점수를 없던 일로 하는 자리라 프로젝트 점수 부여·사유서 승인과 같은
  /// 종류다. `canGrant`(점장 이상)와 헷갈리면 안 된다 — 주는 것과 준 것을
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
    // **부호에 따라 뒷말이 뒤집힌다.** 깎인 것은 다시 깎을 길이 없고, 더해진
    // 것은 다시 줄 수는 있다 — 한 문장으로 같이 쓰면 한쪽이 거짓말이 된다
    final tail = item.isPenalty ? '되돌리면 다시 깎을 수 없어요.' : '취소하면 그만큼 점수가 줄어요.';
    final ok = await showConfirmDialog(
      context,
      icon: Icons.restore_rounded,
      title: item.isPenalty ? '점수를 되돌릴까요?' : '점수를 취소할까요?',
      message: '$who${item.label} ${item.pointsLabel}점이 없던 일이 돼요.\n$tail',
      confirmLabel: item.isPenalty ? '되돌리기' : '취소하기',
    );
    if (!ok || !mounted) return false;
    try {
      await ScoreApi.revert(id);
      if (!mounted) return true;
      // 목록에서 바로 빼고 조용히 다시 받는다 — 지운 줄이 남아 있으면
      // 한 번 더 누르게 되고 그때는 404 다
      setState(() {
        _events = [
          for (final event in _events)
            if (event.id != id) event,
        ];
        // 기여 부여는 **부여 줄도 서버가 같이 지운다** — 여기서도 빼야 목록에
        // 안 남는다 (원장 줄만 빼면 부여 목록에서 온 줄이 그대로 선다)
        bool kept(ContributionGrant grant) => grant.id != item.grantId;
        _received = _received.where(kept).toList();
        _given = _given.where(kept).toList();
        _rebuild();
      });
      AppToast.show(
        context,
        item.isPenalty
            ? '${item.points.abs()}점을 되돌렸어요'
            : '${item.points.abs()}점을 취소했어요',
      );
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
          _monthBar(),
          SizedBox(height: 8),
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
              text: '${_month.month}월 기여 기록이 없어요',
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
        _monthBar(),
        SizedBox(height: 8),
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

  /// 달 이동 줄 — 환경정비 내역·동료 평가와 **같은 부품이다**
  Widget _monthBar() => MonthBar(
    month: _month,
    count: _items.length,
    loading: _turning,
    onPrev: () => _goMonth(-1),
    onNext: _canGoNext ? () => _goMonth(1) : null,
  );
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
    this.grantId,
    this.category,
    this.person,
    this.given = false,
    this.granted = false,
  });

  /// 점수 원장 줄 id — **되돌릴 때 이 값을 쓴다**
  ///
  /// 예전에는 깎인 줄에만 채웠다. 이제 더해진 줄도 되돌릴 수 있어서 거의 다
  /// 채워진다 — 비는 것은 원장에 안 쌓인 줄뿐이다 (대표·관리자에게 준 기여는
  /// `accrue_score` 가 안 쌓는다).
  final String? eventId;

  /// 기여 부여 줄 id — 되돌리면 서버가 이 줄도 같이 지우므로 화면에서도 뺀다
  final String? grantId;

  /// 어느 기여 항목인가 — 네 칸짜리 항목 판(`_KindGrid`)에 서는 것만 채워진다
  final ContribType? kind;

  /// 기여 항목이 아닌 줄은 어느 갈래인가 — 프로젝트 평가·방문 경로·차감 등
  ///
  /// **[kind] 와 둘 중 하나만 찬다.** 앞의 것은 항목 판에 서는 기여 넷이고,
  /// 이건 내역 목록에만 서는 나머지다.
  final ScoreCategory? category;

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

  /// **사람이 손으로 얹어 준 점수인가** — 근무 외 출근·매출처럼
  /// 저절로 들어오는 것과 가른다 (2026-09-06 요청 — "추가 점수 부여된 거 체크").
  final bool granted;

  /// 되돌릴 수 있는 줄인가 — **원장 줄이 있어야 한다**
  ///
  /// 서버가 센터 기여도 내역에 선 줄만 되돌려 주고(`NOT_ON_BOARD`), 이 목록은
  /// 그 줄로만 만든다. 그래서 여기 있으면 되돌릴 수 있다 — 다만 원장에 안 쌓인
  /// 줄이 하나 있다: **대표·관리자에게 준 기여**는 `accrue_score` 가 안 쌓아서
  /// 부여 줄만 남는다. 그때는 아이콘을 안 그린다 (눌러도 지울 것이 없다).
  bool get canRevert => eventId != null;

  /// 깎인 것인가 — 화면은 이걸로 색과 부호를 가른다
  ///
  /// **부호로 가른다** (2026-09-16). 예전에는 `kind == null` 로 갈랐는데,
  /// 기여 항목이 아니면서 **더해지는** 줄(프로젝트 평가·방문 경로)이 들어오면서
  /// 그 셈이 깨졌다 — `+30` 이 빨간 차감으로 보였다.
  bool get isPenalty => points < 0;

  /// 카드에 그릴 아이콘 — 기여 항목은 항목 아이콘, 나머지는 갈래마다
  IconData get icon => switch ((kind, category)) {
    (final ContribType type?, _) => type.icon,
    (_, ScoreCategory.late) => CupertinoIcons.alarm_fill,
    (_, ScoreCategory.taskMiss) => CupertinoIcons.xmark_circle_fill,
    (_, ScoreCategory.peerMiss) =>
      CupertinoIcons.person_crop_circle_badge_xmark,
    (_, ScoreCategory.project) => CupertinoIcons.folder_fill,
    (_, ScoreCategory.blog) => CupertinoIcons.pencil_outline,
    (_, ScoreCategory.instagram) => CupertinoIcons.camera_fill,
    (_, ScoreCategory.otPt) => CupertinoIcons.arrow_right_circle_fill,
    (_, ScoreCategory.env) => CupertinoIcons.exclamationmark_bubble_fill,
    (_, ScoreCategory.operator) => CupertinoIcons.star_fill,
    _ =>
      isPenalty
          ? CupertinoIcons.minus_circle_fill
          : CupertinoIcons.plus_circle_fill,
  };

  /// 깎인 것은 **전부 빨강**이다 — 종류를 색으로 또 가르면 목록이 알록달록해진다
  Color get color =>
      isPenalty ? AppColors.error : (kind?.color ?? AppColors.primary);

  /// 줄 제목 — 깎인 것에만 `차감` 을 붙인다
  ///
  /// 더해진 줄에 붙이면 `프로젝트 달성 차감 +30` 처럼 말이 뒤집힌다.
  String get label => kind?.label ?? _categoryLabel;

  String get _categoryLabel {
    // **환경정비 갈래로 오는 것은 컴플레인 해결뿐이다.** 대표가 컴플레인을
    // 승인하면 `클레임해결` 항목으로 15점이 붙는 구조라 갈래가 ENV 다
    // (서버 `_contrib_board` 가 그 항목만 골라 보낸다). 갈래 이름을 그대로
    // 쓰면 `환경정비` 로 떠서 세탁·청소와 한 덩어리로 보인다.
    final name = category == ScoreCategory.env
        ? claimLabel
        : (category?.label ?? '점수');
    return isPenalty ? '$name 차감' : name;
  }

  /// 컴플레인 해결 — 서버 `CLAIM_ITEM_NAME` 이 붙여 주는 항목 이름의 화면 표기
  static const claimLabel = '컴플레인 해결';

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
