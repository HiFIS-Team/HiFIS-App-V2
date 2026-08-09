import 'package:flutter/material.dart';

import 'pane_transition.dart';

/// 한 번이라도 연 탭만 만들어 두는 [IndexedStack]
///
/// 기본 IndexedStack은 children을 전부 만들고 배치까지 한다. 탭이 8~12개면
/// 앱을 켤 때 안 보는 화면까지 통째로 만드느라 첫 화면이 늦게 뜨고,
/// 탭을 바꿀 때마다 12개 화면이 다시 만들어진다.
///
/// 연 적 있는 탭만 남기므로 화면 상태(필터·입력값)는 그대로 유지되고,
/// 아직 안 연 탭은 빈 자리로 둔다.
///
/// 다만 **스크롤 위치는 탭을 떠날 때 맨 위로 되돌린다.** 한참 내려보다
/// 다른 탭에 갔다 오면 중간에서 시작해 지금 어디를 보는지 알기 어렵다.
class LazyIndexedStack extends StatefulWidget {
  LazyIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack>
    with SingleTickerProviderStateMixin {
  final _opened = <int>{};

  /// 탭을 떠날 때 그 탭 안만 되감으려고 탭마다 하나씩 잡아 둔다
  final _keys = <int, GlobalKey>{};

  GlobalKey _keyOf(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  /// 탭이 바뀔 때마다 처음부터 다시 재생한다 (1에서 시작해 첫 화면은 그냥 떠 있다)
  ///
  /// 값은 [PaneTransition] 이 들고 있다 — 모니터링 탭 전환도 같은 값을 쓴다.
  late final _controller = AnimationController(
    vsync: this,
    duration: PaneTransition.duration,
    value: 1,
  );

  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: PaneTransition.curve,
  );

  /// 살짝 아래에서 올라오면서 나타난다 (화면 높이의 1.2%)
  ///
  /// **여기는 비율 그대로 둔다.** 사이드바는 화면을 통째로 바꾸는 자리라
  /// 화면이 길수록 크게 움직이는 게 맞다. 화면 **안**의 판을 바꾸는
  /// [PaneTransition] 만 픽셀로 고정했다 — 거기는 판 길이가 제각각이라
  /// 같은 바인데 항목마다 다르게 움직였다.
  late final _slide = Tween(
    begin: const Offset(0, 0.012),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    _opened.add(widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _opened.add(widget.index);
    if (oldWidget.index == widget.index) return;

    _controller.forward(from: 0);

    // 들어올 때가 아니라 나갈 때 되감는다 — 화면이 이미 가려진 뒤라
    // 목록이 위로 튀는 게 보이지 않는다.
    // 빌드가 끝난 뒤에 (스크롤 알림이 빌드 도중 돌면 안 된다)
    final leaving = oldWidget.index;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rewind(leaving));
  }

  /// 떠난 탭 안의 세로 스크롤을 전부 맨 위로 돌린다
  ///
  /// 화면마다 컨트롤러를 다는 방식은 이미 자기 컨트롤러를 쓰는 화면
  /// (프로젝트·전자결재 등)을 놓쳐서, 그 탭의 위젯 트리를 훑어 되감는다.
  void _rewind(int index) {
    final context = _keys[index]?.currentContext;
    if (context == null) return;

    void visit(Element element) {
      if (element.widget is Scrollable) {
        final state = (element as StatefulElement).state as ScrollableState;
        // 가로로 미는 칩 줄 같은 건 건드리지 않는다
        if (state.mounted && state.position.axis == Axis.vertical) {
          final position = state.position;
          if (position.hasPixels && position.pixels != 0) position.jumpTo(0);
        }
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: widget.index,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              if (_opened.contains(i))
                // 안 보이는 탭의 애니메이션·시계를 멈춘다.
                //
                // IndexedStack 은 탭을 **살려 둔 채** 하나만 그린다. 그래서
                // 한 번 연 탭의 AnimationController 와 타이머가 앱을 끌 때까지
                // 계속 돈다 — 홈의 1초 시계가 다른 탭에 있는 동안에도
                // 매초 카드를 다시 그렸다.
                //
                // TickerMode 는 InheritedWidget 이라 배치에 아무 영향이 없다.
                // AnimationController 는 저절로 멈추고, Timer 를 쓰는 곳은
                // `TickerMode.valuesOf(context).enabled` 를 보고 스스로 쉰다.
                TickerMode(
                  enabled: i == widget.index,
                  child: KeyedSubtree(
                    key: _keyOf(i),
                    child: widget.children[i],
                  ),
                )
              else
                SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
