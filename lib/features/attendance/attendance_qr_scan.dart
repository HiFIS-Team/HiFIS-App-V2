import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/data/data_signal.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/input/app_button.dart';

/// 출퇴근 QR 찍기 — 매장 카운터에 붙은 종이를 폰으로 읽는다 (2026-08-28)
///
/// **카운터 PC·스캐너를 대신하는 자리다.** 예전에는 직원이 자기 바코드를
/// 띄우고 카운터 기계가 읽었는데, 그 기계가 잠들거나 부팅 중이면 **삑 소리는
/// 나는데 값이 증발했다.** 여기는 찍히는 순간 화면에 뜬다.
///
/// **남을 못 찍는다.** 서버가 QR 을 보낸 사람 본인을 찍으므로, 남의 바코드
/// 화면을 캡처해 대신 찍어 주는 길이 아예 없다 (예전 스캐너에는 있었다).
///
/// 고정 QR 이라 사진을 찍어 두면 어디서든 읽히지만, **서버가 매장 인터넷에서
/// 온 요청인지 본다** — 집이나 LTE 면 `NOT_AT_BRANCH` 로 되돌아온다.
Future<void> showAttendanceQrScan(BuildContext context) => Navigator.push<void>(
  context,
  MaterialPageRoute(fullscreenDialog: true, builder: (_) => _QrScanScreen()),
);

class _QrScanScreen extends StatefulWidget {
  _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _camera = MobileScannerController(
    // 출퇴근 QR 만 읽는다 — 다른 코드까지 열어 두면 엉뚱한 걸 읽고 실패한다
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// 서버에 보내는 중 — 카메라가 같은 QR 을 연달아 물지 않게 잠근다
  bool _busy = false;

  /// 찍힌 결과 — 채워지면 카메라를 덮고 이것만 보여준다
  AttendanceRecord? _done;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _done != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await AttendanceApi.scan(qr: raw);
      if (!mounted) return;
      // 근태·홈 화면이 이 신호를 듣고 있다 — 찍자마자 그쪽이 새 값을 받는다
      notifyAttendanceChanged();
      setState(() {
        _done = record;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(error);
        _busy = false;
      });
    }
  }

  /// 출근인지 퇴근인지 — 퇴근 시각이 찍혔으면 퇴근이다
  String get _what => _done?.checkOut != null ? '퇴근했어요' : '출근했어요';

  String get _stamp {
    final at = _done?.checkOut ?? _done?.checkIn;
    if (at == null) return '';
    final time = at.toLocal();
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$period $hour:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
          // 찍히면 카메라를 덮는다 — 결과를 보는 자리에서 다음 QR 이 또
          // 물리면 방금 뭘 했는지 못 읽는다
          if (_done != null) _result() else _guide(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 카메라 위 안내 — 네모 창과 한 줄
  Widget _guide() {
    return SafeArea(
      child: Column(
        children: [
          Spacer(),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          SizedBox(height: 24),
          Text(
            _busy ? '찍는 중…' : '카운터에 붙은 QR 을 비춰주세요',
            style: AppTextStyles.body1.copyWith(color: Colors.white),
          ),
          if (_error case final message?) ...[
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
          Spacer(),
        ],
      ),
    );
  }

  /// 찍힌 뒤 — **큰 글씨로 결과만.** 이게 이 화면을 만든 이유다
  Widget _result() {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 72, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  _what,
                  style: AppTextStyles.title1.copyWith(color: Colors.white),
                ),
                SizedBox(height: 6),
                Text(
                  _stamp,
                  style: AppTextStyles.title3.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: AppButton(
                    label: '닫기',
                    color: Colors.white,
                    textColor: AppColors.primary,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
