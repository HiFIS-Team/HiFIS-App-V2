import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 스크롤 오프셋 → 상단 블러 세기(0~1)
///
/// 이 값을 State 필드로 두고 setState로 갱신하면 스크롤 한 프레임마다
/// 화면 전체(목록 항목 전부)가 새로 만들어져 버벅인다. 값만 알림으로 흘려서
/// [TopFrost]만 다시 그리게 한다.
class ScrollCollapse extends ValueNotifier<double> {
  ScrollCollapse({this.start = 30, this.distance = 30}) : super(0);

  /// 흐려지기 시작하는 오프셋
  final double start;

  /// 최대로 흐려질 때까지 스크롤해야 하는 거리
  final double distance;

  void update(double pixels) {
    value = ((pixels - start) / distance).clamp(0.0, 1.0);
  }
}

/// 스크롤 시 화면 상단에 생기는 프로그레시브 블러
///
/// Stack의 상단 레이어로 두고, 본문 스크롤에 연결한 [ScrollCollapse]를
/// 넘겨서 사용한다. color는 화면 배경색과 맞춘다.
class TopFrost extends StatelessWidget {
  TopFrost({super.key, required this.collapse, required this.color});

  /// 0이면 투명, 1이면 완전히 흐려진 상태.
  final ValueListenable<double> collapse;

  /// 스크롤과 상관없이 늘 흐려 있는 화면용
  static const ValueListenable<double> always = _Fixed(1);

  /// 그라데이션에 사용할 화면 배경색.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: collapse,
        builder: (context, value, _) => ClipRect(
          child: BackdropFilter(
            // sigma 0은 렌더링 오류가 나므로 최소값을 둔다
            filter: ImageFilter.blur(
              sigmaX: 20 * value + 0.01,
              sigmaY: 20 * value + 0.01,
            ),
            child: Container(
              height: topInset + 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.85 * value),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 값이 안 바뀌는 리스너블 — 알림을 보낼 일이 없어 듣는 쪽도 다시 그리지 않는다
class _Fixed implements ValueListenable<double> {
  const _Fixed(this.value);

  @override
  final double value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
