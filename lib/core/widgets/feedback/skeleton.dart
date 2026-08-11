import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// 받아오는 동안 자리를 잡아 두는 회색 뼈대 (스켈레톤)
///
/// 가운데 동그라미 하나는 **화면이 통째로 비어 있다가 툭 나타난다.** 뼈대를
/// 미리 깔아 두면 어디에 무엇이 올지가 보여서 같은 시간도 짧게 느껴진다
/// (인스타·토스가 쓰는 방식).
///
/// 반드시 [SkeletonGroup] 안에서 쓴다 — 반짝임을 한 화면에 컨트롤러 하나로
/// 돌리려는 것이라, 밖에 두면 움직이지 않는 회색 면으로만 그려진다
/// (깨지지는 않는다).
class Skeleton extends StatelessWidget {
  Skeleton({super.key, this.width, this.height = 12, this.radius = 6});

  /// null 이면 부모가 주는 만큼 늘어난다
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final wave = SkeletonGroup._of(context);
    final shape = BorderRadius.circular(radius);

    if (wave == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: shape,
        ),
      );
    }

    return AnimatedBuilder(
      animation: wave,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: _sweep(wave.value),
        ),
      ),
    );
  }
}

/// 아바타 자리 — 동그란 뼈대
class SkeletonCircle extends StatelessWidget {
  SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Skeleton(width: size, height: size, radius: size / 2);
}

/// 카드 한 장짜리 뼈대 — 진짜 카드와 같은 껍데기(테두리·모서리·그림자)를 쓴다
///
/// 껍데기가 같아야 다 받아왔을 때 카드가 제자리에서 채워지는 것처럼 보인다.
class SkeletonCard extends StatelessWidget {
  SkeletonCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: AppDecorations.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

/// 반짝임을 굴리는 껍데기 — 뼈대를 쓰는 화면을 이걸로 감싼다
///
/// 컨트롤러가 **화면당 하나**라 뼈대가 몇 개든 같은 박자로 흐른다.
/// [TickerMode] 를 타므로 안 보이는 탭에서는 저절로 멈춘다
/// (탭을 살려 두는 `LazyIndexedStack` 과 같은 약속이다).
class SkeletonGroup extends StatefulWidget {
  SkeletonGroup({super.key, required this.child});

  final Widget child;

  static Animation<double>? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonWave>()?.wave;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1200),
  )..repeat();

  /// 밝은 띠가 왼쪽 밖에서 들어와 오른쪽 밖으로 빠져나가게 여유를 둔다
  late final _wave = Tween(
    begin: -_halo,
    end: 1 + _halo,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonWave(wave: _wave, child: widget.child);
}

class _SkeletonWave extends InheritedWidget {
  _SkeletonWave({required this.wave, required super.child});

  final Animation<double> wave;

  @override
  bool updateShouldNotify(_SkeletonWave old) => old.wave != wave;
}

/// 밝은 띠의 반폭 — 넓을수록 부드럽게 흐른다
const _halo = 0.35;

/// 흐르는 띠 — 바탕 회색 위로 한 단계 밝은 면이 지나간다
///
/// 다크에서는 gray50 이 gray100 보다 **어둡다** (명도가 반전된 팔레트라
/// 그렇다). 밝은 쪽을 골라야 반짝이므로 테마마다 다른 칸을 쓴다.
LinearGradient _sweep(double at) {
  final base = AppColors.gray100;
  final halo = AppColors.isDark ? AppColors.gray200 : AppColors.gray50;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [base, halo, base],
    stops: [
      (at - _halo).clamp(0.0, 1.0),
      at.clamp(0.0, 1.0),
      (at + _halo).clamp(0.0, 1.0),
    ],
  );
}
