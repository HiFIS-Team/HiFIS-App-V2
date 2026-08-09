import 'package:flutter/material.dart';

/// 화면 **안**에서 판을 바꿀 때 **살짝 아래에서 올라오며** 나타나는 전환
///
/// 목록바(`SegmentedTabs`)로 항목을 옮기는 자리들이 다 이걸 쓴다 —
/// 업무·모니터링·랭킹·조직도·급여·근태. **어느 바에서든 같게 움직여야 한다.**
///
/// 사이드바로 화면을 통째로 바꾸는 [LazyIndexedStack] 은 여기 값을 안 쓴다.
/// 거기는 화면 전체를 갈아 끼우는 자리라 크게 움직이는 게 맞다.
///
/// [step] 이 바뀔 때마다 처음부터 다시 재생한다. 첫 화면은 이미 떠 있는 것이라
/// 재생하지 않는다 (들어오자마자 한 번 흔들리면 그게 깜빡임이다).
class PaneTransition extends StatefulWidget {
  PaneTransition({super.key, required this.step, required this.child});

  static const duration = Duration(milliseconds: 240);
  static const curve = Curves.easeOut;

  /// 이만큼 아래에서 올라온다 (px)
  ///
  /// **`SlideTransition` 을 쓰면 안 된다.** 거기 오프셋은 화면이 아니라
  /// **그 판 자신의 높이 비율**이라, 판이 길수록 더 멀리서 올라온다.
  /// 예전에는 `Offset(0, 0.012)` 였는데 모니터링에서 판마다 느낌이 갈렸다 —
  /// 성능·이상은 알맞은데 접속·활동은 목록이 길어서 훨씬 아래에서 솟았다
  /// (같은 하단바인데 항목마다 다르게 움직였다).
  ///
  /// 픽셀로 고정하면 판 길이와 상관없이 어디서나 같다.
  static const beginY = 9.0;

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
    begin: PaneTransition.beginY,
    end: 0.0,
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
    child: AnimatedBuilder(
      animation: _slide,
      // 자식은 한 번만 만들고 위치만 옮긴다
      child: widget.child,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _slide.value), child: child),
    ),
  );
}
