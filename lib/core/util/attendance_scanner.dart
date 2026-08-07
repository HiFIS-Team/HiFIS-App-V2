import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../api/client/api_exception.dart';
import '../api/staff/attendance_api.dart';
import '../data/staff_directory.dart';
import '../widgets/feedback/app_toast.dart';
import 'platform.dart';

/// 지점 출퇴근 스캐너 — 배경에서 시리얼 포트를 듣는다
///
/// **화면이 없다.** 지점 PC 는 회원 등록 같은 다른 일에도 같이 쓰는 컴퓨터라,
/// 직원이 무슨 화면을 보고 있든 누가 바코드를 대면 찍혀야 한다. 그래서
/// 스캐너를 **키보드(HID)가 아니라 시리얼(USB CDC)** 로 붙인다 —
/// 키보드 모드는 포커스 잡힌 입력칸이 있어야 값이 들어와서, 포커스가
/// 없으면 **사번이 회원 등록 폼에 그대로 타이핑된다.**
///
/// 흐름은 이렇다.
///
/// ```
/// 직원 폰의 사번 바코드  →  스캐너(USB CDC)  →  COM/tty 포트
///   →  이 클래스가 한 줄씩 끊어  →  POST /attendance/scan  →  토스트
/// ```
///
/// **확인된 기기 (2026-08-07, JYK-EP8280J)**
///
/// | | |
/// |---|---|
/// | 윈도우 | 드라이버 없이 `COM3` |
/// | macOS | 드라이버 없이 `/dev/cu.usbmodem*` |
/// | 통신 | 9600 · 8N1 |
/// | 터미네이터 | `0A` (LF) |
/// | 값 | 사번 그대로 (`2026-0004`) |
/// | 대고 있을 때 | 한 번만 읽는다 (스캐너가 자체적으로 막는다) |
///
/// 스캐너를 다른 것으로 바꾸면 [_looksLikeScanner] 의 조건만 늘리면 된다.
class AttendanceScanner {
  AttendanceScanner._();

  /// 같은 사번이 이 시간 안에 또 오면 버린다
  ///
  /// 스캐너는 재읽기를 안 하지만 **직원이 "안 찍혔나?" 하고 두 번 대는 것**은
  /// 못 막는다. 서버의 `/attendance/scan` 은 토글이라 두 번 들어오면
  /// 출근 찍고 바로 퇴근이 된다.
  ///
  /// 너무 길게 잡으면 안 된다 — 출근하고 곧바로 나가야 하는 사람이
  /// 퇴근을 못 찍는다.
  static const _repeatWindow = Duration(seconds: 10);

  /// 포트가 없거나 끊겼을 때 다시 찾아보는 간격
  static const _retryEvery = Duration(seconds: 5);

  static SerialPort? _port;
  static SerialPortReader? _reader;
  static StreamSubscription<Uint8List>? _sub;
  static Timer? _retry;

  /// 사번 → 마지막으로 서버에 보낸 시각
  static final _lastSent = <String, DateTime>{};

  /// 아직 줄 끝(LF)을 못 만난 조각
  static String _buffer = '';

  static bool _running = false;

  /// 로그인했을 때 켠다 — **데스크톱에서만 돈다**
  ///
  /// 폰에는 스캐너를 꽂을 일이 없고, 시리얼 패키지도 데스크톱 전용이다.
  static void start() {
    if (!isDesktop || _running) return;
    _running = true;
    debugPrint('[스캐너] 시작');
    _open();
  }

  /// 로그아웃하거나 앱을 닫을 때 끈다
  static Future<void> stop() async {
    _running = false;
    _retry?.cancel();
    _retry = null;
    await _sub?.cancel();
    _sub = null;
    _reader?.close();
    _reader = null;
    final port = _port;
    _port = null;
    if (port != null && port.isOpen) port.close();
    port?.dispose();
    _buffer = '';
    _lastSent.clear();
  }

  /// 스캐너로 보이는 포트를 찾아 연다. 없으면 [_retryEvery] 뒤에 다시 본다.
  ///
  /// 안 될 때 원인을 알 길이 없으면 지점 PC 에서 손을 못 쓴다. 그래서
  /// 단계마다 로그를 남긴다 (`flutter logs` 나 콘솔에서 `[스캐너]` 로 찾는다).
  static void _open() {
    if (!_running) return;
    _retry?.cancel();

    final port = _find();
    if (port == null) {
      debugPrint(
        '[스캐너] 못 찾음 — 붙어 있는 포트: ${SerialPort.availablePorts.join(", ")}',
      );
      _retry = Timer(_retryEvery, _open);
      return;
    }

    try {
      if (!port.openRead()) {
        debugPrint('[스캐너] ${port.name} 열기 실패 — ${SerialPort.lastError}');
        port.dispose();
        _retry = Timer(_retryEvery, _open);
        return;
      }
      debugPrint('[스캐너] ${port.name} 연결됨');
      final config = port.config
        ..baudRate = 9600
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1;
      port.config = config;
      config.dispose();

      _port = port;
      _reader = SerialPortReader(port);
      _sub = _reader!.stream.listen(
        _onBytes,
        // 케이블이 빠지면 스트림이 끊긴다 — 다시 꽂으면 이어지도록 다시 찾는다
        onError: (_) => _reopen(),
        onDone: _reopen,
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('[스캐너] ${port.name} 여는 중 예외 — $error');
      port.dispose();
      _retry = Timer(_retryEvery, _open);
    }
  }

  static void _reopen() {
    if (!_running) return;
    unawaited(
      stop().then((_) {
        _running = true;
        _retry = Timer(_retryEvery, _open);
      }),
    );
  }

  /// 붙어 있는 시리얼 장치 중 스캐너를 고른다
  ///
  /// **아무 포트나 열면 안 된다** — 블루투스나 다른 장비의 포트를 열어
  /// 그 기기를 방해할 수 있다.
  static SerialPort? _find() {
    for (final name in SerialPort.availablePorts) {
      final port = SerialPort(name);
      if (_looksLikeScanner(port)) return port;
      port.dispose();
    }
    return null;
  }

  static bool _looksLikeScanner(SerialPort port) {
    try {
      // 확인된 기기 — JYK-EP8280J 는 'DECODER_CDC' 로 잡힌다
      if (port.vendorId == 0x04D8 && port.productId == 0x000A) return true;
      final tag = [
        port.productName,
        port.description,
        port.manufacturer,
      ].whereType<String>().join(' ').toUpperCase();
      return tag.contains('DECODER') ||
          tag.contains('BARCODE') ||
          tag.contains('SCANNER');
    } catch (_) {
      // 열어보기 전에는 정보를 못 읽는 포트도 있다 — 그런 건 건드리지 않는다
      return false;
    }
  }

  /// 들어온 바이트를 줄 단위로 끊는다 (터미네이터 `0A`, `0D` 도 함께 받아 준다)
  static void _onBytes(Uint8List bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final index = _buffer.indexOf(RegExp(r'[\r\n]'));
      if (index < 0) break;
      final line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);
      if (line.isNotEmpty) {
        debugPrint('[스캐너] 읽음 — $line');
        unawaited(_send(line));
      }
    }
    // 터미네이터가 영영 안 오는 쓰레기가 쌓이지 않게 자른다
    if (_buffer.length > 128) _buffer = '';
  }

  static Future<void> _send(String code) async {
    final now = DateTime.now();
    final last = _lastSent[code];
    if (last != null && now.difference(last) < _repeatWindow) return;
    _lastSent[code] = now;

    // **알리는 것은 try 밖에서 한다.** 안에서 부르면 알림이 실패했을 때
    // catch 로 떨어져 "스캔이 실패했다"고 잘못 알리게 된다 (실제 발생).
    String message;
    try {
      final record = await AttendanceApi.scan(code: code);
      final name = StaffDirectory.instance.byId(record.employeeId)?.name;
      final what = record.checkOut == null ? '출근' : '퇴근';
      message = name == null ? what : '$name $what';
    } catch (error) {
      // 실패했으면 막아두지 않는다 — 바로 다시 댈 수 있어야 한다
      _lastSent.remove(code);
      message = messageOf(error);
    }
    AppToast.showGlobal(message);
  }
}
