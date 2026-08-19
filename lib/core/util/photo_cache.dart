/// 받아 본 사진을 파일로 남겨 두는 곳
///
/// `Image.network` 는 **디스크에 안 남긴다.** 메모리 캐시에서 밀려나거나 앱을
/// 껐다 켜면 매번 다시 받아서, 대화를 내릴 때마다 사진이 흰 칸에서 하나씩
/// 튀어나온다. 한 번 받은 것을 파일로 두면 **그다음부터는 바로 뜬다.**
///
/// 패키지를 쓰지 않고 직접 둔 이유는 네 플랫폼을 다 타야 해서다 —
/// 흔히 쓰는 캐시 패키지들은 윈도우 지원이 확실하지 않다.
library;

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
    return _busy[key] ??= _download(url).whenComplete(() => _busy.remove(key));
  }

  static Future<File?> _download(String url) async {
    try {
      final bytes = await ApiClient.instance.getBytes(url);
      final file = _fileOf(url);
      // 받다 말고 끊겼을 때 반쪽짜리 파일이 남지 않게 다 받고 한 번에 쓴다
      await file.writeAsBytes(bytes, flush: true);
      _have.add(keyOf(url));
      return file;
    } catch (_) {
      return null;
    }
  }

  /// 로그아웃할 때 비운다 — 다음 사람에게 남의 사진이 남으면 안 된다
  static void clear() {
    _have.clear();
    _busy.clear();
    try {
      final dir = _dir;
      if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // 지우다 실패해도 넘어간다 — 다음에 다시 쓰면 덮인다
    }
    _dir = null;
  }
}
