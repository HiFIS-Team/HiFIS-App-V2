import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/score_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/delayed_spinner.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/nav/pane_transition.dart';
import '../../core/util/screen_refresh.dart';

part 'ranking_models.dart';
part 'ranking_pickers.dart';
part 'ranking_overtake.dart';
part 'ranking_myrank.dart';
part 'ranking_podium.dart';
part 'ranking_table.dart';
part 'ranking_breakdown.dart';

/// 랭킹 화면
///
/// 이번 달 실적을 항목별로 줄 세운다. 매출(금액) · 친절 점수 · 프로젝트 달성(점수) ·
/// 환경정비(점수) · 수업 개수를 각각 보고, 종합은 다섯 항목을 100점으로 환산해
/// 평균 낸 값이다.
///
/// 순위표보다 "내가 몇 등인지"를 먼저 보게 맨 위에 내 순위 카드를 둔다.
class RankingScreen extends StatefulWidget {
  RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with ScreenRefresh<RankingScreen> {
  /// 고른 항목 ([_Metric] 순서)
  int _tab = 0;

  /// 보고 있는 달 — 랭킹은 달마다 새로 시작한다
  ///
  /// 1일이 되면 그 달 실적이 비어 있으니 저절로 초기화된다 (따로 도는 것이 없다).
  /// 날짜는 버리고 **연·월만** 쓴다 — 31일에 열었을 때 이전 달로 넘기면
  /// `DateTime(2026, 7, 31)` 처럼 없는 날이 되어 8월로 되돌아온다.
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    // PC 는 헤더 아이콘이 지점을 정한다 — 바뀌면 순위표를 다시 세운다
    branchScope.addListener(_onBranchScope);
    _load();
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    super.dispose();
  }

  void _onBranchScope() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      await _loadRanking(period: _periodKey);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  /// 서버에 보낼 달 (`YYYY-MM`)
  String get _periodKey =>
      '${_viewMonth.year}-${_viewMonth.month.toString().padLeft(2, '0')}';

  /// 이번 달을 보고 있나 — **다음 달로는 못 넘긴다** (아직 안 온 달이다)
  bool get _isThisMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  /// 달을 옮기고 그 달 판을 다시 받는다
  ///
  /// 사람 고른 것(`_pickedId`)은 푼다 — 달이 바뀌면 그 사람의 점수 내역도
  /// 달라지는데, 열린 채로 두면 옛 달 숫자가 잠깐 남는다.
  void _moveMonth(int step) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + step);
      _pickedId = null;
    });
    _load();
  }

  /// 폰에서 고른 지점 — 폰은 머리말 왼쪽에 고르개가 그대로 있다
  /// 보고 있는 지점
  ///
  /// **셸 헤더의 지점 아이콘 하나가 정한다** (조직도·업무·근태와 같은 값).
  /// 예전에는 폰이 이 화면 왼쪽 위에 고르개를 따로 갖고 있었는데, 화면마다
  /// 있으면 어느 것이 무엇에 걸리는지 헷갈려서 한 곳으로 모았다.
  ///
  /// 고르개는 MASTER·ADMIN 에게만 있다 — 나머지는 늘 '전 지점' 이다.
  String get _branch => branchScopeName;

  _Metric get _metric => _Metric.values[_tab];

  /// 지금 보고 있는 지점 사람들 — 종합 점수의 기준 모집단이기도 하다
  List<_Ranker> get _pool => _rankers
      .where((r) => _branch == _allBranches || r.branch == _branch)
      .toList();

  /// 고른 항목 기준으로 줄 세운 순위표
  List<_Entry> get _entries {
    final pool = _pool;
    final scored = [for (final r in pool) (r, _valueOf(r, _metric, pool))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (var i = 0; i < scored.length; i++)
        _Entry(
          rank: i + 1,
          ranker: scored[i].$1,
          value: scored[i].$2,
          note: _noteOf(scored[i].$1, _metric),
        ),
    ];
  }

  /// 보고 있는 달 — `2026년 8월`
  String get _month => '${_viewMonth.year}년 ${_viewMonth.month}월';

  /// 달 이동 줄 — 근태 달력과 **같은 모양**이다 (좌우 화살표 + 가운데 달)
  ///
  /// 뒤로는 제한이 없다. 기록이 없는 달은 원래 있던 '집계된 실적이 없어요'
  /// 빈 화면이 그대로 뜬다.
  Widget _monthNav() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _arrow(CupertinoIcons.chevron_left, () => _moveMonth(-1)),
      SizedBox(width: 14),
      Text(_month, style: AppTextStyles.title3),
      SizedBox(width: 14),
      // 다음 달은 아직 안 왔으니 늘 비어 있다 — 눌리지 않게 흐려 둔다
      _arrow(
        CupertinoIcons.chevron_right,
        _isThisMonth ? null : () => _moveMonth(1),
      ),
    ],
  );

  /// [onTap] 이 null 이면 흐린 채로 안 눌린다 (자리는 그대로 둔다 — 감추면
  /// 이번 달일 때만 줄이 한 칸 좁아져서 화면이 흔들린다)
  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final box = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 13,
        color: onTap == null ? AppColors.gray300 : AppColors.textSecondary,
      ),
    );
    return onTap == null
        ? box
        : Pressable(onTap: onTap, scale: 0.9, child: box);
  }

  Widget _tabs() => SegmentedTabs(
    labels: [for (final m in _Metric.values) m.label],
    selected: _tab,
    onSelect: (i) => setState(() => _tab = i),
  );

  /// 점수 내역이 열려 있는 사람 — **종합 탭에서만** 채워진다
  ///
  /// 사람 id 로 들고 있는다. 객체로 들면 목록을 다시 받았을 때 옛 인스턴스가
  /// 남아 값이 안 갱신된다.
  String? _pickedId;

  /// 종합 탭에서만 사람을 누를 수 있다 — 다른 탭은 예전 그대로다
  bool get _canPick => _metric == _Metric.overall;

  void _pick(_Ranker ranker) {
    if (!isDesktop) {
      // 아래에서 올라와 화면 끝에 붙는 판 — 손잡이를 쓸어내리거나 밖을
      // 누르면 닫힌다. 뒤는 어두워진다 (`showModalBottomSheet` 기본값).
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        // 하단바를 덮고 화면 아래 끝까지 내려온다
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ScoreBreakdown(ranker: ranker, sheet: true),
      );
      return;
    }
    // PC 는 순위표 옆에 판을 편다. 같은 사람을 다시 누르면 접는다
    setState(() => _pickedId = _pickedId == ranker.id ? null : ranker.id);
  }

  List<Widget> _body(List<_Entry> entries) {
    // 열어 둔 사람이 지금 목록에 없으면(지점·탭을 옮겼다) 판을 접는다
    final picked = !_canPick
        ? null
        : entries
              .where((e) => e.ranker.id == _pickedId)
              .map((e) => e.ranker)
              .firstOrNull;

    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final podium = _Podium(
      top: top,
      metric: _metric,
      big: !isDesktop,
      onPick: _canPick ? _pick : null,
    );

    // 대표·관리자는 실적이 없어 '내 순위'가 늘 비어 있다.
    // 그 자리에 누가 누구를 앞질렀는지를 대신 놓는다.
    // 다른 지점을 보고 있으면 내 순위가 없다 — 그때는 시상대만 넓게 쓴다
    final at = entries.indexWhere((e) => e.ranker.isMe);
    final myCard = _isRankBoss
        ? _OvertakeCard(metric: _metric, branch: _branch)
        : at < 0
        ? null
        : _MyRankCard(
            entry: entries[at],
            // 따라잡을 앞사람 — 1위면 뒤에서 쫓아오는 사람을 대신 보여준다
            above: at > 0 ? entries[at - 1] : null,
            below: at < entries.length - 1 ? entries[at + 1] : null,
            metric: _metric,
            total: entries.length,
          );

    return [
      // 데스크톱은 폭이 남아 내 순위와 시상대를 나란히 놓는다.
      // 폰은 시상대를 먼저 크게 세우고 내 순위를 그 아래에 둔다.
      if (myCard == null)
        podium
      else if (isDesktop)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: myCard),
              SizedBox(width: 16),
              Expanded(flex: 2, child: podium),
            ],
          ),
        )
      else ...[
        podium,
        SizedBox(height: 16),
        myCard,
      ],
      SizedBox(height: isDesktop ? 16 : 12),
      // 종합에서 사람을 고르면 PC 는 순위표 옆에 점수 내역을 편다.
      // 폰은 시트로 뜨므로 목록 폭이 안 바뀐다.
      if (picked != null && isDesktop)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _rankList(rest, top.length + 1, picked)),
            SizedBox(width: 16),
            SizedBox(
              width: 268,
              child: _ScoreBreakdown(
                ranker: picked,
                onClose: () => setState(() => _pickedId = null),
              ),
            ),
          ],
        )
      else
        _rankList(rest, top.length + 1, picked),
    ];
  }

  Widget _rankList(List<_Entry> rest, int startsAt, _Ranker? picked) =>
      _RankList(
        entries: rest,
        metric: _metric,
        startsAt: startsAt,
        onPick: _canPick ? _pick : null,
        picked: picked?.id,
      );

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    if (!isDesktop) {
      return PhoneListScaffold(
        title: '랭킹',
        filter: _PhoneTabs(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        children: [
          _monthNav(),
          SizedBox(height: 14),
          PaneTransition(
            step: _tab,
            child: entries.isEmpty
                ? EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')
                : Column(children: _body(entries)),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(
              // 달은 아래 이동 줄이 들고 있다 — 부제에도 적으면 두 번 나온다
              title: '랭킹',
              subtitle: '실적 기준으로 줄 세웠어요',
              // 지점 고르개는 헤더의 지점 아이콘으로 옮겼다 — 조직도·업무와
              // 같은 값을 본다 (core/data/branch_scope.dart)
            ),
            SizedBox(height: 22),
            _tabs(),
            SizedBox(height: 16),
            _monthNav(),
            SizedBox(height: 16),
            // 탭을 옮길 때 내용이 같이 갈린다 (업무·모니터링과 같은 모션)
            PaneTransition(
              step: _tab,
              child: entries.isEmpty
                  ? EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')
                  : Column(children: _body(entries)),
            ),
          ],
        ),
      ),
    );
  }
}
