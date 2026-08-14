import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 앱이 다시 앞으로 나온 횟수 — 화면들이 이 값을 보고 데이터를 다시 받는다.
///
/// [HiFISApp] 의 생명주기 감시자가 `resumed` 마다 올린다. 화면마다 따로
/// `WidgetsBindingObserver` 를 달면 탭 12개가 각자 관찰자로 등록되므로
/// 한 곳에서 올리고 나머지는 듣기만 한다.
final appResumed = ValueNotifier<int>(0);

/// 화면이 다시 보일 때 조용히 데이터를 다시 받는다
///
/// **왜 필요한가** — `MainShell` 이 `LazyIndexedStack` 으로 탭을 들고 있어서
/// 한 번 연 화면은 탭을 옮겨도 살아 있다. 데이터를 받는 코드가 `initState`
/// 에만 있으면 그 화면은 앱을 껐다 켤 때까지 처음 받은 것을 계속 보여준다
/// (누가 회원가입을 해도 조직도에 안 나타났다).
///
/// 다시 받는 때는 둘이다.
///
/// - **그 탭으로 돌아왔을 때** — `TickerMode` 가 탭마다 켜지고 꺼지므로
///   그 알림을 그대로 쓴다 (`LazyIndexedStack` 이 이미 걸어 둔 것이다).
/// - **앱이 다시 앞으로 나왔을 때** — 지금 보고 있는 탭만 받는다.
///   안 보이는 탭까지 받으면 복귀 한 번에 요청이 12개 나간다.
///
/// **최소 간격**([screenRefreshGap])을 둔다. 데스크톱은 창이 포커스만 잃어도
/// `inactive` 가 되어서, 간격이 없으면 다른 창을 잠깐 볼 때마다 요청이 나간다
/// (홈에서 실제로 겪은 자리다 — `apple/macos.md` 3번).
///
/// **화면에 새로 생기는 요소는 없다.** [onScreenRefresh] 에는 로딩 표시를
/// 켜지 않는 조용한 로드 함수를 준다 — 스켈레톤이 다시 뜨면 탭을 옮길 때마다
/// 화면이 깜빡인다.
mixin ScreenRefresh<T extends StatefulWidget> on State<T> {
  /// 다시 받을 때 부를 것 — 화면이 이미 쓰는 조용한 로드 함수를 그대로 준다
  Future<void> onScreenRefresh();

  /// 이 간격 안에는 다시 받지 않는다
  Duration get screenRefreshGap => const Duration(minutes: 1);

  /// 마지막으로 받은 때 — 화면이 만들어질 때가 곧 첫 로드라 그 시각으로 시작한다
  /// (안 그러면 화면을 열자마자 한 번 더 받는다)
  DateTime _lastAt = DateTime.now();

  /// 이 탭이 지금 보이는가 — `LazyIndexedStack` 의 `TickerMode` 가 알려준다
  ///
  /// `getValuesNotifier` 는 **의존을 만들지 않는다**(`getInheritedWidgetOfExactType`).
  /// 탭이 바뀔 때 화면이 통째로 다시 빌드되지 않고 이 알림만 온다.
  ValueListenable<TickerModeData>? _visible;

  bool get _isVisible => _visible?.value.enabled ?? true;

  @override
  void initState() {
    super.initState();
    appResumed.addListener(_onResumed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (identical(notifier, _visible)) return;
    _visible?.removeListener(_onVisible);
    _visible = notifier..addListener(_onVisible);
  }

  @override
  void dispose() {
    appResumed.removeListener(_onResumed);
    _visible?.removeListener(_onVisible);
    super.dispose();
  }

  /// 이 탭이 지금 보이는가 — 화면이 직접 알아야 할 때 쓴다
  ///
  /// `LazyIndexedStack` 때문에 **탭을 옮겨도 `dispose` 가 안 온다.**
  /// 셸 헤더에 버튼을 얹는 것처럼 화면 밖에 남는 것을 치우려면 이게 필요하다.
  bool get screenVisible => _isVisible;

  /// 보임·가려짐이 바뀌었다 — 기본은 아무것도 안 한다
  void onScreenVisibility(bool visible) {}

  /// 탭이 다시 보이게 됐다 (가려질 때도 불린다)
  void _onVisible() {
    onScreenVisibility(_isVisible);
    if (_isVisible) _refresh();
  }

  /// 앱이 다시 앞으로 나왔다 — 보고 있는 탭만 받는다
  void _onResumed() {
    if (_isVisible) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastAt) < screenRefreshGap) return;
    _lastAt = now;
    // `TickerMode` 알림은 **빌드 도중**에 온다 — 그 자리에서 바로 부르면
    // 로드 함수가 setState 를 만나는 순간 `called during build` 로 터진다.
    // 마이크로태스크는 지금 프레임이 끝난 뒤에 돌아서 안전하다.
    scheduleMicrotask(() {
      if (mounted) onScreenRefresh();
    });
  }
}
