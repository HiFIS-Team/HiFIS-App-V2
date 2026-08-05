import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/contribution_api.dart';
import '../../core/api/work/score_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/progress_bar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';

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

  Future<void> _load() async {
    final me = currentUser;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    final period = periodKey(DateTime.now());
    try {
      // 부여 내역과 점수 원장을 같이 띄운다 — 둘 다 이번 달만
      final grantRequest = ContributionApi.list(
        employeeId: me.id,
        period: period,
      );
      final eventRequest = ScoreApi.events(
        employeeId: me.id,
        category: ScoreCategory.contrib,
        period: period,
      );
      final grants = await grantRequest;
      final events = await eventRequest;
      if (!mounted) return;
      setState(() {
        _items = _merge(grants, events);
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
    List<ContributionGrant> grants,
    List<ScoreEvent> events,
  ) {
    return [
      for (final grant in grants)
        _Contribution(
          kind: grant.type,
          title: grant.reason,
          points: grant.points,
          date: grant.createdAt,
          by: StaffDirectory.instance.byId(grant.grantedById)?.name,
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
        _ScoreCard(items: _items),
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
    ContribType.sales => Color(0xFF7C5CFC),
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
    this.by,
  });

  final ContribType kind;

  /// 무엇으로 받았는지 (자동 항목은 집계 근거가 들어간다)
  final String title;
  final int points;
  final DateTime date;

  /// 준 사람 — 자동으로 쌓인 점수는 비어 있다
  final String? by;

  /// 사람이 준 게 아니라 기록에서 자동으로 들어온 점수인가
  bool get automatic => by == null;
}

int _sum(List<_Contribution> items) =>
    items.fold(0, (total, c) => total + c.points);

/// '7월 4일'
String _dayLabel(DateTime date) => '${date.month}월 ${date.day}일';

// ---------------------------------------------------------------------------
// 점수 요약
// ---------------------------------------------------------------------------

/// 이번 달 기여 점수 — 총점과 부여/자동 비중
class _ScoreCard extends StatelessWidget {
  _ScoreCard({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final total = _sum(items);
    // 사람이 준 점수와 기록에서 자동으로 들어온 점수를 가른다
    final granted = _sum(items.where((c) => !c.automatic).toList());
    final auto = total - granted;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 기여 점수',
                  style: AppTextStyles.label,
                ),
              ),
              Text(
                '$total',
                style: AppTextStyles.title1.copyWith(
                  fontSize: 28,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.body2.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 14),
          // 받은 점수와 자동으로 쌓인 점수의 비중
          ProgressBar(ratio: total == 0 ? 0 : granted / total),
          SizedBox(height: 12),
          Row(
            children: [
              _legend(AppColors.primary, '부여받은 점수', granted),
              SizedBox(width: 16),
              _legend(AppColors.gray300, '자동 집계', auto),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, int points) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 6),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      SizedBox(width: 4),
      Text(
        '$points점',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 항목 네 칸 — 무엇으로 몇 점이 쌓였는지
class _KindGrid extends StatelessWidget {
  _KindGrid({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    // 데스크톱은 한 줄에 넷, 폰은 2×2
    final columns = isDesktop ? 4 : 2;
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in ContribType.values)
              SizedBox(
                width: width,
                child: _KindCard(
                  kind: kind,
                  items: items.where((c) => c.kind == kind).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KindCard extends StatelessWidget {
  _KindCard({required this.kind, required this.items});

  final ContribType kind;
  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final points = _sum(items);
    final empty = items.isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kind.icon, size: 15, color: kind.color),
              ),
              Spacer(),
              // 이 항목이 어떻게 들어오는지 — 부여인지 자동인지
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kind.grantedInApp ? '부여' : '자동',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            kind.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$points',
                style: AppTextStyles.title2.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textPrimary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.caption.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textSecondary,
                ),
              ),
              Spacer(),
              Text(
                empty ? '없음' : '${items.length}건',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 부여 권한이 있는 사람에게만 보이는 줄
class _GrantBanner extends StatelessWidget {
  _GrantBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.plus_circle_fill,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기여 점수 주기',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '창의적 아이디어 · 자발적 목표 업무를 직접 챙겨 주세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 내역
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  _HistoryCard({
    required this.items,
    required this.total,
    required this.onOpenAll,
  });

  final List<_Contribution> items;
  final int total;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('기여 내역', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$total',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '이번 달 기여 기록이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _ContributionRow(item: items[i]),
            ],
        ],
      ),
    );
  }
}

/// 폰 목록 카드 — 다른 업무 목록과 같은 결로 기여 하나에 카드 하나
///
/// 데스크톱은 아직 [_ContributionRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _ContributionCard extends StatelessWidget {
  _ContributionCard({required this.item});

  final _Contribution item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.kind.icon, size: 18, color: item.kind.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.kind.label,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      // 부여 항목은 누가 줬는지가 근거다
                      item.by == null
                          ? _dayLabel(item.date)
                          : '${item.by}님 · ${_dayLabel(item.date)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: item.kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '+${item.points}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: item.kind.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 한 줄 — 항목 아이콘, 내용, 준 사람, 점수
class _ContributionRow extends StatelessWidget {
  _ContributionRow({required this.item});

  final _Contribution item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.kind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.kind.icon, size: 15, color: item.kind.color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  // 부여 항목은 누가 줬는지가 근거다
                  item.by == null
                      ? '${item.kind.label} · ${_dayLabel(item.date)}'
                      : '${item.kind.label} · ${item.by}님 · '
                            '${_dayLabel(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '+${item.points}',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 내역 전체 화면 — 이번 달 내 기록
class _ContributionHistoryScreen extends StatelessWidget {
  _ContributionHistoryScreen({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final mine = items;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 68, 24, 32),
              children: [
                if (mine.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                    child: Text(
                      '이번 달 기여 기록이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider),
                    _ContributionRow(item: mine[i]),
                  ],
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 내역', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 기여 점수 주기 (마스터~매니저)
// ---------------------------------------------------------------------------

/// 창의적 아이디어·자발적 목표 업무를 직접 주는 화면
///
/// 근무 외 출근·매출 성과는 기록에서 자동으로 들어오므로 여기서 못 준다.
class _GrantScreen extends StatefulWidget {
  _GrantScreen();

  @override
  State<_GrantScreen> createState() => _GrantScreenState();
}

class _GrantScreenState extends State<_GrantScreen> {
  ContribType _kind = ContribType.idea;
  Employee? _target;
  final _title = TextEditingController();

  bool _saving = false;

  /// 줄 수 있는 사람 — 본인은 뺀다
  ///
  /// 점장은 자기 지점만, 대표·관리자는 전 지점.
  /// (서버는 대상 지점을 막지 않지만, 안 보고 준 점수는 근거가 없다)
  List<Employee> get _people {
    final me = currentUser;
    if (me == null) return const [];
    final sameBranchOnly = me.role == Role.manager;
    return [
      for (final employee in StaffDirectory.instance.employees)
        if (employee.id != me.id &&
            (!sameBranchOnly || employee.branchId == me.branchId))
          employee,
    ];
  }

  bool get _ready => _target != null && _title.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready) {
      AppToast.show(context, '받을 사람과 내용을 채워주세요');
      return;
    }
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final target = _target!;
    try {
      // 점수는 항목마다 정해져 있어 주는 사람이 고르지 않는다
      final grant = await ContributionApi.create(
        employeeId: target.id,
        type: _kind,
        reason: _title.text.trim(),
      );
      if (!mounted) return;
      AppToast.show(context, '${target.name}님에게 ${grant.points}점을 줬어요');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                68,
                24,
                // 마지막 줄(점수)이 아래 버튼·모달 끝에 붙지 않게 넉넉히
                MediaQuery.paddingOf(context).bottom + 130,
              ),
              children: [
                _label('항목'),
                SizedBox(height: 8),
                Row(
                  children: [
                    for (final kind in ContribType.values.where(
                      (k) => k.grantedInApp,
                    ))
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: kind == ContribType.idea ? 8 : 0,
                          ),
                          child: _kindButton(kind),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                _label('받을 사람'),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final person in _people) _personChip(person)],
                ),
                SizedBox(height: 20),
                _label('내용'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _title,
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _kind == ContribType.idea
                          ? '예) 락커 회전율 안내 문구 제안'
                          : '예) 신규 회원 온보딩 문서 정리',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 점수 주기', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomButton(
              label: _saving ? '주는 중...' : '주기',
              active: _ready && !_saving,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.label.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );

  /// 항목 버튼 — 점수가 항목에 붙어 있으므로 여기에 같이 적는다
  Widget _kindButton(ContribType kind) {
    final on = kind == _kind;
    final color = on ? AppColors.primary : AppColors.gray500;

    return Pressable(
      onTap: () => setState(() => _kind = kind),
      scale: 0.97,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kind.icon, size: 16, color: color),
            SizedBox(height: 10),
            Text(
              kind.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${kind.points}점',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on ? AppColors.primary : AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personChip(Employee person) {
    final on = person.id == _target?.id;
    return Pressable(
      onTap: () => setState(() => _target = person),
      scale: 0.96,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 140),
        height: 44,
        padding: EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: person.name, size: 32),
            SizedBox(width: 8),
            Text(
              person.name,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
