import 'package:flutter/material.dart';

import '../../api/work/my_task_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 요일 일곱 칸 — 켜진 요일만 고른 것이다 (ISO 1=월 … 7=일)
///
/// 개인 업무가 **정한 요일에만** 돌아오게 하려고 만들었다 (2026-08-20).
/// 금요일에만 하는 대청소를 매일 목록에 세우면 월~목이 전부 누락이었다.
///
/// [selected] 를 **직접 고쳐 쓴다** — 부모가 들고 있는 집합이라 여기서
/// 넣고 빼고, 다시 그리라고 [onChanged] 를 부른다. 값을 복사해서 돌려주면
/// 부모가 두 벌을 들고 있게 된다.
///
/// **하나도 안 고르면 매일로 본다** (부모가 저장할 때 그렇게 넘긴다) —
/// 아무 요일에도 안 걸린 업무는 영영 안 뜨기 때문이다. 서버도 같은 규칙이다
/// (`clean_weekdays`).
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.note,
  });

  final Set<int> selected;
  final VoidCallback onChanged;

  /// 칸 아래 한 줄 설명 — 없으면 안 그린다
  final String? note;

  static const _names = ['월', '화', '수', '목', '금', '토', '일'];

  void _toggle(int day) {
    if (!selected.remove(day)) selected.add(day);
    onChanged();
  }

  /// 전부 켜져 있으면 **매일**이라 따로 알려 줄 것이 없다
  bool get _every => selected.length == 7;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (var day = 1; day <= 7; day++) ...[
            if (day > 1) const SizedBox(width: 6),
            Expanded(
              child: _Cell(
                day: day,
                on: selected.contains(day),
                onTap: _toggle,
              ),
            ),
          ],
        ],
      ),
      if (note case final text?) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            // 매일이면 요일을 안 적는다 — 일곱 개를 다 나열해 봐야 길기만 하다
            _every
                ? '매일 뜨는 업무예요'
                : '$text (${weekdayLabel(selected.toList()..sort())})',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
          ),
        ),
      ],
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.on, required this.onTap});

  final int day;
  final bool on;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // 일요일만 꺼져 있을 때 붉게 — 달력과 같은 규칙이다
    final off = day == 7 ? AppColors.error : AppColors.textSecondary;
    return Pressable(
      onTap: () => onTap(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          WeekdayPicker._names[day - 1],
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : off,
          ),
        ),
      ),
    );
  }
}
