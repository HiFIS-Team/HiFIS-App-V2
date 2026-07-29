import 'package:flutter/material.dart';

/// 눌림 피드백 래퍼 — 누르는 동안 살짝 줄어들고(선택 시 배경색 표시)
/// 떼면 원래 크기로 돌아온다. 앱이 잉크 스플래시를 쓰지 않아
/// 탭 가능한 요소에는 이 래퍼로 눌림 감각을 준다.
class Pressable extends StatefulWidget {
  Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
    this.pressedColor,
    this.borderRadius,
    this.padding,
  });

  final VoidCallback onTap;
  final Widget child;

  /// 눌렸을 때 줄어드는 배율
  final double scale;

  /// 눌렸을 때 깔리는 배경색 (없으면 스케일만)
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
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
    );
  }
}
