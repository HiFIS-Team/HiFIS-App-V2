import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 하단 탭바 위로 잠깐 떠오르는 토스트 알림 (배경 반전 캡슐)
///
/// 사용: `AppToast.show(context, '세탁을 완료했습니다')`
/// 새 토스트가 뜨면 이전 토스트는 즉시 교체된다.
abstract final class AppToast {
  static OverlayEntry? _entry;

  static void show(BuildContext context, String message) {
    final old = _entry;
    _entry = null;
    old?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _ToastView(message: message, onDismissed: () => _remove(entry)),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (_entry == entry) {
      _entry = null;
      entry.remove();
    }
  }
}

class _ToastView extends StatefulWidget {
  _ToastView({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 240),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // 잠시 보여준 뒤 내려가며 사라진다
    _timer = Timer(Duration(milliseconds: 1800), () async {
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    return Positioned(
      left: 20,
      right: 20,
      // 하단 탭바 바로 위
      bottom: 104,
      child: IgnorePointer(
        // Material 바깥(Overlay)에서 텍스트에 노란 밑줄이 생기는 것을 막는다
        child: Material(
          type: MaterialType.transparency,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: Offset(0, 0.4),
                end: Offset.zero,
              ).animate(curved),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    // 배경 반전: 라이트에선 짙은 캡슐, 다크에선 밝은 캡슐
                    color: AppColors.gray900.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 16,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
