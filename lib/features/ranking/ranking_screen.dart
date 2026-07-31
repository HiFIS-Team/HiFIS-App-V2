import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/desktop_header.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/pressable.dart';

part 'ranking_models.dart';

/// 랭킹 화면 (목업)
///
/// 이번 달 실적을 항목별로 줄 세운다. 매출·친절 점수·프로젝트 달성·환경정비를
/// 각각 보고, 종합은 네 항목을 100점으로 환산해 평균 낸 값이다.
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

    // 다른 지점을 보고 있으면 내 순위가 없다 — 그때는 시상대만 넓게 쓴다
    final at = entries.indexWhere((e) => e.ranker.isMe);
    final myCard = at < 0
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
        filter: _PhoneTabs(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        children: entries.isEmpty
            ? [EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')]
            : _body(entries),
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
            if (entries.isEmpty)
              EmptyCard(icon: CupertinoIcons.rosette, text: '집계된 실적이 없어요')
            else
              ..._body(entries),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 항목 · 지점 고르기
// ---------------------------------------------------------------------------

/// 폰 항목 탭 — 다섯 칸을 균등하게 나눈 밑줄 탭 (업무 탭과 같은 결)
///
/// 알약 다섯 개를 늘어놓으면 화면 폭을 넘겨 옆으로 밀어야 하는데,
/// 항목이 몇 개인지 한눈에 안 보인다. 한 화면에 다 세운다.
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _Metric.values.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onSelect(i),
              scale: 0.94,
              child: Container(
                padding: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == selected
                          ? AppColors.primary
                          : AppColors.gray100,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  // 칸보다 이름이 길면 줄여서 맞춘다
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _Metric.values[i].short,
                      maxLines: 1,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        color: i == selected
                            ? AppColors.primary
                            : AppColors.gray500,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 지점 고르기 — 직원 화면과 같은 모양으로 맞춘다
class _BranchPicker extends StatelessWidget {
  _BranchPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 14,
              color: AppColors.gray500,
            ),
            SizedBox(width: 6),
            Text(
              selected == _allBranches ? '전체 지점' : selected,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_branches.length > 1) ...[
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.gray500,
              ),
            ],
          ],
        ),
      ),
    );

    if (_branches.length < 2) return box;

    return PopupMenuButton<String>(
      onSelected: onSelect,
      tooltip: '',
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gray100),
      ),
      itemBuilder: (context) => [
        for (final branch in _branches)
          PopupMenuItem(
            value: branch,
            height: 42,
            child: Row(
              children: [
                Text(
                  branch,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: branch == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: branch == selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                Text(
                  '${_rankers.where((r) => branch == _allBranches || r.branch == branch).length}명',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
      child: box,
    );
  }
}

// ---------------------------------------------------------------------------
// 내 순위
// ---------------------------------------------------------------------------

/// 맨 위 내 순위 카드 — 등수 · 지난달 대비 · 이번 달 값
class _MyRankCard extends StatelessWidget {
  _MyRankCard({
    required this.entry,
    required this.above,
    required this.below,
    required this.metric,
    required this.total,
  });

  final _Entry entry;

  /// 바로 위·아래 사람 (없으면 null)
  final _Entry? above;
  final _Entry? below;

  final _Metric metric;

  /// 이 지점에서 순위에 오른 사람 수 (상위 몇 %인지 계산에 쓴다)
  final int total;

  Widget get _chase =>
      _ChaseLine(entry: entry, above: above, below: below, metric: metric);

  /// 폰 — 아바타·상위 %를 왼쪽에, 등수를 오른쪽에 크게 놓고
  /// 그 아래 한 줄로 다음 순위까지 얼마 남았는지 붙인다
  Widget _phone(int percent) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // 내 순위만 브랜드 테두리로 목록과 구분한다
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: Avatar(name: entry.ranker.name, size: 46),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '내 순위',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                        SizedBox(width: 6),
                        _DeltaBadge(entry: entry, metric: metric),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('상위 $percent%', style: AppTextStyles.title2),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '위',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          SizedBox(height: 12),
          _chase,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (entry.rank * 100 / total).round();

    if (!isDesktop) return _phone(percent);

    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      // 옆 시상대에 높이를 맞추면 남는 자리가 생긴다. Spacer(flex)를 쓰면
      // IntrinsicHeight가 높이를 재는 동안 터지므로, 위·아래 두 덩어리로
      // 나누고 빈자리를 사이에 몰아준다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '내 ${metric.label}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 6),
                  _DeltaBadge(entry: entry, metric: metric),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '위',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '/ $total명',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 14),
              Container(height: 1, color: AppColors.divider),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _format(metric, entry.value),
                          style: AppTextStyles.title3,
                        ),
                        SizedBox(height: 2),
                        Text(entry.note, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '상위 $percent%',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _chase,
            ],
          ),
        ],
      ),
    );
  }
}

/// 다음 순위까지 얼마나 남았는지 — 카드 맨 아래 한 줄
///
/// 순위만 보여주면 뭘 해야 할지 모른다. 바로 위 사람과의 차이를
/// 그 항목의 단위(만원·회·건…)로 바꿔서 "얼마 더"를 알려 준다.
/// 이미 1위면 쫓아오는 사람과의 여유를 대신 보여준다.
class _ChaseLine extends StatelessWidget {
  _ChaseLine({
    required this.entry,
    required this.above,
    required this.below,
    required this.metric,
  });

  final _Entry entry;
  final _Entry? above;
  final _Entry? below;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final chasing = above != null;
    final target = above ?? below;

    // 혼자면 비교할 상대가 없다
    if (target == null) return SizedBox.shrink();

    final gap = chasing
        ? target.value - entry.value
        : entry.value - target.value;
    final color = chasing ? AppColors.primary : AppColors.success;

    final text = gap <= 0
        ? '${target.ranker.name}님과 동점이에요'
        : chasing
        ? '${target.rank}위 ${target.ranker.name}까지 '
              '${_gapLabel(metric, gap, entry.ranker)} 남았어요'
        : '${target.rank}위와 ${_gapLabel(metric, gap, entry.ranker)} 차이로 앞서요';

    final line = Row(
      children: [
        Icon(
          chasing
              ? CupertinoIcons.arrow_up_right
              : CupertinoIcons.checkmark_seal_fill,
          size: 13,
          color: color,
        ),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );

    // 폰은 이미 카드 안 구분선 아래라서 면을 한 겹 더 깔면 답답하다
    if (!isDesktop) return line;

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: line,
    );
  }
}

/// 지난달 대비 순위 변동 — 올라갔으면 초록 위 화살표
class _DeltaBadge extends StatelessWidget {
  _DeltaBadge({
    required this.entry,
    required this.metric,
    this.compact = false,
  });

  final _Entry entry;
  final _Metric metric;

  /// 순위표 줄에서 쓸 때는 배경 없이 화살표만
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final last = entry.ranker.lastRank[metric.index];

    // 지난달에 없던 사람은 비교할 게 없다
    if (last == 0) {
      return compact ? SizedBox.shrink() : _box('NEW', AppColors.primary, null);
    }

    final delta = last - entry.rank;
    if (delta == 0) {
      return compact
          ? Icon(Icons.remove_rounded, size: 12, color: AppColors.gray300)
          : _box('-', AppColors.gray400, null);
    }

    final up = delta > 0;
    final color = up ? AppColors.success : AppColors.error;
    final icon = up
        ? CupertinoIcons.arrow_up_right
        : CupertinoIcons.arrow_down_right;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 1),
          Text(
            '${delta.abs()}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
    }
    return _box('${delta.abs()}', color, icon);
  }

  Widget _box(String text, Color color, IconData? icon) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          SizedBox(width: 2),
        ],
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 시상대
// ---------------------------------------------------------------------------

/// TOP 3 시상대 — 가운데가 1위, 받침대 높이로 등수를 보여준다
class _Podium extends StatelessWidget {
  _Podium({required this.top, required this.metric, this.big = false});

  final List<_Entry> top;
  final _Metric metric;

  /// 폰은 이 화면의 주인공이라 카드 없이 크게 세운다
  final bool big;

  /// 2위 · 1위 · 3위 순서로 세워야 1위가 가운데에 온다
  List<_Entry?> get _order => [
    top.length > 1 ? top[1] : null,
    top.isNotEmpty ? top[0] : null,
    top.length > 2 ? top[2] : null,
  ];

  @override
  Widget build(BuildContext context) {
    final steps = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in _order)
          Expanded(
            child: entry == null
                ? SizedBox()
                : _Step(entry: entry, metric: metric, big: big),
          ),
      ],
    );

    // 폰은 배경 위에 그대로 세운다 — 카드 테두리를 두르면 시상대가 작아 보인다
    if (big) return steps;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${metric.label} TOP 3', style: AppTextStyles.label),
          SizedBox(height: 16),
          steps,
        ],
      ),
    );
  }
}

/// 시상대 한 칸 — 왕관 · 아바타 · 이름 · 값 · 등수 받침대
class _Step extends StatelessWidget {
  _Step({required this.entry, required this.metric, this.big = false});

  final _Entry entry;
  final _Metric metric;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    // 등수가 높을수록 받침대가 높다
    final height = switch ((entry.rank, big)) {
      (1, true) => 104.0,
      (2, true) => 78.0,
      (_, true) => 64.0,
      (1, _) => 74.0,
      (2, _) => 56.0,
      _ => 44.0,
    };
    final avatar = big ? (first ? 72.0 : 56.0) : (first ? 52.0 : 42.0);
    final (light, dark) = _medal(entry.rank);

    return Column(
      children: [
        // 1위 머리 위 왕관 — 자리를 늘 잡아둬서 세 칸의 아래가 어긋나지 않는다
        if (big)
          SizedBox(
            height: 24,
            child: first
                ? Text('👑', style: TextStyle(fontSize: 20, height: 1.1))
                : null,
          ),
        // 1위만 메달 색 링을 두른다
        Container(
          padding: EdgeInsets.all(first ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: first ? Border.all(color: dark, width: 2.5) : null,
          ),
          child: Avatar(name: entry.ranker.name, size: avatar),
        ),
        SizedBox(height: big ? 10 : 8),
        Text(
          entry.ranker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(
            fontWeight: first ? FontWeight.w700 : FontWeight.w600,
            fontSize: big ? (first ? 16 : 15) : (first ? 15 : 14),
          ),
        ),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _format(metric, entry.value),
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(
              fontSize: big ? 13 : 12,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
        ),
        SizedBox(height: big ? 12 : 10),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: big ? 3 : 4),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: big ? 14 : 10),
          decoration: BoxDecoration(
            // 금·은·동 — 셋 다 색이 있어야 3위도 배경에서 떨어져 보인다
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [light, dark],
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(big ? 16 : 12),
            ),
          ),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: big ? (first ? 34 : 28) : (first ? 22 : 18),
              fontWeight: FontWeight.w800,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 순위표
// ---------------------------------------------------------------------------

/// 4위부터의 순위표 — 내 줄은 파란 면으로 눈에 띄게 둔다
class _RankList extends StatelessWidget {
  _RankList({
    required this.entries,
    required this.metric,
    required this.startsAt,
  });

  final List<_Entry> entries;
  final _Metric metric;

  /// 목록이 몇 위부터 시작하는지 (머리말에 쓴다)
  final int startsAt;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(12, isDesktop ? 16 : 6, 12, 6),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 폰은 시상대 바로 아래라 이어지는 흐름이 보여서 머리말을 뺀다
          if (isDesktop) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('$startsAt위부터', style: AppTextStyles.label),
            ),
            SizedBox(height: 6),
          ],
          for (var i = 0; i < entries.length; i++) ...[
            if (!isDesktop && i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Container(height: 1, color: AppColors.divider),
              ),
            _RankRow(entry: entries[i], metric: metric),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  _RankRow({required this.entry, required this.metric});

  final _Entry entry;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final mine = entry.ranker.isMe;

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.primary : AppColors.gray500,
              ),
            ),
          ),
          Avatar(name: entry.ranker.name, size: isDesktop ? 32 : 36),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.ranker.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 폰은 폭이 좁아 이름과 점수만 남긴다
                if (isDesktop) ...[
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.ranker.team,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _format(metric, entry.value),
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: mine ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isDesktop) ...[
                SizedBox(height: 1),
                Text(
                  entry.note,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Align(
              alignment: Alignment.centerRight,
              child: _DeltaBadge(entry: entry, metric: metric, compact: true),
            ),
          ),
        ],
      ),
    );
  }
}
