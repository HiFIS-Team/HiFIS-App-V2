import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
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
///
/// **머리말 바코드 버튼이 곧장 이걸 연다** (2026-08-28). 예전에는 자기 바코드를
/// 띄우는 창이 먼저 떴는데, 그 바코드를 읽던 카운터 스캐너를 걷어내면서
/// 한 단계가 통째로 뜻을 잃었다.
Future<void> showAttendanceQrScan(BuildContext context) => Navigator.push<void>(
  context,
  // 다른 상세 화면처럼 옆에서 밀려 들어온다 — 아래에서 올라오는 모달로 두면
  // 이 화면만 결이 다르다
  CupertinoPageRoute(builder: (_) => _QrScanScreen()),
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

  /// 카메라 자체를 못 여는 상태 — 권한을 막았거나 카메라가 없다
  ///
  /// **시뮬레이터가 여기 걸린다** (카메라가 아예 없다). 그냥 두면 패키지가
  /// 네모 안에 영어 문구를 그려서 화면이 고장 난 것처럼 보인다.
  bool _noCamera = false;

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
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            // 패키지 기본 화면은 영어라 우리 말로 갈아 끼운다.
            // 여기서 `setState` 를 바로 부르면 빌드 도중이라 터진다 —
            // 값만 세우고 다음 프레임에 알린다
            errorBuilder: (context, error) {
              if (!_noCamera) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _noCamera = true);
                });
              }
              return const SizedBox.shrink();
            },
          ),
          // 찍히면 카메라를 덮는다 — 결과를 보는 자리에서 다음 QR 이 또
          // 물리면 방금 뭘 했는지 못 읽는다
          if (_done != null)
            _result()
          else if (_noCamera)
            _cameraOff()
          else
            _guide(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
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
          CustomPaint(
            size: Size.square(_ScanFrame.side),
            painter: _ScanFrame(),
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

  /// 카메라를 못 열었다 — 권한을 막았거나 (시뮬레이터처럼) 카메라가 없다
  Widget _cameraOff() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_rounded,
                size: 44,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              SizedBox(height: 18),
              Text(
                '카메라를 열 수 없어요',
                textAlign: TextAlign.center,
                style: AppTextStyles.title3.copyWith(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                '설정에서 HiFIS 의 카메라 권한을 켜주세요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
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

/// 조준 규격 — **네 모서리만** 그린다 (2026-08-28 대표 요청)
///
/// 네모를 통째로 두르면 그 선이 QR 테두리처럼 보여서, 카메라가 무엇을 읽는지
/// 헷갈린다. 모서리만 두면 "이 안에 넣어라"는 뜻은 그대로고 화면은 비운다.
///
/// **네 조각을 따로 그리지 않는다.** 한 조각을 만들어 가운데를 축으로 90도씩
/// 돌려 찍는다 — 값을 하나만 고치면 넷이 같이 움직인다.
class _ScanFrame extends CustomPainter {
  /// 규격 한 변 — 여기에 QR 을 채우면 읽힌다
  static const side = 240.0;

  /// 모서리 곡률과 뻗는 길이
  static const _radius = 28.0;
  static const _arm = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      // 끝을 둥글려야 잘린 선처럼 안 보인다
      ..strokeCap = StrokeCap.round;

    // 왼쪽 위 한 조각 — 아래에서 올라와 모서리를 돌아 오른쪽으로 뻗는다
    final corner = Path()
      ..moveTo(0, _radius + _arm)
      ..lineTo(0, _radius)
      ..arcToPoint(Offset(_radius, 0), radius: Radius.circular(_radius))
      ..lineTo(_radius + _arm, 0);

    for (var turn = 0; turn < 4; turn++) {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(turn * math.pi / 2);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
