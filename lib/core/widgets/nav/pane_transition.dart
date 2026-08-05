import 'package:flutter/material.dart';

/// 자리를 옮길 때 **살짝 아래에서 올라오며** 나타나는 전환
///
/// 사이드바로 화면을 바꿀 때 [LazyIndexedStack] 이 주는 것과 **같은 값**이다 —
/// 한 앱 안에서 자리를 옮기는 느낌이 데가 다르면 어색하다. 값은 여기 한 곳에만
/// 두고 양쪽이 같이 읽는다.
///
/// [step] 이 바뀔 때마다 처음부터 다시 재생한다. 첫 화면은 이미 떠 있는 것이라
/// 재생하지 않는다 (들어오자마자 한 번 흔들리면 그게 깜빡임이다).
class PaneTransition extends StatefulWidget {
  PaneTransition({super.key, required this.step, required this.child});

  static const duration = Duration(milliseconds: 240);
  static const curve = Curves.easeOut;

  /// 화면 높이의 1.2% ≈ 9px 아래에서 올라온다
  static const beginOffset = Offset(0, 0.012);

  /// 이 값이 바뀌면 다시 재생한다 (탭 번호 등)
  final Object step;

  final Widget child;

  @override
  State<PaneTransition> createState() => _PaneTransitionState();
}

class _PaneTransitionState extends State<PaneTransition>
    with SingleTickerProviderStateMixin {
  /// 1 에서 시작해 첫 화면은 그냥 떠 있다
  late final _controller = AnimationController(
    vsync: this,
    duration: PaneTransition.duration,
    value: 1,
  );

  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: PaneTransition.curve,
  );

  late final _slide = Tween(
    begin: PaneTransition.beginOffset,
    end: Offset.zero,
  ).animate(_fade);

  @override
  void didUpdateWidget(PaneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
