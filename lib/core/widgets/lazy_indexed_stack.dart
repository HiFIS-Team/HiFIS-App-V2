import 'package:flutter/material.dart';

/// 한 번이라도 연 탭만 만들어 두는 [IndexedStack]
///
/// 기본 IndexedStack은 children을 전부 만들고 배치까지 한다. 탭이 8~12개면
/// 앱을 켤 때 안 보는 화면까지 통째로 만드느라 첫 화면이 늦게 뜨고,
/// 탭을 바꿀 때마다 12개 화면이 다시 만들어진다.
///
/// 연 적 있는 탭만 남기므로 화면 상태(스크롤 위치·입력값)는 그대로 유지되고,
/// 아직 안 연 탭은 빈 자리로 둔다.
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

  /// 탭이 바뀔 때마다 처음부터 다시 재생한다 (1에서 시작해 첫 화면은 그냥 떠 있다)
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 240),
    value: 1,
  );

  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  /// 살짝 아래에서 올라오면서 나타난다 (화면 높이의 1.2% ≈ 9px)
  late final _slide = Tween(
    begin: Offset(0, 0.012),
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
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
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
                widget.children[i]
              else
                SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
