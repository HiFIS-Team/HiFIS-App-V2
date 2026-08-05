import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../util/platform.dart';
import '../../theme/app_shadows.dart';

/// 잠깐 떠올랐다 사라지는 토스트 알림
///
/// **폰은 아래, 데스크톱은 위에서 뜬다.** 폰은 하단 탭바 위가 손이 닿는
/// 자리라 거기가 맞고, 데스크톱은 아래에 우하단 사내톡 필이 떠 있어서
/// 겹친다 — 게다가 눈이 머무는 곳이 화면 위쪽이다.
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

    // 데스크톱은 창 위쪽(타이틀바 아래), 폰은 하단 탭바 바로 위
    return Positioned(
      left: 20,
      right: 20,
      top: isDesktop ? 28 : null,
      bottom: isDesktop ? null : 104,
      child: IgnorePointer(
        // Material 바깥(Overlay)에서 텍스트에 노란 밑줄이 생기는 것을 막는다
        child: Material(
          type: MaterialType.transparency,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              // 뜨는 자리 쪽에서 밀려 나온다 — 위에서 뜨는데 아래에서
              // 올라오면 어디서 온 건지 안 읽힌다
              position: Tween(
                begin: Offset(0, isDesktop ? -0.4 : 0.4),
                end: Offset.zero,
              ).animate(curved),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    // 카드 톤과 맞춘 흰 캡슐 — 구분은 헤어라인과 그림자로
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gray100),
                    boxShadow: AppShadows.popup,
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
                            color: AppColors.textPrimary,
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
