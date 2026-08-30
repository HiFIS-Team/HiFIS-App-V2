/// 받아 본 사진을 파일로 남겨 두는 곳
///
/// `Image.network` 는 **디스크에 안 남긴다.** 메모리 캐시에서 밀려나거나 앱을
/// 껐다 켜면 매번 다시 받아서, 대화를 내릴 때마다 사진이 흰 칸에서 하나씩
/// 튀어나온다. 한 번 받은 것을 파일로 두면 **그다음부터는 바로 뜬다.**
///
/// 패키지를 쓰지 않고 직접 둔 이유는 네 플랫폼을 다 타야 해서다 —
/// 흔히 쓰는 캐시 패키지들은 윈도우 지원이 확실하지 않다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/client/api_client.dart';

abstract final class PhotoCache {
  /// 파일을 두는 곳 — OS 가 지워도 되는 자리다 (지워지면 다시 받는다)
  static Directory? _dir;

  /// 이미 받아 둔 것 — 그릴 때마다 디스크를 뒤지지 않으려고 기억해 둔다
  static final Set<String> _have = {};

  /// 지금 받는 중 — 같은 사진을 두 번 받지 않는다
  /// (격자에 같은 사진이 여러 번 나오거나 화면이 다시 그려질 때)
  static final Map<String, Future<File?>> _busy = {};

  /// 서명(`?exp=..&sig=..`)은 받을 때마다 갈리므로 **경로 끝 이름만** 키로 쓴다.
  /// 서버가 uuid 로 파일을 만들어서 그 자체로 겹치지 않는다
  ///
  /// 밖으로도 연다 — 주소 두 개가 **같은 파일을 가리키는지** 물어보는 자리가
  /// 있다 ([Avatar]). 글자로 비교하면 서명 때문에 매번 다르다고 나온다
  static String keyOf(String url) {
    final path = url.split('?').first;
    final name = path.substring(path.lastIndexOf('/') + 1);
    return name.isEmpty ? '${path.hashCode}' : name;
  }

  static Directory _folder() {
    final made = _dir;
    if (made != null) return made;
    final dir = Directory('${Directory.systemTemp.path}/hifis_photos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dir = dir;
  }

  static File _fileOf(String url) => File('${_folder().path}/${keyOf(url)}');

  /// 받아 둔 파일 — **없으면 null.** 그리기 전에 바로 물어보는 자리라
  /// 기다리지 않는다 (있으면 첫 프레임부터 사진이 뜬다)
  static File? ready(String url) {
    final key = keyOf(url);
    final file = _fileOf(url);
    if (_have.contains(key)) return file;
    if (!file.existsSync()) return null;
    _have.add(key);
    return file;
  }

  /// 받아서 남긴다 — 이미 있으면 그걸 그대로 준다
  static Future<File?> fetch(String url) {
    final key = keyOf(url);
    final done = ready(url);
    if (done != null) return Future.value(done);
    // **[whenComplete] 에 화살표 몸통을 쓰면 안 된다.** `_busy.remove(key)` 가
    // 지금 기다리는 바로 그 Future 를 돌려주는데, [Future.whenComplete] 는
    // 콜백이 Future 를 돌려주면 그게 끝날 때까지 기다린다 — 자기 자신을
    // 기다리게 돼서 **영원히 안 끝난다** (사진 칸이 계속 도는 채로 남았다).
    return _busy[key] ??= _download(url).whenComplete(() {
      _busy.remove(key);
    });
  }

  static Future<File?> _download(String url) async {
    try {
      final bytes = await ApiClient.instance.getBytes(url);
      // 빈 몸으로 200 이 오면 0바이트 파일이 남아 **영원히 회색 칸**이 된다 —
      // [ready] 가 그 파일을 계속 돌려줘서 다시 받을 기회가 없다
      if (bytes.isEmpty) return null;
      final file = _fileOf(url);
      // 받다 말고 끊겼을 때 반쪽짜리 파일이 남지 않게 다 받고 한 번에 쓴다
      await file.writeAsBytes(bytes, flush: true);
      _have.add(keyOf(url));
      return file;
    } catch (_) {
      return null;
    }
  }

  // ── 사진 비율 — 받기 전에 자리를 잡으려고 기억해 둔다 ──
  //
  // 사진은 **다 받아서 풀기 전에는 높이를 모른다.** 그동안 말풍선이 0 높이로
  // 서 있다가 사진이 뜨는 순간 늘어나서, 목록이 통째로 밀린다 — 방에 들어가면
  // 바닥에 붙어 있던 화면이 중간에 서고, 스크롤하면 사진이 뜰 때마다 흔들렸다
  // (2026-08-19). 대화방이 1.5초 동안 바닥을 붙잡고 있는 것도 그 때문이다.
  //
  // 한 번 본 사진은 비율을 적어 두고, 다음부터는 **받기 전에** 그 높이로
  // 자리를 잡는다. 그러면 사진이 떠도 목록이 안 움직인다.
  //
  // 서버가 폭·높이를 안 준다 (`attachments` 가 주소 문자열 목록이다).
  // 주면 처음 보는 사진도 자리를 잡을 수 있다 — backend-gap 에 적어 뒀다.
  static final Map<String, double> _ratio = {};
  static bool _ratioLoaded = false;
  static bool _ratioDirty = false;

  static File get _ratioFile => File('${_folder().path}/ratios.json');

  static void _loadRatios() {
    if (_ratioLoaded) return;
    _ratioLoaded = true;
    try {
      final file = _ratioFile;
      if (!file.existsSync()) return;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      data.forEach((key, value) {
        final ratio = value is num ? value.toDouble() : 0.0;
        if (ratio > 0 && ratio.isFinite) _ratio[key] = ratio;
      });
    } catch (_) {
      // 깨졌으면 없는 셈 친다 — 다시 재면 채워진다
    }
  }

  /// 아는 비율(가로÷세로) — **처음 보는 사진이면 null**
  static double? ratioOf(String url) {
    _loadRatios();
    return _ratio[keyOf(url)];
  }

  /// 방금 푼 사진의 비율을 적어 둔다
  static void remember(String url, double ratio) {
    if (!ratio.isFinite || ratio <= 0) return;
    _loadRatios();
    final key = keyOf(url);
    if (_ratio[key] == ratio) return;
    _ratio[key] = ratio;
    // 사진 여러 장이 한꺼번에 풀리므로 모아서 한 번만 쓴다
    if (_ratioDirty) return;
    _ratioDirty = true;
    Timer(const Duration(seconds: 1), () {
      _ratioDirty = false;
      try {
        _ratioFile.writeAsStringSync(jsonEncode(_ratio));
      } catch (_) {
        // 못 남겨도 이번 실행에서는 메모리 값으로 돈다
      }
    });
  }

  /// 로그아웃할 때 비운다 — 다음 사람에게 남의 사진이 남으면 안 된다
  static void clear() {
    _have.clear();
    _busy.clear();
    _ratio.clear();
    _ratioLoaded = false;
    try {
      final dir = _dir;
      if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // 지우다 실패해도 넘어간다 — 다음에 다시 쓰면 덮인다
    }
    _dir = null;
  }
}
