import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 고른 칸으로 미끄러지는 데 걸리는 시간 (2026-08-21 대표 요청)
///
/// **목록바가 도는 자리는 다 이 값을 쓴다** — 밑줄 탭([UnderlineTabs])도
/// 같이 쓴다. 두 값으로 갈리면 화면마다 빠르기가 달라진다.
const slideDuration = Duration(milliseconds: 240);
const slideCurve = Curves.easeOutCubic;

/// 칸 안쪽 좌우 여백 — 폭을 미리 재는 데 쓴다 (`expand: false` 일 때)
const _segmentPadding = 18.0;

/// 목록바 글자 — **고른 칸은 굵어진다.** 폭을 잴 때도 이 스타일을 쓴다
TextStyle segmentTextStyle({required bool selected}) =>
    AppTextStyles.body2.copyWith(
      fontSize: 14,
      color: selected ? AppColors.primary : AppColors.gray600,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

/// 글자 한 줄이 차지하는 폭 — 화면에 그리기 **전에** 잰다
///
/// 알약을 옮기려면 어느 칸이 어디서 시작해 얼마나 넓은지를 그리기 전에
/// 알아야 한다. 다 그린 뒤에 재면(`GlobalKey`) 첫 프레임에 알약이 엉뚱한
/// 자리에 있다가 튄다.
double measureLabel(BuildContext context, String label, {required bool bold}) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: segmentTextStyle(selected: bold),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// 칸마다의 폭
///
/// **고른 칸이 굵어져도 폭이 안 변해야 한다.** 지금 글자 그대로 재면 고를
/// 때마다 칸이 넓어졌다 좁아져서 옆 칸들이 밀린다 — 알약이 미끄러지는데
/// 바닥이 같이 움직이면 그게 곧 '확' 하는 느낌이다. 그래서 **늘 굵은 폭**으로
/// 잡아 두고 안 고른 글자는 그 안에서 가운데 선다.
List<double> _segmentWidths(
  BuildContext context,
  List<String> labels,
  bool expand,
  double maxWidth,
) {
  if (expand) {
    // 균등하게 나눈다 — 마지막 칸이 반올림으로 삐져나오지 않게 남는 폭을 준다
    final each = maxWidth / labels.length;
    return [
      for (var i = 0; i < labels.length; i++)
        i == labels.length - 1 ? maxWidth - each * i : each,
    ];
  }
  return [
    for (final label in labels)
      measureLabel(context, label, bold: true) + _segmentPadding * 2,
  ];
}

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
      child: LayoutBuilder(
        builder: (context, box) {
          final widths = _segmentWidths(
            context,
            widget.labels,
            widget.expand,
            box.maxWidth,
          );
          final index = widget.selected.clamp(0, widget.labels.length - 1);
          var left = 0.0;
          for (var i = 0; i < index; i++) {
            left += widths[i];
          }
          return SizedBox(
            width: widget.expand
                ? box.maxWidth
                : widths.reduce((a, b) => a + b),
            child: Stack(
              children: [
                // 흰 알약 **하나**가 자리를 옮긴다 — 칸마다 따로 켜고 끄면
                // 옮기는 동안 둘 다 켜져 보이거나(페이드) 툭 튄다(즉시)
                AnimatedPositioned(
                  duration: slideDuration,
                  curve: slideCurve,
                  left: left,
                  width: widths[index],
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: segmentFill(selected: true)),
                ),
                Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.labels.length; i++)
                      SizedBox(width: widths[i], child: _segment(i)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segment(int index) {
    return _Segment(
      label: widget.labels[index],
      selected: index == widget.selected,
      hovered: index == _hover,
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

/// 밑줄 목록바 — 고른 칸 아래 파란 줄이 **미끄러진다** (2026-08-21 대표 요청)
///
/// 알약 목록바([SegmentedTabs])와 **같은 빠르기**로 돈다. 폰 업무 탭·내역
/// 탭이 이걸 쓴다 — 예전에는 칸마다 아래 테두리를 켰다 껐다 해서 툭 튀었다.
///
/// **줄은 칸 전체가 아니라 글자 폭에 맞춘다.** 예전 모양 그대로다.
class UnderlineTabs extends StatelessWidget {
  UnderlineTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 글자 위아래 여백 — 예전 `_WorkTab` 과 같은 값이다
  static const _vertical = 12.0;

  /// 밑줄이 글자보다 살짝 넓게 깔리도록 주는 좌우 여유
  static const _slack = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / labels.length;
        final index = selected.clamp(0, labels.length - 1);
        // 밑줄 폭은 **고른 칸의 글자 폭**이다. 굵은 글자로 재야 실제와 맞는다
        final bar =
            measureLabel(context, labels[index], bold: true) + _slack * 2;
        // 그 칸 한가운데에 놓는다
        final left = cell * index + (cell - bar) / 2;
        return SizedBox(
          height: _height(context),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Pressable(
                        onTap: () => onSelect(i),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              style: segmentTextStyle(selected: i == selected),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: slideDuration,
                curve: slideCurve,
                left: left.clamp(0.0, box.maxWidth),
                width: bar,
                bottom: 0,
                child: Container(height: 2, color: AppColors.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 글자 높이 + 위아래 여백 — 예전에는 `Container` 가 알아서 잡던 값이다.
  /// 밑줄을 겹쳐 놓으려면 `Stack` 이 높이를 알아야 해서 여기서 셈한다.
  double _height(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: '가', style: segmentTextStyle(selected: true)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height + _vertical * 2;
  }
}

class _Segment extends StatelessWidget {
  _Segment({
    required this.label,
    required this.selected,
    required this.hovered,
    required this.onTap,
    required this.onHover,
  });

  final String label;
  final bool selected;
  final bool hovered;
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
        style: segmentTextStyle(selected: selected),
      ),
    );

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Pressable(
        onTap: onTap,
        // **고른 칸의 흰 면은 여기서 안 그린다** — 뒤에서 알약 하나가
        // 미끄러져 온다. 여기서도 그리면 옮기는 동안 둘이 같이 켜져 보인다.
        // 커서가 올라간 표시만 남긴다 (데스크톱).
        child: Container(
          alignment: Alignment.center,
          decoration: segmentFill(
            selected: false,
            hovered: hovered && !selected,
          ),
          child: text,
        ),
      ),
    );
  }
}
