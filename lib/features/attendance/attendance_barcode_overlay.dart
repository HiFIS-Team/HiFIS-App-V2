import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 출퇴근 바코드 오버레이
///
/// 상단 바코드 버튼에서 작게 시작해 화면 가운데로 내려오며 커진다.
/// 배경을 탭하면 닫힌다. 사번은 목업이며 근태 연동 시 실제 데이터로 교체한다.
/// TODO: 실기기 대응 시 오버레이가 열릴 때 화면 밝기 최대화 처리 추가.
Future<void> showAttendanceBarcode(BuildContext context) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => const _BarcodeOverlay(),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: 0.4, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}

class _BarcodeOverlay extends StatelessWidget {
  const _BarcodeOverlay();

  static const _employeeNo = 'FS-0903';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: _employeeNo,
                  height: 96,
                  drawText: false,
                  color: AppColors.gray900,
                ),
                const SizedBox(height: 14),
                Text(
                  _employeeNo,
                  style: AppTextStyles.label.copyWith(letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
