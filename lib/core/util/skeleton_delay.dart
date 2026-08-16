import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/feedback/delayed_spinner.dart';

/// 다시 받는 동안 뼈대를 **늦게** 띄운다 — 빨리 오면 아예 안 띄운다
///
/// **왜 필요한가** — 서버가 가까우면 값이 10ms 안에 온다. 그때마다 뼈대를
/// 깔았다 지우면 한두 프레임만 떴다 사라져서 **화면이 깜빡인다.**
/// 달을 옮기고 지점을 바꾸는 자리마다 이 증상이 났다.
///
/// [DelayedSpinner] 가 이미 같은 사정으로 220ms 를 두고 있어서
/// **그 값을 그대로 쓴다** — 앱 안에서 '깜빡임 문턱'이 둘로 갈리면 안 된다.
///
/// ```dart
/// class _FooState extends State<Foo> with SkeletonDelay<Foo> {
///   Future<void> _fetch() async {
///     setState(beginLoad);
///     try {
///       final rows = await Api.list();
///       if (!mounted) return;
///       setState(() {
///         _rows = rows;
///         endLoad();
///       });
///     } catch (error) {
///       if (!mounted) return;
///       setState(endLoad);          // 실패해도 뼈대에 갇히지 않게 푼다
///       AppToast.show(context, messageOf(error));
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) =>
///       showSkeleton ? _Skeleton() : _List(rows: _rows);
/// }
/// ```
///
/// [beginLoad]·[endLoad] 는 **스스로 setState 를 안 한다.** 값을 여러 개 같이
/// 바꾸는 자리가 많아서(`_rows` 와 함께) 부르는 쪽의 setState 안에 넣는다.
///
/// **뼈대를 그리는 동안 옛 내용을 지우지 않는다.** 지우면 그 사이가 빈 화면이라
/// 그것도 깜빡인다 — 옛 줄을 둔 채로 오는 대로 갈아끼우는 게 제일 조용하다.
mixin SkeletonDelay<T extends StatefulWidget> on State<T> {
  /// 뼈대가 한 번 떴으면 **최소 이만큼은 유지한다**
  ///
  /// 개발 서버가 같은 맥이라 값이 10~30ms 만에 온다. 그때 뼈대를 바로 걷으면
  /// 한두 프레임만 떴다 사라져서 **번쩍인다.** 늦게 띄우는 것([DelayedSpinner.delay])
  /// 만으로는 첫 로딩을 못 막는다 — 첫 로딩은 늦추지 않고 바로 띄우기 때문이다.
  ///
  /// 인스타처럼 "떴으면 한 박자는 보이고 사라진다"로 맞춘다.
  static const minVisible = Duration(milliseconds: 300);

  bool _showSkeleton = true;
  bool _loading = true;
  Timer? _skeletonTimer;

  /// 뼈대가 실제로 화면에 뜬 시각 — [minVisible] 을 재는 기준
  DateTime? _shownAt = DateTime.now();

  /// 뼈대를 **실제로 그릴지** — 첫 로딩은 바로, 다시 받을 때는 늦을 때만
  ///
  /// 첫 로딩이 true 로 시작하는 이유는 그때 보여줄 옛 내용이 없어서다.
  /// 늦추면 빈 화면이 잠깐 뜬다 — 늦출 이유가 없는 자리다.
  ///
  /// 열 때 부모가 이미 값을 넘겨주는 화면은 [skipFirstSkeleton] 을 부른다.
  bool get showSkeleton => _showSkeleton;

  /// 요청이 도는 중 — 뼈대와 **다르다.**
  ///
  /// 220ms 안에 오면 뼈대는 안 뜨지만 이 값은 그동안 true 다. 옛 내용에 달린
  /// 버튼을 잠그는 데 쓴다 (누르면 이미 처리된 것을 다시 보내게 되는 자리).
  bool get loading => _loading;

  /// 열 때 이미 값을 갖고 있다 — 뼈대 없이 시작한다
  ///
  /// `initState` 에서 부른다. 부모가 첫 목록을 넘겨주는 화면
  /// (환경정비 내역이 그렇다)만 해당한다.
  void skipFirstSkeleton() {
    _showSkeleton = false;
    _loading = false;
    _shownAt = null;
  }

  /// 받기 시작 — [DelayedSpinner.delay] 를 넘기면 그때 뼈대로 바꾼다
  void beginLoad() {
    _loading = true;
    _skeletonTimer?.cancel();
    if (_showSkeleton) {
      // 이미 떠 있다(첫 로딩) — 언제부터 떠 있었는지를 잃지 않는다
      _shownAt ??= DateTime.now();
      return;
    }
    _skeletonTimer = Timer(DelayedSpinner.delay, () {
      if (!mounted) return;
      setState(() {
        _showSkeleton = true;
        _shownAt = DateTime.now();
      });
    });
  }

  /// 다 받았다(또는 실패) — 뼈대를 걷고 예약도 취소한다
  ///
  /// **뜬 지 [minVisible] 이 안 됐으면 그만큼 미뤄서 걷는다.** 값은 이미
  /// 부르는 쪽 setState 에서 갈아끼워졌으므로, 뼈대만 잠깐 더 덮고 있다가 사라진다.
  void endLoad() {
    _skeletonTimer?.cancel();
    _loading = false;
    if (!_showSkeleton) {
      _shownAt = null;
      return;
    }
    final shownAt = _shownAt;
    final left = shownAt == null
        ? Duration.zero
        : minVisible - DateTime.now().difference(shownAt);
    if (left <= Duration.zero) {
      _showSkeleton = false;
      _shownAt = null;
      return;
    }
    _skeletonTimer = Timer(left, () {
      if (!mounted) return;
      setState(() {
        _showSkeleton = false;
        _shownAt = null;
      });
    });
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }
}
