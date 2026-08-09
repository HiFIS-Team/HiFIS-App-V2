import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/data/attendance_signal.dart';
import '../../core/data/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_toast.dart';

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

class _BarcodeOverlay extends StatefulWidget {
  _BarcodeOverlay();

  @override
  State<_BarcodeOverlay> createState() => _BarcodeOverlayState();
}

class _BarcodeOverlayState extends State<_BarcodeOverlay> {
  /// 찍혔는지 서버에 물어보는 간격
  ///
  /// 스캔은 **카운터 PC 에서** 일어나서 폰은 그 사실을 모른다. 푸시가 아직
  /// 안 가므로(backend-gap 78번) 바코드를 띄우고 있는 동안만 짧게 물어본다.
  static const _pollEvery = Duration(seconds: 2);

  /// 이만큼 지나면 그만 물어본다 — 켜 둔 채 놔둬도 요청이 계속 나가면 안 된다
  static const _pollFor = Duration(minutes: 2);

  Timer? _timer;
  DateTime? _until;

  /// 열었을 때의 상태 — 이게 바뀌면 방금 찍힌 것이다
  ({DateTime? checkIn, DateTime? checkOut})? _before;
  bool _told = false;

  /// 잇달아 실패한 횟수 — 한 번 튄 것으로 경고를 띄우지 않는다
  int _failures = 0;

  /// 실패를 이미 알렸나 — 2초마다 같은 말을 쌓지 않는다
  bool _warned = false;

  /// 이만큼 잇달아 실패하면 알린다 (2초 × 3 ≈ 6초)
  static const _failuresBeforeWarn = 3;

  @override
  void initState() {
    super.initState();
    _until = DateTime.now().add(_pollFor);
    unawaited(_poll());
    _timer = Timer.periodic(_pollEvery, (_) => unawaited(_poll()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_told || DateTime.now().isAfter(_until!)) {
      _timer?.cancel();
      return;
    }
    final me = currentUser?.id;
    if (me == null) return;

    final today = DateTime.now();
    final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    try {
      final rows = await AttendanceApi.list(employeeId: me, month: month);
      final mine = rows.where(
        (r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day,
      );
      final now = mine.isEmpty
          ? (checkIn: null, checkOut: null)
          : (checkIn: mine.first.checkIn, checkOut: mine.first.checkOut);

      // 물어보는 데 성공했다 — 실패 셈을 되돌린다
      _failures = 0;

      // 첫 응답은 기준값으로만 쓴다 — 어제 찍어 둔 걸 방금 찍힌 것으로
      // 오해하면 안 된다
      if (_before == null) {
        _before = now;
        return;
      }
      if (now == _before) return;

      _told = true;
      _timer?.cancel();
      // 홈의 '오늘 근무' 카드가 따라오게 알린다 — 서로 남남이라
      // 이걸 안 보내면 찍고 홈으로 와도 한동안 '미출근' 그대로다
      notifyAttendanceChanged();
      if (!mounted) return;
      // **토스트를 먼저 띄우고 닫는다.** 토스트는 뿌리 오버레이에 얹히므로
      // 이 화면이 닫혀도 그대로 떠 있다.
      AppToast.show(
        context,
        now.checkOut != null && _before!.checkOut == null ? '퇴근했어요' : '출근했어요',
      );
      // 찍혔으면 바코드를 더 보여 줄 이유가 없다 — 알아서 닫힌다
      Navigator.of(context).pop();
    } catch (error) {
      // 한 번 튄 것은 넘어간다 — 2초마다 묻는 자리라 흔하다.
      // 잇달아 실패하면 **찍혔는지 확인할 수 없다는 것**을 알린다.
      // 가만히 두면 사용자는 안 찍힌 줄도 모르고 계속 대고 있게 된다.
      _failures++;
      if (_warned || _failures < _failuresBeforeWarn || !mounted) return;
      _warned = true;
      AppToast.show(context, '${messageOf(error)} 찍혔는지 확인할 수 없어요');
    }
  }

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
