import 'package:cupertino_native/cupertino_native.dart';
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
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/delayed_spinner.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_menu.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/nav/pane_transition.dart';

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

class _RankingScreenState extends State<RankingScreen> {
  /// 고른 항목 ([_Metric] 순서)
  int _tab = 0;

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
      await _loadRanking();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  /// 폰에서 고른 지점 — 폰은 머리말 왼쪽에 고르개가 그대로 있다
  String _phoneBranch = _allBranches;

  /// 보고 있는 지점
  ///
  /// **PC 는 헤더의 지점 아이콘이 정한다** (조직도·업무와 같은 값).
  /// 폰에는 그 헤더가 없어서 화면이 제 고르개를 그대로 쓴다.
  String get _branch => isDesktop ? branchScopeName : _phoneBranch;

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

  /// 이번 달 (랭킹은 달마다 초기화된다)
  String get _month {
    final now = DateTime.now();
    return '${now.year}년 ${now.month}월';
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

  /// 같은 사람을 다시 누르면 접는다 — PC 는 순위표 옆 판, 폰은 아래 바다
  void _pick(_Ranker ranker) =>
      setState(() => _pickedId = _pickedId == ranker.id ? null : ranker.id);

  /// 내려가는 동안 보여줄 마지막 사람
  ///
  /// 바가 미끄러져 내려가는 중에도 안이 채워져 있어야 한다. `_pickedId` 만
  /// 보면 접는 순간 내용이 통째로 사라져서 빈 칸이 내려간다.
  _Ranker? _lastPicked;

  /// 지금 목록에 있는, 내역을 연 사람 (지점·탭을 옮겼으면 null 이다)
  _Ranker? _pickedIn(List<_Entry> entries) {
    if (!_canPick) return null;
    return entries
        .where((e) => e.ranker.id == _pickedId)
        .map((e) => e.ranker)
        .firstOrNull;
  }

  List<Widget> _body(List<_Entry> entries, _Ranker? picked) {
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
      // 폰은 아래에서 바가 올라오므로 목록 폭이 안 바뀐다.
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
    final picked = _pickedIn(entries);
    if (picked != null) _lastPicked = picked;

    if (!isDesktop) {
      return PhoneListScaffold(
        title: '랭킹',
        // 고를 지점이 하나뿐이면 안 그린다 (지점 없는 사람·명단을 못 받았을 때)
        leading: _branchChoices.length > 1
            ? _PhoneBranchFilter(
                selected: _branch,
                onSelect: (branch) => setState(() => _phoneBranch = branch),
              )
            : null,
        filter: _PhoneTabs(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        bottomPanel: _BreakdownBar(
          ranker: picked ?? _lastPicked,
          shown: picked != null,
          onClose: () => setState(() => _pickedId = null),
        ),
        children: [
          PaneTransition(
            step: _tab,
            child: entries.isEmpty
                ? EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')
                : Column(children: _body(entries, picked)),
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
              title: '랭킹',
              subtitle: '$_month 실적 기준으로 줄 세웠어요',
              // 지점 고르개는 헤더의 지점 아이콘으로 옮겼다 — 조직도·업무와
              // 같은 값을 본다 (core/data/branch_scope.dart)
            ),
            SizedBox(height: 22),
            _tabs(),
            SizedBox(height: 16),
            // 탭을 옮길 때 내용이 같이 갈린다 (업무·모니터링과 같은 모션)
            PaneTransition(
              step: _tab,
              child: entries.isEmpty
                  ? EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')
                  : Column(children: _body(entries, picked)),
            ),
          ],
        ),
      ),
    );
  }
}
