import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../core/data/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 출퇴근 바코드 오버레이
///
/// 상단 바코드 버튼에서 작게 시작해 화면 가운데로 내려오며 커진다.
/// 배경을 탭하면 닫힌다.
///
/// **매장 스캐너가 읽는 값이 여기 그려지는 사번이다.** 서버는 사번으로 주인을
/// 찾아 출퇴근을 찍는다 (`POST /attendance/scan`).
/// TODO: 실기기 대응 시 오버레이가 열릴 때 화면 밝기 최대화 처리 추가.
Future<void> showAttendanceBarcode(BuildContext context) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Duration(milliseconds: 380),
      reverseTransitionDuration: Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => _BarcodeOverlay(),
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
              begin: Offset(0, -0.35),
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
  _BarcodeOverlay();

  @override
  Widget build(BuildContext context) {
    // 서버가 주는 진짜 사번 — 매장 스캐너가 이 값으로 주인을 찾는다
    // (`POST /attendance/scan` 의 `code`). 예전에는 여기가 고정값이라
    // **누가 찍어도 같은 값이 나갔다.**
    final employeeNo = currentUser?.empNo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 40),
            padding: EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: employeeNo == null || employeeNo.isEmpty
                  // 사번은 가입·직원 추가 때 서버가 반드시 발급하고 옛 계정도
                  // 백필했다 — 여기까지 오는 건 로그인 정보를 아직 못 받은 때다.
                  // 빈 바코드를 그리면 스캐너가 엉뚱한 값을 읽으므로 안 그린다
                  ? [
                      Text(
                        '사번을 불러오지 못했어요',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ]
                  : [
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: employeeNo,
                        height: 96,
                        drawText: false,
                        color: AppColors.gray900,
                      ),
                      SizedBox(height: 14),
                      Text(
                        employeeNo,
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
