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

  // ── 갈래 신호 (`watchSignals`) ───────────────────────────────────────────
  //
  // 다른 화면이 값을 바꿨을 때 쓰는 길이다. 간격을 안 따지는 것이 핵심이라
  // **간격을 1분으로 켜 두고** 잰다 — 간격이 0이면 신호가 통했는지
  // 그냥 시간이 지나서 받은 것인지 갈리지 않는다.

  testWidgets('신호가 오면 간격을 안 따지고 바로 받는다', (tester) async {
    final calls = <int>[];
    final signal = ValueNotifier<int>(0);
    await tester.pumpWidget(
      _Host(
        onRefresh: () => calls.add(0),
        gap: const Duration(minutes: 1),
        signals: [signal],
      ),
    );

    // 같은 간격 안에서 복귀만으로는 안 받는다 (위 테스트와 같은 조건)
    appResumed.value++;
    await tester.pump();
    await tester.pump();
    expect(calls, isEmpty);

    signal.value++;
    await tester.pump();
    await tester.pump();
    expect(calls, hasLength(1), reason: '신호는 간격을 건너뛴다');
  });

  testWidgets('안 보이는 탭은 그 자리에서 안 받고 다시 보일 때 받는다', (tester) async {
    final calls = <int>[];
    final signal = ValueNotifier<int>(0);
    await tester.pumpWidget(
      _Host(
        onRefresh: () => calls.add(0),
        gap: const Duration(minutes: 1),
        signals: [signal],
      ),
    );

    await tester.state<_HostState>(find.byType(_Host)).show(false);
    await tester.pump();

    // 결재 한 건에 탭 열두 개가 동시에 요청을 내면 안 된다
    signal.value++;
    await tester.pump();
    await tester.pump();
    expect(calls, isEmpty, reason: '안 보이는 동안에는 안 받는다');

    await tester.state<_HostState>(find.byType(_Host)).show(true);
    await tester.pump();
    await tester.pump();
    expect(calls, hasLength(1), reason: '다시 보이면 간격을 건너뛰고 받는다');
  });

  testWidgets('신호를 안 받았으면 돌아와도 간격을 지킨다', (tester) async {
    final calls = <int>[];
    final signal = ValueNotifier<int>(0);
    await tester.pumpWidget(
      _Host(
        onRefresh: () => calls.add(0),
        gap: const Duration(minutes: 1),
        signals: [signal],
      ),
    );

    // 위 테스트와 같은 흐름인데 **신호만 없다** — 그러면 예전대로 간격을 지킨다
    await tester.state<_HostState>(find.byType(_Host)).show(false);
    await tester.pump();
    await tester.state<_HostState>(find.byType(_Host)).show(true);
    await tester.pump();
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('화면이 사라지면 신호를 놓는다', (tester) async {
    final calls = <int>[];
    final signal = ValueNotifier<int>(0);
    await tester.pumpWidget(
      _Host(onRefresh: () => calls.add(0), signals: [signal]),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    signal.value++;
    await tester.pump();
    expect(calls, isEmpty, reason: '떼지 않으면 죽은 화면이 계속 받는다');

    // `dispose()` 는 리스너가 남아 있어도 안 던진다 — 값이 안 왔다는 것으로만
    // 잰다. 남아 있으면 위 expect 가 이미 걸린다
    signal.dispose();
  });
}

class _Host extends StatefulWidget {
  const _Host({
    required this.onRefresh,
    this.gap = Duration.zero,
    this.signals = const [],
  });

  final VoidCallback onRefresh;
  final Duration gap;
  final List<ValueNotifier<int>> signals;

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
      child: _Screen(
        onRefresh: widget.onRefresh,
        gap: widget.gap,
        signals: widget.signals,
      ),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({
    required this.onRefresh,
    required this.gap,
    required this.signals,
  });

  final VoidCallback onRefresh;
  final Duration gap;
  final List<ValueNotifier<int>> signals;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with ScreenRefresh<_Screen> {
  @override
  Duration get screenRefreshGap => widget.gap;

  @override
  Future<void> onScreenRefresh() async => widget.onRefresh();

  @override
  List<ValueNotifier<int>> get watchSignals => widget.signals;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
