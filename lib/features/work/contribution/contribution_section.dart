import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/contribution_api.dart';
import '../../../core/api/work/score_api.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/display/avatar.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
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

class _ContributionSectionState extends State<ContributionSection> {
  bool _loading = true;

  /// 이번 달 내 기여 (부여 + 자동)
  List<_Contribution> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 받는 쪽이 아니라 **주는 쪽만** 보는 사람인가 — 대표·관리자
  ///
  /// 기여도는 자기보다 아래에만 주는 것이라(서버 `GRANTABLE`) 그 둘은 받을
  /// 일이 없다. 본인 것으로 거르면 늘 비어서, 대신 **내가 준 내역**을 본다.
  /// 점장은 주기도 받기도 해서 둘을 한 목록에 담는다.
  static bool get _givenOnly => myRole == Role.master || myRole == Role.admin;

  Future<void> _load() async {
    final me = currentUser;
    if (me == null) {
      setState(() => _loading = false);
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
      // 자동으로 쌓인 점수는 받는 쪽에만 있다 — 주는 목록에는 낄 자리가 없다
      final eventRequest = _givenOnly
          ? Future.value(const <ScoreEvent>[])
          : ScoreApi.events(
              employeeId: me.id,
              category: ScoreCategory.contrib,
              period: period,
            );
      final given = await givenRequest;
      final received = await receivedRequest;
      final events = await eventRequest;
      if (!mounted) return;
      setState(() {
        _items = _merge(received, given, events);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 부여 내역과 자동 점수를 한 줄기로 합친다
  ///
  /// 부여분은 `/contributions` 에 항목 종류가 있고, 자동분은 점수 원장에만
  /// 있으므로 원장에서 **사람이 준 게 아닌 것**만 골라 붙인다.
  /// 둘을 다 원장에서 뽑으면 아이디어인지 목표 업무인지 알 수 없다.
  static List<_Contribution> _merge(
    List<ContributionGrant> received,
    List<ContributionGrant> given,
    List<ScoreEvent> events,
  ) {
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
        if (event.automatic)
          _Contribution(
            kind: _autoKindOf(event),
            title: event.reason ?? _autoKindOf(event).label,
            points: event.points,
            date: event.createdAt,
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

  void _openHistory() {
    showFullPage<void>(
      context,
      (_) => _ContributionHistoryScreen(items: _items),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

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
              _ContributionCard(item: recent[i]),
            ],
        ],
      );
    }

    return Column(
      children: [
        _ScoreCard(items: _items, given: _givenOnly),
        SizedBox(height: 16),
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
    this.person,
    this.given = false,
  });

  final ContribType kind;

  /// 무엇으로 받았는지 (자동 항목은 집계 근거가 들어간다)
  final String title;
  final int points;
  final DateTime date;

  /// 상대 이름 — 받은 것은 **준 사람**, 준 것은 **받은 사람**.
  /// 자동으로 쌓인 점수는 상대가 없어서 비어 있다.
  final String? person;

  /// 내가 준 것인가 — 점장은 준 것과 받은 것을 한 목록에서 본다
  final bool given;

  /// 사람이 준 게 아니라 기록에서 자동으로 들어온 점수인가
  bool get automatic => person == null;

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
