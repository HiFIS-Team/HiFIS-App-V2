import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../feedback/app_dialog.dart';
import 'app_button.dart';
import 'pressable.dart';

/// 앱 톤 달력으로 날짜 하나 고르기 — 취소하면 `null`
///
/// **머티리얼 `showDatePicker` 를 안 쓴다.** 그건 자기 색·자기 글꼴·자기
/// 모서리를 들고 와서, 한 화면 안에서 이 칸만 다른 앱처럼 보인다. 색만
/// 덮어써도 헤더 덩어리와 연도 고르개가 그대로 남는다.
Future<DateTime?> pickAppDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? min,
  DateTime? max,
}) => showAppDialog<DateTime>(
  context,
  (_) => AppDatePicker(initial: initial, min: min, max: max),
);

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

class AppDatePicker extends StatefulWidget {
  const AppDatePicker({super.key, required this.initial, this.min, this.max});

  final DateTime initial;

  /// 이 날 이전은 못 고른다 — 안 주면 아래로 막지 않는다
  final DateTime? min;

  /// 이 날 이후는 못 고른다 — 안 주면 위로 막지 않는다
  final DateTime? max;

  @override
  State<AppDatePicker> createState() => _AppDatePickerState();
}

class _AppDatePickerState extends State<AppDatePicker> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _picked = _dayOf(widget.initial);

  DateTime? get _floor => widget.min == null ? null : _dayOf(widget.min!);

  DateTime? get _ceil => widget.max == null ? null : _dayOf(widget.max!);

  bool _allowed(DateTime date) {
    if (_floor case final low? when date.isBefore(low)) return false;
    if (_ceil case final high? when date.isAfter(high)) return false;
    return true;
  }

  bool get _canGoBack {
    final low = _floor;
    return low == null || _month.isAfter(DateTime(low.year, low.month));
  }

  bool get _canGoNext {
    final high = _ceil;
    return high == null || _month.isBefore(DateTime(high.year, high.month));
  }

  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  /// 오늘로 — 달을 여러 번 넘기지 않고 한 번에 돌아온다
  void _today() {
    final now = _dayOf(DateTime.now());
    if (!_allowed(now)) return;
    setState(() {
      _month = DateTime(now.year, now.month);
      _picked = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    // 그 달 1일이 무슨 요일인지 — 일요일을 0 으로 둔다
    final lead = _month.weekday % 7;
    final rows = ((lead + lastDay) / 7).ceil();
    final todayAllowed = _allowed(_dayOf(DateTime.now()));

    return Container(
      width: dialogWidth(context, 340),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _arrow(CupertinoIcons.chevron_left, _canGoBack, () => _move(-1)),
              Expanded(
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title3,
                ),
              ),
              _arrow(CupertinoIcons.chevron_right, _canGoNext, () => _move(1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(row * 7 + col - lead + 1, lastDay)),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (todayAllowed) ...[
                AppButton(label: '오늘', shrinkWrap: true, onTap: _today),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AppButton(
                  label: '취소',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '선택',
                  filled: true,
                  onTap: () => Navigator.pop(context, _picked),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int dayNumber, int lastDay) {
    if (dayNumber < 1 || dayNumber > lastDay) return const SizedBox(height: 40);
    final date = DateTime(_month.year, _month.month, dayNumber);
    return _PickCell(
      date: date,
      selected: _sameDay(date, _picked),
      today: _sameDay(date, DateTime.now()),
      enabled: _allowed(date),
      onTap: () => setState(() => _picked = date),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) => Pressable(
    onTap: enabled ? onTap : () {},
    child: Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 14,
        color: enabled ? AppColors.textSecondary : AppColors.gray300,
      ),
    ),
  );
}

class _PickCell extends StatelessWidget {
  const _PickCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sunday = date.weekday == DateTime.sunday;

    return Pressable(
      onTap: enabled ? onTap : () {},
      child: SizedBox(
        height: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              // 오늘은 고른 날이 아닐 때만 테두리로 표시한다 (겹치면 둘 다 안 읽힌다)
              border: today && !selected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                fontWeight: selected || today
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected
                    ? AppColors.surface
                    : !enabled
                    ? AppColors.gray300
                    : sunday
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
