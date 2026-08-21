import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
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
///
/// 칸이 둘로 고정된 것 말고는 [SegmentedTabs] 와 같은 물건이다. 트랙·알약·
/// 글자·커서 반응을 같은 부품(`_Segment`)에서 가져오므로 둘이 갈리지 않는다.
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
  Widget build(BuildContext context) => SegmentedTabs(
    labels: [left, right],
    selected: value ? 1 : 0,
    onSelect: (index) => onChanged(index == 1),
  );
}

/// 여러 값 중 하나를 고르는 세그먼트 ([ModeSwitch]의 N개 버전)
///
/// 칸을 균등하게 나누고, 라벨이 길어 칸을 넘치면 글자를 줄여 맞춘다.
///
/// **업무 화면의 항목 탭이 기준이다.** 예전에는 업무만 따로 만든 위젯을 써서
/// 거기만 커서 반응이 있고 고른 칸 글자가 파랬다. 지금은 업무도 이걸 쓴다 —
/// 다른 화면의 목록바와 한 몸이라 갈릴 수가 없다.
class SegmentedTabs extends StatefulWidget {
  SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.expand = true,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 칸을 균등하게 나눌지 — false 면 글자 폭만큼만 차지한다
  ///
  /// 업무 화면처럼 **왼쪽에 붙여 놓는** 탭이 false 다. 화면 폭을 채우는
  /// 자리(월차·급여·모니터링)는 true 여야 오른쪽 선이 다른 요소와 맞는다.
  final bool expand;

  @override
  State<SegmentedTabs> createState() => _SegmentedTabsState();
}

class _SegmentedTabsState extends State<SegmentedTabs> {
  /// 커서가 올라간 칸 — 마우스가 없는 폰에서는 늘 null 이다
  int? _hover;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.labels.length; i++)
            if (widget.expand) Expanded(child: _segment(i)) else _segment(i),
        ],
      ),
    );
  }

  Widget _segment(int index) {
    return _Segment(
      label: widget.labels[index],
      selected: index == widget.selected,
      hovered: index == _hover,
      expand: widget.expand,
      onTap: () => widget.onSelect(index),
      onHover: (over) => setState(() {
        if (over) {
          _hover = index;
        } else if (_hover == index) {
          _hover = null;
        }
      }),
    );
  }
}

class _Segment extends StatelessWidget {
  _Segment({
    required this.label,
    required this.selected,
    required this.hovered,
    required this.expand,
    required this.onTap,
    required this.onHover,
  });

  final String label;
  final bool selected;
  final bool hovered;
  final bool expand;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    // 칸보다 라벨이 길면 줄여서 맞춘다 (3단 이상에서 넘칠 수 있다)
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: AppTextStyles.body2.copyWith(
          fontSize: 14,
          color: selected ? AppColors.primary : AppColors.gray600,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Pressable(
        onTap: onTap,
        // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 선택돼 있던
        // 칸이 서서히 사라지며 양쪽이 같이 눌린 것처럼 보인다
        child: Container(
          padding: expand ? null : EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: segmentFill(selected: selected, hovered: hovered),
          child: text,
        ),
      ),
    );
  }
}
