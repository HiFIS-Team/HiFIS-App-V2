import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/avatar.dart';
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

  late String _branch = _rankers.firstWhere((r) => r.isMe).branch;

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
    final podium = _Podium(top: top, metric: _metric);

    // 다른 지점을 보고 있으면 내 순위가 없다 — 그때는 시상대만 넓게 쓴다
    final mine = entries.where((e) => e.ranker.isMe).toList();
    final myCard = mine.isEmpty
        ? null
        : _MyRankCard(
            entry: mine.first,
            metric: _metric,
            total: entries.length,
          );

    return [
      // 데스크톱은 폭이 남아 내 순위와 시상대를 나란히 놓는다
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
        myCard,
        SizedBox(height: 12),
        podium,
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
            Row(
              children: [
                Text('랭킹', style: AppTextStyles.title1),
                SizedBox(width: 10),
                Text(
                  _month,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Spacer(),
                _BranchPicker(
                  selected: _branch,
                  onSelect: (branch) => setState(() => _branch = branch),
                ),
              ],
            ),
            SizedBox(height: 20),
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

/// 폰 항목 탭 — 다섯 칸을 세그먼트에 욱여넣으면 글자가 뭉개져서 칩을 옆으로 민다
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < _Metric.values.length; i++) ...[
            if (i > 0) SizedBox(width: 8),
            Pressable(
              onTap: () => onSelect(i),
              scale: 0.96,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? AppColors.primary : AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _Metric.values[i].label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == selected ? Colors.white : AppColors.gray600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
  _MyRankCard({required this.entry, required this.metric, required this.total});

  final _Entry entry;
  final _Metric metric;

  /// 이 지점에서 순위에 오른 사람 수 (상위 몇 %인지 계산에 쓴다)
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = (entry.rank * 100 / total).round();

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
            ],
          ),
        ],
      ),
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
  _Podium({required this.top, required this.metric});

  final List<_Entry> top;
  final _Metric metric;

  /// 2위 · 1위 · 3위 순서로 세워야 1위가 가운데에 온다
  List<_Entry?> get _order => [
    top.length > 1 ? top[1] : null,
    top.isNotEmpty ? top[0] : null,
    top.length > 2 ? top[2] : null,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${metric.label} TOP 3', style: AppTextStyles.label),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in _order)
                Expanded(
                  child: entry == null
                      ? SizedBox()
                      : _Step(entry: entry, metric: metric),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 시상대 한 칸 — 아바타 · 이름 · 값 · 등수 받침대
class _Step extends StatelessWidget {
  _Step({required this.entry, required this.metric});

  final _Entry entry;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    // 등수가 높을수록 받침대가 높다
    final height = switch (entry.rank) {
      1 => 74.0,
      2 => 56.0,
      _ => 44.0,
    };

    return Column(
      children: [
        Avatar(name: entry.ranker.name, size: first ? 52 : 42),
        SizedBox(height: 8),
        Text(
          entry.ranker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(
            fontWeight: first ? FontWeight.w700 : FontWeight.w600,
            fontSize: first ? 15 : 14,
          ),
        ),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _format(metric, entry.value),
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: first ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            // 1위만 브랜드 색으로, 나머지는 회색 면 (포인트 컬러 하나 원칙)
            gradient: first
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  )
                : null,
            color: first ? null : AppColors.gray50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: first ? 22 : 18,
              fontWeight: FontWeight.w800,
              height: 1,
              color: first ? Colors.white : AppColors.gray400,
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
      padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('$startsAt위부터', style: AppTextStyles.label),
          ),
          SizedBox(height: 6),
          for (final entry in entries) _RankRow(entry: entry, metric: metric),
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
          Avatar(name: entry.ranker.name, size: 32),
          SizedBox(width: 10),
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
              SizedBox(height: 1),
              Text(
                entry.note,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
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
