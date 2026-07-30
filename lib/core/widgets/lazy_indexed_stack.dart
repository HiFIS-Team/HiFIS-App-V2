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

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final _opened = <int>{};

  @override
  void initState() {
    super.initState();
    _opened.add(widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _opened.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_opened.contains(i)) widget.children[i] else SizedBox.shrink(),
      ],
    );
  }
}
