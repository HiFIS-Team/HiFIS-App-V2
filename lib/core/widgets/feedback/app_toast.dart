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

  /// 지금 떠 있는 토스트 — 새 토스트가 오면 **이걸 갈아 끼운다**
  ///
  /// 예전에는 지우고 새로 끼웠다. 그러면 떠 있던 것이 **툭 사라졌다가**
  /// 아래에서 다시 올라와서, 페이지를 나가는 순간과 겹치면 토스트가
  /// 페이지를 따라 들어갔다 다시 생기는 것처럼 보였다 (2026-08-31 대표가 짚었다).
  /// 자리를 그대로 두고 글자만 바꾸면 그 깜빡임이 없다.
  static _ToastViewState? _live;

  /// **토스트만 사는 층** — [main.dart] 가 Navigator 위에 하나 깔아 준다
  ///
  /// 예전에는 Navigator 의 오버레이에 끼워 넣었다. 그러면 토스트가 화면들과
  /// **같은 층에서** 움직여서, 뜨는 240ms 와 페이지가 밀려 나가는 전환이
  /// 겹치면 **뜨다 말고 끊겨 보였다** (알림 전체 읽기를 누르고 바로 나갈 때
  /// 실제로 그랬다). 층을 갈라 두면 전환이 이 위젯을 건드리지 않는다.
  ///
  /// 로그아웃 때 Navigator 가 새로 만들어져도 이 층은 그대로다 —
  /// 아래 [_clear] 가 막아 두던 사고도 애초에 안 난다.
  static final overlayKey = GlobalKey<OverlayState>();

  static void show(BuildContext context, String message) {
    // 전용 층이 아직 없으면(테스트 등) 예전처럼 화면 오버레이를 쓴다
    final overlay =
        overlayKey.currentState ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) _insert(overlay, message);
  }

  static void _insert(OverlayState overlay, String message) {
    // 떠 있는 게 있으면 그대로 두고 글자와 시계만 바꾼다
    final live = _live;
    if (live != null && live.mounted) {
      live.replace(message);
      return;
    }
    _clear();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _ToastView(message: message, onDismissed: () => _remove(entry)),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// 떠 있던 토스트를 치운다
  ///
  /// **`mounted` 를 반드시 본다.** 로그아웃하면 Navigator 가 새로 만들어지면서
  /// 오버레이가 통째로 사라지는데, static 인 [_entry] 는 그 참조를 그대로
  /// 들고 있다. 그대로 `remove()` 를 부르면 "이미 지운 걸 또 지운다"고
  /// 터진다 (실제 발생 — 그 예외 때문에 토스트가 아예 안 떴다).
  static void _clear() {
    final old = _entry;
    _entry = null;
    if (old != null && old.mounted) old.remove();
  }

  static void _remove(OverlayEntry entry) {
    if (_entry == entry) _clear();
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

  /// 보여주는 시간 — 내려가는 240ms 는 여기에 안 든다
  static const _hold = Duration(milliseconds: 1800);

  /// 지금 띄우고 있는 글 — [replace] 로 갈린다
  late String _message = widget.message;

  @override
  void initState() {
    super.initState();
    AppToast._live = this;
    _controller.forward();
    _countdown();
  }

  /// 잠시 보여준 뒤 내려가며 사라진다
  void _countdown() {
    _timer?.cancel();
    _timer = Timer(_hold, () async {
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  /// 떠 있는 채로 글만 갈아 끼운다 — 지웠다 새로 끼우면 깜빡인다
  ///
  /// 내려가던 중이었으면 되돌려 올린다. 시계는 처음부터 다시 잰다.
  void replace(String message) {
    setState(() => _message = message);
    _controller.forward();
    _countdown();
  }

  @override
  void dispose() {
    if (AppToast._live == this) AppToast._live = null;
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
        // **일부러 [RepaintBoundary] 를 안 쓴다 (2026-08-31).**
        //
        // 따로 된 층으로 만들면 뒤 화면을 다시 안 칠해도 되지만, iOS 는
        // 글래스 버튼·탭바가 **네이티브 뷰**라 그 위에 얹는 Flutter 층을
        // 페이지가 드나들 때마다 다시 짠다. 그때 따로 선 층이 같이 딸려가서
        // 토스트가 페이지를 따라 들어갔다 다시 생기는 것처럼 보였다.
        // 토스트는 화면 한 귀퉁이라 다시 칠해도 부담이 없다.
        child:
            // Material 바깥(Overlay)에서 텍스트에 노란 밑줄이 생기는 것을 막는다
            Material(
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
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
                              _message,
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
