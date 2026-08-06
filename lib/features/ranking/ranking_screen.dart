import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/score_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
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
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadRanking();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
  }

  /// 지점은 전체로 시작한다 (내 지점만 보려면 직접 고른다)
  String _branch = _allBranches;

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

  List<Widget> _body(List<_Entry> entries) {
    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final podium = _Podium(top: top, metric: _metric, big: !isDesktop);

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
      _RankList(entries: rest, metric: _metric, startsAt: top.length + 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    if (!isDesktop) {
      return PhoneListScaffold(
        title: '랭킹',
        // 고를 지점이 하나뿐이면 안 그린다 (지점 없는 사람·명단을 못 받았을 때)
        leading: _branchChoices.length > 1
            ? _PhoneBranchFilter(
                selected: _branch,
                onSelect: (branch) => setState(() => _branch = branch),
              )
            : null,
        filter: _PhoneTabs(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        children: [
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
              title: '랭킹',
              subtitle: '$_month 실적 기준으로 줄 세웠어요',
              trailing: _BranchPicker(
                selected: _branch,
                onSelect: (branch) => setState(() => _branch = branch),
              ),
            ),
            SizedBox(height: 22),
            _tabs(),
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
