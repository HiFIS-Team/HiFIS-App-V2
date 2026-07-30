import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pressable.dart';

/// 세그먼트 스위치의 바깥 트랙 — 안 눌린 칸이 배경에 묻히지 않게 회색 면을 깐다
BoxDecoration segmentTrack() {
  return BoxDecoration(
    color: AppColors.track,
    borderRadius: BorderRadius.circular(14),
  );
}

/// 트랙 안의 칸 한 개 — 선택되면 흰 면으로 떠오르고, 아니면 트랙이 비친다
BoxDecoration segmentFill({required bool selected, bool hovered = false}) {
  return BoxDecoration(
    color: selected
        ? AppColors.surface
        : hovered
        ? AppColors.surface.withValues(alpha: 0.5)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
  );
}

/// 두 값 사이를 전환하는 세그먼트 스위치 — 회색 트랙 위에 선택된 쪽이 흰 칸으로 뜬다
class ModeSwitch extends StatelessWidget {
  ModeSwitch({
    super.key,
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  final String left;
  final String right;

  /// true면 오른쪽이 선택된 상태
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: left,
              selected: !value,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: right,
              selected: value,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// 여러 값 중 하나를 고르는 세그먼트 ([ModeSwitch]의 N개 버전)
///
/// 칸을 균등하게 나누고, 라벨이 길어 칸을 넘치면 글자를 줄여 맞춘다.
class SegmentedTabs extends StatelessWidget {
  SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Segment(
                label: labels[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 선택돼 있던
      // 칸이 서서히 사라지며 양쪽이 같이 눌린 것처럼 보인다
      child: Container(
        decoration: segmentFill(selected: selected),
        child: Center(
          // 칸보다 라벨이 길면 줄여서 맞춘다 (3단 이상에서 넘칠 수 있다)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: selected ? AppColors.textPrimary : AppColors.gray600,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
