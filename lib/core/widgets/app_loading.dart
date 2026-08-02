import 'package:flutter/material.dart';

/// 마크 로딩 애니메이션
///
/// 마크가 천천히 떠올라 잠깐 머물다가, 떨어지면서 통통 튀며
/// 제자리에 안착하는 동작을 반복한다. 들려 있는 동안 살짝 기울고
/// 바닥 그림자는 높이에 따라 작아진다.
class AppLoading extends StatefulWidget {
  AppLoading({super.key, this.size = 72});

  /// 마크 높이 (논리 픽셀). 폭은 마크 비율([_markRatio])을 따라간다.
  final double size;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

/// 마크 이미지의 가로:세로 (`assets/images/hifis_mark.png` 866×451)
///
/// 마크를 바꾸면 이 값도 같이 고쳐야 한다 — 안 고치면 박스를 넘치거나
/// 그림자가 마크 폭과 어긋난다.
const _markRatio = 1.92;

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2400),
  )..repeat();

  /// 0(바닥)~1(꼭대기) 높이 곡선.
  /// 천천히 들어올림 → 꼭대기에서 잠깐 → 낙하하며 통통(bounceOut) → 바닥에서 잠깐.
  late final _height = _controller.drive(
    TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 42,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 38,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
    ]),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 들어올리는 최대 높이
    final lift = widget.size * 0.55;

    // 레이아웃 박스는 정지 상태의 마크 크기와 같다 — Center에 두면
    // 정지한 마크가 런치 스크린의 마크와 같은 자리에 온다.
    // 들어올리는 동작과 그림자는 박스 밖으로 그려진다.
    return SizedBox(
      width: widget.size * _markRatio,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _height.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // 바닥 그림자 — 마크가 올라갈수록 작아지고 옅어진다
              Positioned(
                bottom: -8,
                child: Container(
                  // 마크 폭보다 조금 좁게 깔리고, 떠오를수록 3분의 1까지 줄어든다
                  width: widget.size * _markRatio * (0.87 - 0.29 * t),
                  height: widget.size * 0.09,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.10 - 0.05 * t),
                    borderRadius: BorderRadius.all(Radius.elliptical(100, 40)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06 - 0.03 * t),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // 마크 — 들려 있는 동안 손잡이를 잡은 듯 살짝 기운다.
              // 낙하 구간에서는 t가 튕기며 0으로 돌아와 기울기도 함께 털린다.
              Positioned(
                bottom: t * lift,
                child: Transform.rotate(angle: t * 0.09, child: child),
              ),
            ],
          );
        },
        child: Image.asset(
          'assets/images/hifis_mark.png',
          height: widget.size,
          // 원본이 크므로 디코드 크기를 제한한다
          cacheHeight: (widget.size * 3).round(),
        ),
      ),
    );
  }
}
