import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../util/platform.dart';

/// 눌림 피드백 래퍼
///
/// **플랫폼마다 누른 느낌이 다르다.**
///
/// | | 무엇이 보이나 |
/// |---|---|
/// | 애플 · 윈도우 | 살짝 **줄어든다** (선택 시 배경색) — 지금까지와 똑같다 |
/// | 안드로이드 | 누른 자리에서 **물결이 퍼진다** (Material 리플) |
///
/// 안드로이드에서 축소만 주면 iOS 앱을 쓰는 느낌이 난다. 그래서 갈랐는데,
/// **쓰는 쪽 95개 파일은 하나도 안 고쳤다** — 이 안에서만 갈린다.
class Pressable extends StatefulWidget {
  Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.scale = 0.96,
    this.pressedColor,
    this.borderRadius,
    this.padding,
  });

  final VoidCallback onTap;

  /// 꾹 누르기 — 없으면 길게 눌러도 탭과 같다 (기본 동작 그대로)
  final VoidCallback? onLongPress;

  final Widget child;

  /// 눌렸을 때 줄어드는 배율 (**애플·윈도우만**. 안드로이드는 안 줄어든다)
  final double scale;

  /// 눌렸을 때 깔리는 배경색 (없으면 스케일만).
  /// 안드로이드에서는 **물결의 색**으로 쓴다.
  final Color? pressedColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) {
      // 넘겨준 반경이 있으면 그걸 쓰고, 없으면 child 가 칠한 배경에서 알아본다
      final clip = widget.borderRadius != null
          ? (radius: widget.borderRadius, circle: false)
          : rippleClipOf(widget.child);
      return _Ripple(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        tint: widget.pressedColor,
        borderRadius: clip.radius,
        circle: clip.circle,
        padding: widget.padding,
        child: widget.child,
      );
    }

    return MouseRegion(
      // 데스크톱(macOS)에서 눌 수 있는 요소임을 커서로 알려준다
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1.0,
          duration: Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 120),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: _pressed
                  ? (widget.pressedColor ?? Colors.transparent)
                  : Colors.transparent,
              borderRadius: widget.borderRadius,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 물결을 어떤 모양으로 자를지 — [child] 가 제 배경을 어떻게 칠했는지 보고 정한다
///
/// **안 알아보면 둥근 버튼에 네모난 물결이 뜬다.** 실제로 그렇게 나왔다 —
/// 헤더 글래스 버튼(`GlassIconButton` 의 안드로이드 폴백)이 `borderRadius` 가
/// 아니라 **`shape: BoxShape.circle`** 로 그려져 있어서, 전 화면의 동그란
/// 버튼이 누를 때마다 네모로 번쩍였다.
///
/// `borderRadius` 를 안 넘기면서 배경을 칠하는 곳이 75곳이라 호출부를 다 고치는
/// 대신 여기서 알아본다. 못 찾으면 사각형으로 자른다 — 넘치지는 않는다.
typedef RippleClip = ({BorderRadius? radius, bool circle});

const RippleClip _rectClip = (radius: null, circle: false);
const RippleClip _circleClip = (radius: null, circle: true);

@visibleForTesting
RippleClip rippleClipOf(Widget child, [int depth = 0]) {
  if (child is Container) return _fromDecoration(child.decoration);
  if (child is DecoratedBox) return _fromDecoration(child.decoration);
  if (child is ClipOval) return _circleClip;
  if (child is ClipRRect) {
    final radius = child.borderRadius;
    return radius is BorderRadius ? (radius: radius, circle: false) : _rectClip;
  }
  // 배경을 칠하는 위젯이 한 겹 안쪽에 있는 경우가 많다 (여백·정렬로 감싼 것).
  // 깊이는 막아 둔다 — 트리를 끝까지 훑을 일이 아니다.
  if (depth < 2) {
    final inner = switch (child) {
      Padding(:final child) => child,
      SizedBox(:final child) => child,
      Center(:final child) => child,
      Align(:final child) => child,
      _ => null,
    };
    if (inner != null) return rippleClipOf(inner, depth + 1);
  }
  return _rectClip;
}

RippleClip _fromDecoration(Decoration? decoration) {
  if (decoration is! BoxDecoration) return _rectClip;
  if (decoration.shape == BoxShape.circle) return _circleClip;
  final radius = decoration.borderRadius;
  return radius is BorderRadius ? (radius: radius, circle: false) : _rectClip;
}

/// 안드로이드 물결 — 누른 자리에서 퍼진다
///
/// **`InkWell` 을 안 쓴다.** 두 가지가 걸렸다.
///
/// - 물결을 child **아래**에 그리면(`InkWell` 의 제자리) 카드가 제 배경을 칠하는
///   **94곳에서 안 보인다**
/// - 물결을 child **위**에 덮으면(`Stack` 오버레이) 카드 안에 든 버튼이 안 눌린다
///   (**11곳**) — 나중에 그린 형제가 터치를 먼저 가져간다
///
/// 그래서 손짓 처리는 예전 [GestureDetector] 그대로 두고(= 자식이 먼저 받는다),
/// 물결만 [CustomPaint] 의 **foregroundPainter** 로 위에 얹는다. 그리는 것과
/// 누르는 것을 갈라 두 문제를 같이 피한다.
class _Ripple extends StatefulWidget {
  _Ripple({
    required this.onTap,
    required this.onLongPress,
    required this.tint,
    required this.borderRadius,
    required this.circle,
    required this.padding,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? tint;
  final BorderRadius? borderRadius;

  /// 동그란 버튼인가 — [borderRadius] 로는 못 담는 모양이다
  final bool circle;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with TickerProviderStateMixin {
  // Flutter 의 `InkRipple` 과 **같은 값**이다 (material/ink_ripple.dart).
  // 우리가 그리지만 손맛은 안드로이드 기본과 같아야 한다.
  static const _growDuration = Duration(milliseconds: 225);
  static const _fadeInDuration = Duration(milliseconds: 75);
  static const _fadeOutDuration = Duration(milliseconds: 375);

  late final _grow = AnimationController(vsync: this, duration: _growDuration);
  late final _fade = AnimationController(
    vsync: this,
    duration: _fadeInDuration,
  );

  Offset? _center;

  @override
  void dispose() {
    _grow.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _down(TapDownDetails details) {
    setState(() => _center = details.localPosition);
    _grow.forward(from: 0);
    _fade.duration = _fadeInDuration;
    _fade.forward(from: 0);
  }

  /// 손을 뗐다(또는 취소) — 퍼지던 것은 그대로 두고 사라지게만 한다
  void _up() {
    if (!_fade.isDismissed) {
      _fade.duration = _fadeOutDuration;
      _fade.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _up();
                widget.onLongPress!();
              },
        child: CustomPaint(
          foregroundPainter: _RipplePainter(
            center: _center,
            grow: _grow,
            fade: _fade,
            // Material 3 의 눌림 상태 레이어가 12% 다. 뜻이 있는 색을
            // 넘겨줬으면(선택 표시 등) 그 색으로 퍼진다.
            color: (widget.tint ?? AppColors.textPrimary).withValues(
              alpha: 0.12,
            ),
            borderRadius: widget.borderRadius,
            circle: widget.circle,
          ),
          child: padding == null
              ? widget.child
              : Padding(padding: padding, child: widget.child),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.center,
    required this.grow,
    required this.fade,
    required this.color,
    required this.borderRadius,
    required this.circle,
  }) : super(repaint: Listenable.merge([grow, fade]));

  final Offset? center;
  final Animation<double> grow;
  final Animation<double> fade;
  final Color color;
  final BorderRadius? borderRadius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = center;
    if (origin == null || fade.value == 0) return;

    final target = _targetRadius(size, origin);
    final t = Curves.ease.transform(grow.value);
    final radius = target * 0.3 + (target + 5 - target * 0.3) * t;

    canvas.save();
    final bounds = Offset.zero & size;
    final shape = borderRadius;
    if (circle) {
      // `BoxShape.circle` 과 같은 규칙 — 가운데, 반지름은 짧은 변의 절반
      final r = math.min(size.width, size.height) / 2;
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: bounds.center, radius: r)),
      );
    } else if (shape == null) {
      canvas.clipRect(bounds);
    } else {
      canvas.clipRRect(shape.toRRect(bounds));
    }
    canvas.drawCircle(
      origin,
      radius,
      Paint()..color = color.withValues(alpha: color.a * fade.value),
    );
    canvas.restore();
  }

  /// 누른 자리에서 **제일 먼 모서리**까지 — 그래야 끝까지 덮인다
  static double _targetRadius(Size size, Offset center) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.center != center ||
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.circle != circle;
}
