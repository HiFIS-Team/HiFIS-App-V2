import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/util/screen_refresh.dart';

/// [ScreenRefresh] 가 언제 다시 받는지
///
/// 탭을 살려 두는 `LazyIndexedStack` 을 흉내 낸다 — 거기서 쓰는 `TickerMode`
/// 를 그대로 걸고 껐다 켜면서, 화면이 다시 보일 때만 다시 받는지 본다.
void main() {
  testWidgets('탭을 떠났다 돌아오면 다시 받는다', (tester) async {
    final calls = <int>[];
    await tester.pumpWidget(_Host(onRefresh: () => calls.add(0)));

    // 처음 만들 때는 화면이 스스로 받는다 — 여기서 또 받으면 두 번이다
    expect(calls, isEmpty);

    await tester.state<_HostState>(find.byType(_Host)).show(false);
    await tester.pump();
    expect(calls, isEmpty, reason: '가려질 때는 받지 않는다');

    await tester.state<_HostState>(find.byType(_Host)).show(true);
    await tester.pump();
    await tester.pump();
    expect(calls, hasLength(1), reason: '돌아오면 한 번 받는다');
  });

  testWidgets('앱이 다시 앞으로 나오면 보고 있는 탭만 받는다', (tester) async {
    final calls = <int>[];
    await tester.pumpWidget(_Host(onRefresh: () => calls.add(0)));

    appResumed.value++;
    await tester.pump();
    await tester.pump();
    expect(calls, hasLength(1));

    // 가려 두고 복귀하면 안 받는다 — 복귀 한 번에 탭 12개가 다 받으면 안 된다
    await tester.state<_HostState>(find.byType(_Host)).show(false);
    await tester.pump();
    appResumed.value++;
    await tester.pump();
    await tester.pump();
    expect(calls, hasLength(1));
  });

  testWidgets('최소 간격 안에는 다시 받지 않는다', (tester) async {
    final calls = <int>[];
    // 실제 화면이 쓰는 간격(1분). 방금 연 화면은 그 자체가 첫 로드라,
    // 데스크톱에서 다른 창을 오가며 포커스가 여러 번 바뀌어도 요청이 안 나간다.
    await tester.pumpWidget(
      _Host(onRefresh: () => calls.add(0), gap: const Duration(minutes: 1)),
    );

    for (var i = 0; i < 3; i++) {
      appResumed.value++;
      await tester.pump();
      await tester.pump();
    }
    expect(calls, isEmpty, reason: '연달아 복귀해도 간격 안이면 안 받는다');
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onRefresh, this.gap = Duration.zero});

  final VoidCallback onRefresh;
  final Duration gap;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _shown = true;

  Future<void> show(bool value) async => setState(() => _shown = value);

  @override
  Widget build(BuildContext context) {
    // LazyIndexedStack 과 같은 모양 — 탭은 살아 있고 TickerMode 만 꺼진다
    return TickerMode(
      enabled: _shown,
      child: _Screen(onRefresh: widget.onRefresh, gap: widget.gap),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({required this.onRefresh, required this.gap});

  final VoidCallback onRefresh;
  final Duration gap;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with ScreenRefresh<_Screen> {
  @override
  Duration get screenRefreshGap => widget.gap;

  @override
  Future<void> onScreenRefresh() async => widget.onRefresh();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
