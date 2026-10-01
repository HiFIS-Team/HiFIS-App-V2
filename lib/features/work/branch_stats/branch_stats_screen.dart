import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/staff/staff_api.dart' show Branch;
import '../../../core/api/work/branch_stats_api.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/layout.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/nav/phone_scaffold.dart';

/// 지점 통계 — 점장이 개인 업무로 적어 내는 숫자를 그래프로 (2026-09-30 대표 요청)
///
/// 점장은 매일 `기존·신규·일권` 칸에 **이번 달 들어 지금까지의 누적**을 적는다
/// (9/11 기존 38 → 9/30 기존 94). 그래서 여기서는
///
/// | 보기 | 값 |
/// |---|---|
/// | 일 | 그날 늘어난 수 — 전날 누적과의 차이 (그달 첫 기록은 그 값 그대로) |
/// | 주 | 그 주에 늘어난 수의 합 |
/// | 월 | 그달 마지막 누적 |
/// | 년 | 그해 달마다 마지막 누적의 합 |
/// | 같은 날 비교 | 이번 달 D일까지의 누적 ↔ 지난달 D일까지의 누적 |
///
/// **전 직원이 본다.** 대표·관리자는 **지점 카드부터** 고르고, 나머지는 자기
/// 지점으로 바로 들어간다 (서버가 고정).
class BranchStatsScreen extends StatefulWidget {
  const BranchStatsScreen({super.key, this.branchId});

  final String? branchId;

  @override
  State<BranchStatsScreen> createState() => _BranchStatsScreenState();
}

enum _Unit {
  day('일'),
  week('주'),
  month('월'),
  year('년');

  const _Unit(this.label);
  final String label;
}

/// 칸마다 선 색 — 서버가 주는 칸 차례(기존·신규·일권)대로 붙는다
List<Color> get _lineColors => [
  AppColors.primary,
  AppColors.success,
  AppColors.warning,
  AppColors.violet,
  AppColors.pink,
  AppColors.teal,
];

Color _colorOf(int i) => _lineColors[i % _lineColors.length];

/// 지점 카드에 붙는 이름 — `화순` → `피트니스스타 화순점`
String _branchTitle(String name) =>
    '피트니스스타 ${name.endsWith('점') ? name : '$name점'}';

class _BranchStatsScreenState extends State<BranchStatsScreen>
    with SkeletonDelay<BranchStatsScreen> {
  /// 대표·관리자가 지점을 안 고르고 들어왔다 — 지점 카드부터 (2026-10-01 대표 요청)
  bool get _picking =>
      (currentUser?.role.boss ?? false) && widget.branchId == null;

  BranchStats? _stats;

  /// 지점 카드마다 받아 둔 통계 — 오른쪽 숫자에 쓴다
  List<(Branch, BranchStats?)> _branches = const [];

  _Unit _unit = _Unit.day;

  /// 같은 날 비교의 기준일 — 기본은 오늘
  DateTime _compareDay = DateUtils.dateOnly(DateTime.now());

  /// 그래프가 보는 달 (일·주) — 월 단위는 이 달의 **해**를 본다. 년은 안 쓴다
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);

  /// 기간을 옮긴다 — 일·주는 한 달씩, 월은 한 해씩
  void _movePeriod(int delta) => setState(() {
    _period = _unit == _Unit.month
        ? DateTime(_period.year + delta, _period.month)
        : DateTime(_period.year, _period.month + delta);
  });

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(beginLoad);
    try {
      if (_picking) {
        final directory = StaffDirectory.instance;
        final branches =
            [
              for (final b in directory.branches)
                if (!b.isHq) b,
            ]..sort(
              (a, b) => directory.branchRank(a.id) - directory.branchRank(b.id),
            );
        final stats = await Future.wait([
          for (final b in branches)
            BranchStatsApi.get(
              branchId: b.id,
            ).then<BranchStats?>((s) => s, onError: (_) => null),
        ]);
        if (!mounted) return;
        setState(() {
          _branches = [
            for (var i = 0; i < branches.length; i++) (branches[i], stats[i]),
          ];
          endLoad();
        });
        return;
      }
      final stats = await BranchStatsApi.get(branchId: widget.branchId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      20,
      PhoneDetailScaffold.topPadding,
      20,
      bottomBarInset(context),
    );
    if (_picking) {
      return PhoneDetailScaffold(
        title: '지점 통계',
        child: ListView(
          padding: padding,
          children: [
            if (showSkeleton)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppDecorations.card(),
                child: SkeletonRows(rows: 2, avatar: 0),
              )
            else if (_branches.isEmpty)
              EmptyCard(icon: Icons.store_rounded, text: '지점이 없어요')
            else
              for (var i = 0; i < _branches.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _BranchCard(
                  branch: _branches[i].$1,
                  stats: _branches[i].$2,
                  onTap: () => showFullPage<void>(
                    context,
                    (_) => BranchStatsScreen(branchId: _branches[i].$1.id),
                  ),
                ),
              ],
          ],
        ),
      );
    }

    final stats = _stats;
    final branchName = StaffDirectory.instance.branchName(
      widget.branchId ?? currentUser?.branchId,
    );
    return PhoneDetailScaffold(
      title: branchName.isEmpty ? '지점 통계' : _branchTitle(branchName),
      child: ListView(
        padding: padding,
        children: [
          if (showSkeleton || stats == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(),
              child: SkeletonRows(rows: 4, avatar: 0),
            )
          else if (stats.fields.isEmpty)
            EmptyCard(
              icon: Icons.bar_chart_rounded,
              text: '아직 점장님이 적어 낸 숫자가 없어요',
            )
          else ...[
            _CompareCard(
              stats: stats,
              day: _compareDay,
              onMove: (delta) => setState(
                () => _compareDay = _compareDay.add(Duration(days: delta)),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedTabs(
              labels: [for (final u in _Unit.values) u.label],
              selected: _unit.index,
              onSelect: (i) => setState(() => _unit = _Unit.values[i]),
            ),
            const SizedBox(height: 12),
            // 그래프를 보지 않아도 되게 **숫자로** 먼저 (2026-09-30 대표 요청)
            _SummaryCard(stats: stats, unit: _unit, period: _period),
            const SizedBox(height: 12),
            _ChartCard(
              unit: _unit,
              stats: stats,
              period: _period,
              onMove: _movePeriod,
            ),
          ],
        ],
      ),
    );
  }
}

/// 지점 카드 — 이름과 **점장이 마지막으로 적은 숫자** (2026-10-01 대표 요청)
class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.stats,
    required this.onTap,
  });

  final Branch branch;
  final BranchStats? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = stats?.days.lastOrNull;
    final fields = stats?.fields ?? const <String>[];
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _branchTitle(branch.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? '아직 적은 숫자가 없어요'
                        : '${last.date.month}월 ${last.date.day}일까지 누적',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (last != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < fields.length; i++)
                    if (last.values[fields[i]] case final v?)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${fields[i]} ',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: _num(v),
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _colorOf(i),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 셈 ──

/// 그달 [day] 까지의 누적 — 그날이나 그 전 가장 가까운 기록 (없으면 null)
double? _cumulativeAt(BranchStats stats, String field, DateTime day) {
  double? found;
  for (final d in stats.days) {
    if (d.date.year != day.year || d.date.month != day.month) continue;
    if (d.date.isAfter(day)) break;
    final v = d.values[field];
    if (v != null) found = v;
  }
  return found;
}

/// 날마다 늘어난 수 — 같은 달 안에서 전 기록과의 차이
List<(DateTime, double)> _daily(BranchStats stats, String field) {
  final out = <(DateTime, double)>[];
  DateTime? prevDay;
  double? prev;
  for (final d in stats.days) {
    final v = d.values[field];
    if (v == null) continue;
    final sameMonth =
        prevDay != null &&
        prevDay.year == d.date.year &&
        prevDay.month == d.date.month;
    out.add((d.date, sameMonth ? v - prev! : v));
    prevDay = d.date;
    prev = v;
  }
  return out;
}

/// 날짜 → 그날 늘어난 수 (같은 달 안에서 전 기록과의 차이)
Map<DateTime, double> _dailyMap(BranchStats stats, String field) => {
  for (final (d, v) in _daily(stats, field)) DateUtils.dateOnly(d): v,
};

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 같은 날 비교 — 이번 달 D일까지 ↔ 지난달 D일까지 (칸마다)
class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.stats,
    required this.day,
    required this.onMove,
  });

  final BranchStats stats;
  final DateTime day;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    // 지난달 같은 날 — 그 달에 없는 날(31일 등)은 말일로 당긴다
    final lastMonthEnd = DateTime(day.year, day.month, 0);
    final prevDay = DateTime(
      day.year,
      day.month - 1,
      day.day > lastMonthEnd.day ? lastMonthEnd.day : day.day,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('지난달 같은 날과 비교', style: AppTextStyles.label)),
              _Arrow(
                icon: CupertinoIcons.chevron_left,
                onTap: () => onMove(-1),
              ),
              Text(
                '${day.month}월 ${day.day}일',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _Arrow(
                icon: CupertinoIcons.chevron_right,
                onTap: day.isBefore(today) ? () => onMove(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${day.month}월 ${day.day}일까지 누적 vs ${prevDay.month}월 ${prevDay.day}일까지 누적',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < stats.fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _CompareRow(
              field: stats.fields[i],
              now: _cumulativeAt(stats, stats.fields[i], day),
              before: _cumulativeAt(stats, stats.fields[i], prevDay),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.field,
    required this.now,
    required this.before,
  });

  final String field;
  final double? now;
  final double? before;

  @override
  Widget build(BuildContext context) {
    final now = this.now;
    final before = this.before;
    final diff = (now != null && before != null) ? now - before : null;
    final pct = (diff != null && before != null && before != 0)
        ? diff / before * 100
        : null;
    final color = diff == null || diff == 0
        ? AppColors.textTertiary
        : diff > 0
        ? AppColors.success
        : AppColors.error;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            field,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: now == null ? '-' : _num(now),
                  style: AppTextStyles.title3,
                ),
                TextSpan(
                  text: '  지난달 ${before == null ? '-' : _num(before)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
        Text(
          diff == null
              ? '-'
              : '${diff > 0 ? '+' : ''}${_num(diff)}'
                    '${pct == null ? '' : ' (${pct > 0 ? '+' : ''}${pct.round()}%)'}',
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap ?? () {},
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        icon,
        size: 14,
        color: onTap == null ? AppColors.gray300 : AppColors.textSecondary,
      ),
    ),
  );
}

/// 그래프 한 벌 — 칸마다 이름과 **칸(기존·신규·일권)별** 값 (기록이 없으면 null)
class _Series {
  const _Series({
    required this.labels,
    required this.titles,
    required this.values,
  });

  /// 아래 축 글자 — `1` · `1주` · `1월` · `2026`
  final List<String> labels;

  /// 말풍선 머리 — `9월 29일` · `9월 3주 (15~21일)` · `2026년 9월` · `2026년`
  final List<String> titles;

  /// `values[칸 차례][자리]`
  final List<List<double?>> values;
}

/// 달마다 마지막 누적 — `{(해, 달): 값}`
Map<(int, int), double> _monthTotals(BranchStats stats, String field) {
  final last = <(int, int), double>{};
  for (final d in stats.days) {
    final v = d.values[field];
    if (v != null) last[(d.date.year, d.date.month)] = v;
  }
  return last;
}

/// 달력 기준으로 칸을 만든다 (2026-09-30·10-01 대표 요청)
///
/// | 단위 | 칸 |
/// |---|---|
/// | 일 | 그 달 1일 ~ 말일 — 날마다 늘어난 수 |
/// | 주 | 그 달의 월~일 주 — 그 주에 늘어난 수 (달 밖의 날은 안 센다) |
/// | 월 | 그 해 1월 ~ 12월 — 달마다 마지막 누적 |
/// | 년 | 기록이 있는 첫 해 ~ 올해 — 달마다 마지막 누적을 더한 것 |
_Series _series(BranchStats stats, _Unit unit, DateTime period) {
  final y = period.year;
  final m = period.month;
  final days = DateTime(y, m + 1, 0).day;
  final fields = stats.fields;
  switch (unit) {
    case _Unit.day:
      return _Series(
        labels: [for (var d = 1; d <= days; d++) '$d'],
        titles: [for (var d = 1; d <= days; d++) '$m월 $d일'],
        values: [
          for (final f in fields)
            () {
              final daily = _dailyMap(stats, f);
              return [for (var d = 1; d <= days; d++) daily[DateTime(y, m, d)]];
            }(),
        ],
      );
    case _Unit.week:
      // 1일이 든 주부터 월요일 단위로 끊는다 — 달 밖의 날은 안 센다
      final weeks = <List<DateTime>>[];
      for (var d = 1; d <= days; d++) {
        final day = DateTime(y, m, d);
        if (weeks.isEmpty || day.weekday == DateTime.monday) weeks.add([]);
        weeks.last.add(day);
      }
      return _Series(
        labels: [for (var i = 0; i < weeks.length; i++) '${i + 1}주'],
        titles: [
          for (var i = 0; i < weeks.length; i++)
            '$m월 ${i + 1}주 (${weeks[i].first.day}~${weeks[i].last.day}일)',
        ],
        values: [
          for (final f in fields)
            () {
              final daily = _dailyMap(stats, f);
              return [
                for (final w in weeks)
                  w.any(daily.containsKey)
                      ? w.fold<double>(0, (sum, d) => sum + (daily[d] ?? 0))
                      : null,
              ];
            }(),
        ],
      );
    case _Unit.month:
      return _Series(
        labels: [for (var i = 1; i <= 12; i++) '$i월'],
        titles: [for (var i = 1; i <= 12; i++) '$y년 $i월'],
        values: [
          for (final f in fields)
            () {
              final totals = _monthTotals(stats, f);
              return [for (var i = 1; i <= 12; i++) totals[(y, i)]];
            }(),
        ],
      );
    case _Unit.year:
      final now = DateTime.now().year;
      final first = stats.days.isEmpty ? now : stats.days.first.date.year;
      final years = [for (var yy = first; yy <= now; yy++) yy];
      return _Series(
        labels: [for (final yy in years) '$yy'],
        titles: [for (final yy in years) '$yy년'],
        values: [
          for (final f in fields)
            () {
              final totals = _monthTotals(stats, f);
              return [
                for (final yy in years)
                  totals.keys.any((k) => k.$1 == yy)
                      ? totals.entries
                            .where((e) => e.key.$1 == yy)
                            .fold<double>(0, (sum, e) => sum + e.value)
                      : null,
              ];
            }(),
        ],
      );
  }
}

/// 그래프 위 숫자 카드 — 칸마다 한 줄 (합계 · 평균 · 최고)
///
/// | 단위 | 합계 칸 |
/// |---|---|
/// | 일·주 | 그 달 마지막 누적 (점장이 적은 숫자 그대로) |
/// | 월 | 그해 달마다 누적의 합 |
/// | 년 | 기록 전체의 합 |
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stats,
    required this.unit,
    required this.period,
  });

  final BranchStats stats;
  final _Unit unit;
  final DateTime period;

  @override
  Widget build(BuildContext context) {
    final series = _series(stats, unit, period);
    final (totalLabel, avgLabel, bestLabel) = switch (unit) {
      _Unit.day => ('${period.month}월 누적', '하루 평균', '가장 많이 는 날'),
      _Unit.week => ('${period.month}월 누적', '주 평균', '가장 많이 는 주'),
      _Unit.month => ('${period.year}년 합계', '월 평균', '가장 많은 달'),
      _Unit.year => ('전체 합계', '해 평균', '가장 많은 해'),
    };
    final header = AppTextStyles.caption.copyWith(fontSize: 11);

    List<Widget> row(int i) {
      final field = stats.fields[i];
      final vals = series.values[i];
      final filled = [
        for (var k = 0; k < vals.length; k++)
          if (vals[k] != null) (k, vals[k]!),
      ];
      final sum = filled.fold(0.0, (s, e) => s + e.$2);
      final avg = filled.isEmpty ? null : sum / filled.length;
      final best = filled.isEmpty
          ? null
          : filled.reduce((a, b) => b.$2 > a.$2 ? b : a);
      // 일·주는 '늘어난 수' 를 더하지 않고 점장이 적은 누적을 그대로 쓴다
      final total = switch (unit) {
        _Unit.day || _Unit.week => () {
          double? last;
          for (
            var d = DateTime(period.year, period.month + 1, 0).day;
            d >= 1;
            d--
          ) {
            last = _cumulativeAt(
              stats,
              field,
              DateTime(period.year, period.month, d),
            );
            if (last != null) break;
          }
          return last;
        }(),
        _ => filled.isEmpty ? null : sum,
      };
      final plus = unit == _Unit.day || unit == _Unit.week ? '+' : '';
      return [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _colorOf(i),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              field,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Text(
          total == null ? '-' : _num(total),
          textAlign: TextAlign.right,
          style: AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.w800,
            color: _colorOf(i),
          ),
        ),
        Text(
          avg == null
              ? '-'
              : '$plus${_num(double.parse(avg.toStringAsFixed(1)))}',
          textAlign: TextAlign.right,
          style: AppTextStyles.body2,
        ),
        Text(
          best == null ? '-' : '$plus${_num(best.$2)}',
          textAlign: TextAlign.right,
          style: AppTextStyles.body2,
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: AppDecorations.card(),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1.2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox.shrink(),
              Text(totalLabel, textAlign: TextAlign.right, style: header),
              Text(avgLabel, textAlign: TextAlign.right, style: header),
              Text(bestLabel, textAlign: TextAlign.right, style: header),
            ],
          ),
          for (var i = 0; i < stats.fields.length; i++)
            TableRow(
              children: [
                for (final cell in row(i))
                  Padding(padding: const EdgeInsets.only(top: 10), child: cell),
              ],
            ),
        ],
      ),
    );
  }
}

/// 선 그래프 — 칸(기존·신규·일권)마다 **색이 다른 선**, 왼쪽에 눈금
/// (2026-10-01 대표 요청)
///
/// 기록이 없는 자리(일요일 등)는 **점을 안 찍고 건너뛴다.** 누르거나 끌면
/// 그 자리의 칸별 값이 말풍선으로 뜬다.
class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.unit,
    required this.stats,
    required this.period,
    required this.onMove,
  });

  final _Unit unit;
  final BranchStats stats;
  final DateTime period;
  final ValueChanged<int> onMove;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  /// 누르고 있는 자리 — 없으면 말풍선을 안 띄운다
  int? _picked;

  @override
  void didUpdateWidget(covariant _ChartCard old) {
    super.didUpdateWidget(old);
    if (old.unit != widget.unit || old.period != widget.period) _picked = null;
  }

  void _pick(Offset local, double width, int count) {
    final inner = width - _LineChart.padLeft - _LineChart.padRight;
    final step = count <= 1 ? 0.0 : inner / (count - 1);
    final i = step == 0
        ? 0
        : ((local.dx - _LineChart.padLeft) / step).round().clamp(0, count - 1);
    if (i != _picked) setState(() => _picked = i);
  }

  @override
  Widget build(BuildContext context) {
    final series = _series(widget.stats, widget.unit, widget.period);
    final count = series.labels.length;
    final hasAny = series.values.any((v) => v.any((x) => x != null));
    final title = switch (widget.unit) {
      _Unit.day => '날마다 늘어난 수',
      _Unit.week => '주마다 늘어난 수',
      _Unit.month => '달마다 합계',
      _Unit.year => '해마다 합계',
    };
    final now = DateTime.now();
    final atLatest = widget.unit == _Unit.month
        ? widget.period.year >= now.year
        : !DateTime(
            widget.period.year,
            widget.period.month,
          ).isBefore(DateTime(now.year, now.month));
    final periodLabel = switch (widget.unit) {
      _Unit.month => '${widget.period.year}년',
      _Unit.year => '',
      _ => '${widget.period.year}년 ${widget.period.month}월',
    };
    final picked = _picked;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(title, style: AppTextStyles.label),
                ),
              ),
              // 년은 한 화면에 다 보여서 옮길 것이 없다
              if (widget.unit != _Unit.year) ...[
                _Arrow(
                  icon: CupertinoIcons.chevron_left,
                  onTap: () => widget.onMove(-1),
                ),
                Text(
                  periodLabel,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _Arrow(
                  icon: CupertinoIcons.chevron_right,
                  onTap: atLatest ? null : () => widget.onMove(1),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (!hasAny)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text('이 기간에는 기록이 없어요', style: AppTextStyles.caption),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pick(d.localPosition, box.maxWidth, count),
                onHorizontalDragUpdate: (d) =>
                    _pick(d.localPosition, box.maxWidth, count),
                child: SizedBox(
                  width: box.maxWidth,
                  height: 240,
                  child: CustomPaint(
                    painter: _LineChart(
                      series: series,
                      colors: [
                        for (var i = 0; i < series.values.length; i++)
                          _colorOf(i),
                      ],
                      fields: widget.stats.fields,
                      picked: picked,
                      labelEvery: switch (widget.unit) {
                        _Unit.day => 7,
                        _Unit.month => 2,
                        _ => 1,
                      },
                      grid: AppColors.gray100,
                      guide: AppColors.gray300,
                      text: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                      bubble: AppColors.gray900,
                      surface: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (var i = 0; i < widget.stats.fields.length; i++)
                _Legend(color: _colorOf(i), label: widget.stats.fields[i]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
    ],
  );
}

/// 눈금 간격 — 1·2·5 × 10ⁿ 중에서 [max] 를 네 칸 남짓으로 나누는 값
double _niceStep(double max) {
  if (max <= 0) return 1;
  final raw = max / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 5, 10]) {
    if (raw <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// 선 그래프 그리기 — 칸 자리는 고정, 값이 있는 자리만 잇는다
class _LineChart extends CustomPainter {
  _LineChart({
    required this.series,
    required this.colors,
    required this.fields,
    required this.picked,
    required this.labelEvery,
    required this.grid,
    required this.guide,
    required this.text,
    required this.bubble,
    required this.surface,
  });

  final _Series series;
  final List<Color> colors;
  final List<String> fields;
  final int? picked;

  /// 아래 글자를 몇 칸마다 적나 — 마지막 칸은 늘 적는다
  final int labelEvery;
  final Color grid;
  final Color guide;
  final TextStyle text;
  final Color bubble;
  final Color surface;

  /// 왼쪽 눈금 글자 자리 · 오른쪽 여백
  static const padLeft = 34.0;
  static const padRight = 8.0;
  static const _labelH = 22.0;
  static const _top = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - _labelH;
    final all = [for (final v in series.values) ...v.whereType<double>()];
    final maxV = all.fold(0.0, (m, v) => v > m ? v : m);
    final minV = all.fold(0.0, (m, v) => v < m ? v : m);
    final step = _niceStep(math.max(maxV, -minV));
    final top = (maxV / step).ceil() * step;
    final bottom = (minV / step).floor() * step;
    final span = (top - bottom) == 0 ? step : (top - bottom);
    final n = series.labels.length;
    final inner = size.width - padLeft - padRight;
    final dx = n <= 1 ? 0.0 : inner / (n - 1);

    double x(int i) => n <= 1 ? padLeft + inner / 2 : padLeft + dx * i;
    double y(double v) =>
        _top + (chartH - _top - 6) * (1 - (v - bottom) / span);

    TextPainter label(String s, [TextStyle? st]) => TextPainter(
      text: TextSpan(text: s, style: st ?? text),
      textDirection: TextDirection.ltr,
    )..layout();

    // ── 왼쪽 눈금과 가로선 ──
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = bottom; v <= top + step / 2; v += step) {
      final gy = y(v);
      canvas.drawLine(
        Offset(padLeft, gy),
        Offset(size.width - padRight, gy),
        gridPaint,
      );
      final tp = label(_num(v));
      tp.paint(canvas, Offset(padLeft - 6 - tp.width, gy - tp.height / 2));
    }

    /// 값이 있는 점만 부드럽게 잇는다 (빈 자리는 건너뛴다)
    Path? curve(List<double?> vs) {
      Offset? prev;
      Path? path;
      for (var i = 0; i < vs.length; i++) {
        final v = vs[i];
        if (v == null) continue;
        final p = Offset(x(i), y(v));
        if (prev == null) {
          path = Path()..moveTo(p.dx, p.dy);
        } else {
          final mid = (prev.dx + p.dx) / 2;
          path!.cubicTo(mid, prev.dy, mid, p.dy, p.dx, p.dy);
        }
        prev = p;
      }
      return path;
    }

    // 고른 자리 — 세로 안내선 (선보다 먼저 깔린다)
    final pickedAt = picked?.clamp(0, n - 1);
    if (pickedAt != null) {
      canvas.drawLine(
        Offset(x(pickedAt), _top),
        Offset(x(pickedAt), chartH - 6),
        Paint()
          ..color = guide
          ..strokeWidth = 1,
      );
    }

    // ── 칸마다 선 ──
    for (var f = 0; f < series.values.length; f++) {
      final vs = series.values[f];
      final color = colors[f];
      final path = curve(vs);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < n; i++) {
        final v = vs[i];
        if (v == null) continue;
        final big = i == pickedAt;
        if (big) {
          canvas.drawCircle(Offset(x(i), y(v)), 6.5, Paint()..color = surface);
        }
        canvas.drawCircle(
          Offset(x(i), y(v)),
          big ? 4.5 : 2.4,
          Paint()..color = color,
        );
      }
    }

    if (pickedAt != null) _bubble(canvas, size, x(pickedAt), pickedAt);

    // ── 아래 글자 — [labelEvery] 칸마다 + 마지막 칸 (몰리지 않게) ──
    for (var i = 0; i < n; i++) {
      final last = i == n - 1;
      if (i % labelEvery != 0 && !last) continue;
      if (!last && n - 1 - i < labelEvery / 2) continue;
      final tp = label(series.labels[i]);
      final lx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, chartH + 4));
    }
  }

  /// 누른 자리 위에 말풍선 — 그 자리의 칸별 값
  void _bubble(Canvas canvas, Size size, double px, int at) {
    TextPainter tp(String t, TextStyle st) => TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
    )..layout();
    final head = tp(
      series.titles[at],
      text.copyWith(color: surface.withValues(alpha: 0.8)),
    );
    final rows = [
      for (var f = 0; f < fields.length; f++)
        (
          colors[f],
          tp(
            '${fields[f]} ${series.values[f][at] == null ? '-' : _num(series.values[f][at]!)}',
            text.copyWith(
              color: surface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];
    const padH = 12.0, padV = 9.0, gap = 3.0, dot = 8.0;
    final w =
        [
          head.width,
          for (final r in rows) r.$2.width + dot + 6,
        ].fold(0.0, (m, v) => v > m ? v : m) +
        padH * 2;
    final h =
        head.height +
        rows.fold(0.0, (s, r) => s + r.$2.height + gap) +
        padV * 2;
    // 손가락에 안 가리게 위쪽에 띄우고, 오른쪽 끝이면 왼쪽으로 붙인다
    final left = (px + 10 + w > size.width) ? px - 10 - w : px + 10;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left.clamp(0.0, size.width - w), _top, w, h),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = bubble);
    var ty = rect.top + padV;
    head.paint(canvas, Offset(rect.left + padH, ty));
    ty += head.height + gap;
    for (final (color, line) in rows) {
      canvas.drawCircle(
        Offset(rect.left + padH + dot / 2, ty + line.height / 2),
        dot / 2,
        Paint()..color = color,
      );
      line.paint(canvas, Offset(rect.left + padH + dot + 6, ty));
      ty += line.height + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChart old) =>
      old.series != series || old.picked != picked;
}
