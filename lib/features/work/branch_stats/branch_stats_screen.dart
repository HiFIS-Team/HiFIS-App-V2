import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/branch_stats_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/layout.dart';
import '../../../core/util/skeleton_delay.dart';
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
/// | 같은 날 비교 | 이번 달 D일까지의 누적 ↔ 지난달 D일까지의 누적 |
///
/// **전 직원이 본다.** 대표·관리자는 고른 지점, 나머지는 자기 지점이다 (서버가 고정).
class BranchStatsScreen extends StatefulWidget {
  const BranchStatsScreen({super.key, this.branchId});

  final String? branchId;

  @override
  State<BranchStatsScreen> createState() => _BranchStatsScreenState();
}

enum _Unit { day, week, month }

class _BranchStatsScreenState extends State<BranchStatsScreen>
    with SkeletonDelay<BranchStatsScreen> {
  BranchStats? _stats;
  int _field = 0;
  _Unit _unit = _Unit.day;

  /// 같은 날 비교의 기준일 — 기본은 오늘
  DateTime _compareDay = DateUtils.dateOnly(DateTime.now());

  /// 그래프가 보는 달 (일·주) — 월 단위는 이 달의 **해**를 본다
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
    final stats = _stats;
    return PhoneDetailScaffold(
      title: '지점 통계',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
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
              labels: stats.fields,
              selected: _field.clamp(0, stats.fields.length - 1),
              onSelect: (i) => setState(() => _field = i),
            ),
            const SizedBox(height: 12),
            SegmentedTabs(
              labels: const ['일', '주', '월'],
              selected: _unit.index,
              onSelect: (i) => setState(() => _unit = _Unit.values[i]),
            ),
            const SizedBox(height: 12),
            // 그래프를 보지 않아도 되게 **숫자로** 먼저 (2026-09-30 대표 요청)
            _SummaryCard(
              series: _series(
                stats,
                stats.fields[_field.clamp(0, stats.fields.length - 1)],
                _unit,
                _period,
              ),
              stats: stats,
              field: stats.fields[_field.clamp(0, stats.fields.length - 1)],
              unit: _unit,
              period: _period,
            ),
            const SizedBox(height: 12),
            _ChartCard(
              field: stats.fields[_field.clamp(0, stats.fields.length - 1)],
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

/// 그래프 한 벌 — 칸마다 이름과 값 (기록이 없는 칸은 null)
class _Series {
  const _Series({
    required this.labels,
    required this.values,
    required this.titles,
    required this.written,
    this.compare,
  });

  /// 아래 축 글자 — `1` · `1주` · `1월`
  final List<String> labels;
  final List<double?> values;

  /// 고른 점을 크게 보일 때 붙이는 이름 — `9월 29일` · `9월 3주` · `2026년 9월`
  final List<String> titles;

  /// 겹쳐 그릴 지난달 선 (일 단위만)
  final List<double?>? compare;

  /// 그때 **점장이 적은 숫자** (누적) — 말풍선이 보여준다.
  /// 일은 그날 적은 값, 주는 그 주 마지막 값, 월은 그 달 마지막 값
  final List<double?> written;
}

/// 날짜 → 그날 적은 누적 값
Map<DateTime, double> _writtenMap(BranchStats stats, String field) => {
  for (final d in stats.days) DateUtils.dateOnly(d.date): ?d.values[field],
};

/// 날짜 → 그날 늘어난 수 (같은 달 안에서 전 기록과의 차이)
Map<DateTime, double> _dailyMap(BranchStats stats, String field) => {
  for (final (d, v) in _daily(stats, field)) DateUtils.dateOnly(d): v,
};

/// 달력 기준으로 칸을 만든다 (2026-09-30 대표 요청)
///
/// | 단위 | 칸 |
/// |---|---|
/// | 일 | 그 달 1일 ~ 말일 — 날마다 늘어난 수. 지난달 같은 날 선을 겹친다 |
/// | 주 | 그 달의 월~일 주 — 그 주에 늘어난 수 (달 밖의 날은 안 센다) |
/// | 월 | 그 해 1월 ~ 12월 — 달마다 마지막 누적 |
_Series _series(BranchStats stats, String field, _Unit unit, DateTime period) {
  final daily = _dailyMap(stats, field);
  final written = _writtenMap(stats, field);
  final y = period.year;
  final m = period.month;
  final days = DateTime(y, m + 1, 0).day;
  switch (unit) {
    case _Unit.day:
      final prevDays = DateTime(y, m, 0).day;
      return _Series(
        labels: [for (var d = 1; d <= days; d++) '$d'],
        values: [for (var d = 1; d <= days; d++) daily[DateTime(y, m, d)]],
        titles: [for (var d = 1; d <= days; d++) '$m월 $d일'],
        written: [for (var d = 1; d <= days; d++) written[DateTime(y, m, d)]],
        compare: [
          for (var d = 1; d <= days; d++)
            d <= prevDays ? daily[DateTime(y, m - 1, d)] : null,
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
        values: [
          for (final w in weeks)
            w.any(daily.containsKey)
                ? w.fold<double>(0, (sum, d) => sum + (daily[d] ?? 0))
                : null,
        ],
        titles: [
          for (var i = 0; i < weeks.length; i++)
            '$m월 ${i + 1}주 (${weeks[i].first.day}~${weeks[i].last.day}일)',
        ],
        written: [
          for (final w in weeks)
            [for (final d in w) written[d]].whereType<double>().lastOrNull,
        ],
      );
    case _Unit.month:
      final last = <int, double>{};
      for (final d in stats.days) {
        final v = d.values[field];
        if (v != null && d.date.year == y) last[d.date.month] = v;
      }
      return _Series(
        labels: [for (var i = 1; i <= 12; i++) '$i월'],
        values: [for (var i = 1; i <= 12; i++) last[i]],
        titles: [for (var i = 1; i <= 12; i++) '$y년 $i월'],
        written: [for (var i = 1; i <= 12; i++) last[i]],
      );
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ── 조각 ──

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

/// 그래프 위 숫자 카드 — 고른 기간을 숫자 넷으로
///
/// | 일·주 (한 달) | 월 (한 해) |
/// |---|---|
/// | 이번 달 누적 (마지막으로 적은 값) | 올해 합계 |
/// | 지난달 같은 날까지 · 차이 | 이번 해 월 평균 |
/// | 하루(주) 평균 늘어난 수 | 가장 많은 달 |
/// | 가장 많이 늘어난 날(주) | 기록한 달 수 |
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.series,
    required this.stats,
    required this.field,
    required this.unit,
    required this.period,
  });

  final _Series series;
  final BranchStats stats;
  final String field;
  final _Unit unit;
  final DateTime period;

  @override
  Widget build(BuildContext context) {
    final vals = series.values;
    final filled = [
      for (var i = 0; i < vals.length; i++)
        if (vals[i] != null) (i, vals[i]!),
    ];
    final avg = filled.isEmpty
        ? null
        : filled.fold(0.0, (s, e) => s + e.$2) / filled.length;
    final best = filled.isEmpty
        ? null
        : filled.reduce((a, b) => b.$2 > a.$2 ? b : a);

    final List<(String, String, String?, Color?)> cells;
    if (unit == _Unit.month) {
      final total = filled.fold(0.0, (s, e) => s + e.$2);
      cells = [
        ('${period.year}년 합계', filled.isEmpty ? '-' : _num(total), null, null),
        ('월 평균', avg == null ? '-' : _num(avg), null, null),
        (
          '가장 많은 달',
          best == null ? '-' : _num(best.$2),
          best == null ? null : series.labels[best.$1],
          null,
        ),
        ('기록한 달', '${filled.length}달', null, null),
      ];
    } else {
      // 이번 달에 마지막으로 적은 날과 그 값
      int? lastIdx;
      final written = unit == _Unit.day
          ? series.written
          : [
              for (
                var d = 1;
                d <= DateTime(period.year, period.month + 1, 0).day;
                d++
              )
                _cumulativeAt(
                  stats,
                  field,
                  DateTime(period.year, period.month, d),
                ),
            ];
      for (var i = 0; i < written.length; i++) {
        if (written[i] != null) lastIdx = i;
      }
      final now = lastIdx == null ? null : written[lastIdx];
      final day = lastIdx == null
          ? null
          : DateTime(period.year, period.month, lastIdx + 1);
      final prevEnd = DateTime(period.year, period.month, 0).day;
      final before = day == null
          ? null
          : _cumulativeAt(
              stats,
              field,
              DateTime(
                period.year,
                period.month - 1,
                day.day > prevEnd ? prevEnd : day.day,
              ),
            );
      final diff = (now != null && before != null) ? now - before : null;
      cells = [
        (
          '${period.month}월 누적',
          now == null ? '-' : _num(now),
          day == null ? null : '${day.month}월 ${day.day}일까지',
          null,
        ),
        (
          '지난달 같은 날',
          before == null ? '-' : _num(before),
          diff == null ? null : '${diff > 0 ? '+' : ''}${_num(diff)}',
          diff == null || diff == 0
              ? null
              : diff > 0
              ? AppColors.success
              : AppColors.error,
        ),
        (
          unit == _Unit.day ? '하루 평균' : '주 평균',
          avg == null ? '-' : '+${_num(avg)}',
          null,
          null,
        ),
        (
          unit == _Unit.day ? '가장 많이 는 날' : '가장 많이 는 주',
          best == null ? '-' : '+${_num(best.$2)}',
          best == null ? null : series.titles[best.$1].split(' (').first,
          null,
        ),
      ];
    }

    Widget cell((String, String, String?, Color?) c) {
      final (label, value, sub, subColor) = c;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.title3),
            const SizedBox(height: 2),
            Text(
              sub ?? ' ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: subColor,
                fontWeight: subColor == null ? null : FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Row(children: [cell(cells[0]), cell(cells[1])]),
          const SizedBox(height: 14),
          Row(children: [cell(cells[2]), cell(cells[3])]),
        ],
      ),
    );
  }
}

/// 선 그래프 — 달력 칸 위에 점을 잇는다 (2026-09-30 대표 요청)
///
/// 기록이 없는 칸(일요일 등)은 **점을 안 찍고 건너뛴다.** 누르거나 끌면 그 칸의
/// 값이 위에 크게 뜬다. 일 단위는 지난달 같은 날을 회색 선으로 겹친다.
class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.field,
    required this.unit,
    required this.stats,
    required this.period,
    required this.onMove,
  });

  final String field;
  final _Unit unit;
  final BranchStats stats;
  final DateTime period;
  final ValueChanged<int> onMove;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  /// 누르고 있는 칸 — 없으면 값이 있는 마지막 칸
  int? _picked;

  @override
  void didUpdateWidget(covariant _ChartCard old) {
    super.didUpdateWidget(old);
    if (old.field != widget.field ||
        old.unit != widget.unit ||
        old.period != widget.period) {
      _picked = null;
    }
  }

  void _pick(Offset local, double width, int count) {
    final step = count <= 1 ? 0.0 : (width - _LineChart.padX * 2) / (count - 1);
    final i = step == 0
        ? 0
        : ((local.dx - _LineChart.padX) / step).round().clamp(0, count - 1);
    if (i != _picked) setState(() => _picked = i);
  }

  @override
  Widget build(BuildContext context) {
    final series = _series(
      widget.stats,
      widget.field,
      widget.unit,
      widget.period,
    );
    final values = series.values;
    int? lastWithValue;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != null) lastWithValue = i;
    }
    final picked = _picked ?? lastWithValue ?? 0;
    final pickedValue = values[picked];
    final title = switch (widget.unit) {
      _Unit.day => '날마다 늘어난 ${widget.field}',
      _Unit.week => '주마다 늘어난 ${widget.field}',
      _Unit.month => '달마다 ${widget.field} 합계',
    };
    final now = DateTime.now();
    final atLatest = widget.unit == _Unit.month
        ? widget.period.year >= now.year
        : !DateTime(
            widget.period.year,
            widget.period.month,
          ).isBefore(DateTime(now.year, now.month));
    final periodLabel = widget.unit == _Unit.month
        ? '${widget.period.year}년'
        : '${widget.period.year}년 ${widget.period.month}월';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.label)),
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
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                pickedValue == null ? '-' : _num(pickedValue),
                style: AppTextStyles.title1.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(series.titles[picked], style: AppTextStyles.caption),
              if (series.compare?[picked] case final prev?) ...[
                const Spacer(),
                Text(
                  '지난달 ${_num(prev)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (lastWithValue == null)
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
                onTapDown: (d) =>
                    _pick(d.localPosition, box.maxWidth, values.length),
                onHorizontalDragUpdate: (d) =>
                    _pick(d.localPosition, box.maxWidth, values.length),
                child: SizedBox(
                  width: box.maxWidth,
                  height: 220,
                  child: CustomPaint(
                    painter: _LineChart(
                      bubbleTitle: series.titles[picked],
                      // 그 칸의 칸별 숫자 — 일·주는 늘어난 수, 월은 그달 누적
                      bubbleRows: [
                        for (final f in widget.stats.fields)
                          (
                            f,
                            _series(
                              widget.stats,
                              f,
                              widget.unit,
                              widget.period,
                            ).values[picked],
                            f == widget.field,
                          ),
                      ],
                      showBubble: _picked != null,
                      values: values,
                      compare: series.compare,
                      labels: series.labels,
                      picked: picked,
                      labelEvery: widget.unit == _Unit.day
                          ? 7
                          : widget.unit == _Unit.month
                          ? 2
                          : 1,
                      line: AppColors.primary,
                      compareLine: AppColors.gray300,
                      grid: AppColors.gray100,
                      text: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                      surface: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          if (series.compare != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _Legend(color: AppColors.primary, label: '이번 달'),
                const SizedBox(width: 14),
                _Legend(color: AppColors.gray300, label: '지난달'),
              ],
            ),
          ],
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

/// 선 그래프 그리기 — 칸 자리는 고정, 값이 있는 칸만 잇는다
class _LineChart extends CustomPainter {
  _LineChart({
    required this.bubbleTitle,
    required this.bubbleRows,
    required this.showBubble,
    required this.values,
    required this.compare,
    required this.labels,
    required this.picked,
    required this.labelEvery,
    required this.line,
    required this.compareLine,
    required this.grid,
    required this.text,
    required this.surface,
  });

  /// 말풍선 — 누른 칸의 이름 · 칸별 숫자 (이름 · 값 · 지금 보는 칸인가)
  final String bubbleTitle;
  final List<(String, double?, bool)> bubbleRows;

  /// 직접 눌렀을 때만 띄운다 — 처음 열었을 때 말풍선이 떠 있으면 선을 가린다
  final bool showBubble;

  final List<double?> values;
  final List<double?>? compare;
  final List<String> labels;
  final int picked;

  /// 아래 글자를 몇 칸마다 적나 — 마지막 칸은 늘 적는다
  final int labelEvery;
  final Color line;
  final Color compareLine;
  final Color grid;
  final TextStyle text;
  final Color surface;

  /// 좌우 여백 — 첫·마지막 점이 카드 끝에 붙지 않게
  static const padX = 10.0;

  static const _labelH = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - _labelH;
    final all = [
      ...values.whereType<double>(),
      ...?compare?.whereType<double>(),
    ];
    final top = all.fold(0.0, (m, v) => v > m ? v : m);
    final bottom = all.fold(0.0, (m, v) => v < m ? v : m);
    final span = (top - bottom) == 0 ? 1.0 : (top - bottom);
    final n = values.length;
    final step = n <= 1 ? 0.0 : (size.width - padX * 2) / (n - 1);

    double x(int i) => n <= 1 ? size.width / 2 : padX + step * i;
    double y(double v) => 10 + (chartH - 20) * (1 - (v - bottom) / span);

    // 눈금선 — 위·가운데·아래
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final gy = 10 + (chartH - 20) * f;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }

    /// 값이 있는 점만 부드럽게 잇는다 (빈 칸은 건너뛴다)
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

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 지난달 — 회색 가는 선을 먼저 (아래에 깔린다)
    if (compare != null) {
      final c = curve(compare!);
      if (c != null) {
        canvas.drawPath(
          c,
          stroke
            ..color = compareLine
            ..strokeWidth = 1.8,
        );
      }
    }

    final path = curve(values);
    if (path != null) {
      final first = values.indexWhere((v) => v != null);
      final last = values.lastIndexWhere((v) => v != null);
      if (last > first) {
        final fill = Path.from(path)
          ..lineTo(x(last), chartH - 10)
          ..lineTo(x(first), chartH - 10)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [line.withValues(alpha: 0.18), line.withValues(alpha: 0)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // 값이 있는 점은 작게 찍어 둔다 — 빈 칸과 갈리게
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        canvas.drawCircle(Offset(x(i), y(v)), 2.4, Paint()..color = line);
      }
    }

    // 고른 칸 — 세로 안내선, 값이 있으면 흰 테두리 점
    final px = x(picked.clamp(0, n - 1));
    canvas.drawLine(
      Offset(px, 10),
      Offset(px, chartH - 10),
      Paint()
        ..color = line.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
    final pv = values[picked.clamp(0, n - 1)];
    if (pv != null) {
      canvas.drawCircle(Offset(px, y(pv)), 7, Paint()..color = surface);
      canvas.drawCircle(Offset(px, y(pv)), 5, Paint()..color = line);
    }

    if (showBubble) _bubble(canvas, size, px, pv == null ? 10 : y(pv));

    // 아래 글자 — [labelEvery] 칸마다 + 마지막 칸 (몰리지 않게)
    for (var i = 0; i < n; i++) {
      final last = i == n - 1;
      if (i % labelEvery != 0 && !last) continue;
      if (!last && n - 1 - i < labelEvery / 2) continue;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: text),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, chartH + 4));
    }
  }

  /// 누른 점 위에 말풍선 — 위가 모자라면 아래로 내린다
  void _bubble(Canvas canvas, Size size, double px, double py) {
    TextPainter tp(String t, TextStyle st) => TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
    )..layout();
    final lines = [
      tp(bubbleTitle, text.copyWith(color: surface.withValues(alpha: 0.8))),
      for (final (name, v, current) in bubbleRows)
        tp(
          '$name ${v == null ? '-' : _num(v)}',
          text.copyWith(
            color: current ? surface : surface.withValues(alpha: 0.85),
            fontSize: current ? 14 : 12,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
    ];
    const padH = 10.0, padV = 8.0, gap = 2.0, arrow = 6.0;
    final w = lines.fold(0.0, (m, l) => l.width > m ? l.width : m) + padH * 2;
    final h =
        lines.fold(0.0, (s, l) => s + l.height) +
        gap * (lines.length - 1) +
        padV * 2;
    final above = py - h - arrow - 8 >= 0;
    final top = above ? py - h - arrow - 8 : py + arrow + 8;
    final left = (px - w / 2).clamp(0.0, size.width - w);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(10),
    );
    final paint = Paint()..color = line;
    canvas.drawRRect(rect, paint);
    // 꼬리 — 점을 가리킨다
    final tipY = above ? top + h + arrow : top - arrow;
    final baseY = above ? top + h : top;
    canvas.drawPath(
      Path()
        ..moveTo(px - arrow, baseY)
        ..lineTo(px + arrow, baseY)
        ..lineTo(px, tipY)
        ..close(),
      paint,
    );
    var ty = top + padV;
    for (final l in lines) {
      l.paint(canvas, Offset(left + padH, ty));
      ty += l.height + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChart old) =>
      old.values != values ||
      old.compare != compare ||
      old.picked != picked ||
      old.showBubble != showBubble ||
      old.labels != labels;
}
