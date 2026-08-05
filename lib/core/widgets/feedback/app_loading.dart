import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 마크 로딩 애니메이션
///
/// 마크는 제자리에 고정이고 색만 왼쪽에서 오른쪽으로 흐른다. 색이 왼쪽부터
/// 빠져 회색만 남았다가 다시 왼쪽부터 차오르기를 반복한다. 반복해서 봐도
/// 눈에 거슬리지 않고, 로고가 오른쪽으로 기운 모양이라 흐르는 방향과도 맞는다.
///
/// **풀컬러에서 시작한다.** 런치 스크린이 색이 다 들어간 마크라, 회색에서
/// 시작하면 앱으로 넘어오는 순간 색이 빠지는 것처럼 깜빡인다.
class AppLoading extends StatefulWidget {
  AppLoading({super.key, this.size = 72});

  /// 마크 높이 (논리 픽셀). 폭은 마크 비율([_markRatio])을 따라간다.
  final double size;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

/// 마크 이미지의 가로:세로 (`assets/images/hifis_mark.png` 866×451)
///
/// 마크를 바꾸면 이 값도 같이 고쳐야 한다 — 안 고치면 박스를 넘친다.
const _markRatio = 1.92;

/// 색이 차고 빠지는 경계의 번짐 폭 (마크 폭 대비)
///
/// 0이면 색이 칼같이 잘려서 딱딱하다. 다만 차오른 폭보다 크면 안 되므로
/// 좁을 때는 그만큼 줄인다.
const _softEdge = 0.14;

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [from]~[to] 구간을 0~1로 펴서 [curve]를 태운다. 구간 밖은 0 또는 1.
  double _segment(double v, double from, double to, Curve curve) {
    if (v <= from) return 0;
    if (v >= to) return 1;
    return curve.transform((v - from) / (to - from));
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.size * _markRatio;

    return SizedBox(
      width: width,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = _controller.value;
          // 한 바퀴: 풀컬러로 잠깐 머물다 → 왼쪽부터 색이 빠지고 →
          // 회색으로 잠깐 → 왼쪽부터 다시 차서 풀컬러로 돌아온다.
          //
          // 색이 남은 구간을 [start, end] 로 잡는다. 빠질 때는 왼쪽 끝이
          // 밀고 들어오고(start↑), 찰 때는 오른쪽 끝이 밀려난다(end↑).
          // 넘어가는 지점이 양쪽 다 '색 없음'이라 끊기지 않는다.
          final draining = v < 0.53;
          final start = draining
              ? _segment(v, 0.10, 0.50, Curves.easeInOutCubic)
              : 0.0;
          final end = draining
              ? 1.0
              : _segment(v, 0.56, 1.00, Curves.easeInOutCubic);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 바탕 — 색을 뺀 마크. 로딩 중에도 형태는 늘 보인다.
              Image.asset(
                'assets/images/hifis_mark.png',
                color: AppColors.gray200,
                colorBlendMode: BlendMode.srcIn,
                cacheHeight: (widget.size * 3).round(),
              ),
              // 차오른 구간만 원래 색으로 덮는다
              if (end - start > 0.001)
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) =>
                      _fillShader(rect, start: start, end: end),
                  child: child,
                ),
            ],
          );
        },
        child: Image.asset(
          'assets/images/hifis_mark.png',
          cacheHeight: (widget.size * 3).round(),
        ),
      ),
    );
  }

  /// [start]~[end] 구간만 남기고 지우는 마스크 — 양 끝은 부드럽게 흐린다
  Shader _fillShader(Rect rect, {required double start, required double end}) {
    // 구간이 번짐 폭보다 좁으면 번짐도 같이 줄인다.
    // 안 그러면 막 차오르기 시작할 때 색이 옅게 뜬 채로 보인다.
    final soft = _softEdge * ((end - start) / _softEdge).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [
        (start - soft).clamp(0.0, 1.0),
        start,
        end,
        (end + soft).clamp(0.0, 1.0),
      ],
    ).createShader(rect);
  }
}
