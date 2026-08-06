/// 올리기 전에 사진을 줄인다
///
/// 아이폰 사진첩이 주는 원본은 12MP 짜리라 한 장이 3~5MB 다. LTE 로 올리면
/// **장당 10초가 넘는다.** 사내톡에 붙는 사진은 말풍선 안에서 220pt,
/// 크게 봐도 화면 폭이라 원본 해상도가 아무 쓸모가 없다.
///
/// **긴 변 [_maxSide] 로 줄이고 JPEG 로 다시 굽는다** — 대개 10배쯤 작아진다.
///
/// 줄이는 값은 화면에서 필요한 것보다 넉넉하게 잡았다. 크게 보기에서 손가락으로
/// 늘려 보는 것까지 생각하면 화면 폭(최대 3배 배율)보다는 커야 한다.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// 긴 변을 이 길이로 맞춘다 (이보다 작은 사진은 그대로 둔다)
const _maxSide = 1600;

/// JPEG 품질 — 80 이면 눈으로는 거의 구분이 안 되고 크기는 크게 준다
const _quality = 80;

/// 이보다 작으면 손대지 않는다 — 줄여 봐야 얼마 안 줄고 시간만 쓴다
const _skipUnder = 400 * 1024;

/// 사진 하나를 줄여 임시 파일로 저장하고 (경로, 이름) 을 돌려준다
///
/// **줄일 수 없으면 원본을 그대로 돌려준다.** 사진이 아니거나(그림 파일이 아닌
/// 것), 이미 작거나, 굽다가 실패하면 원본으로 올린다 — 여기서 막히면
/// 보내는 것 자체가 안 되는데, 그건 느린 것보다 나쁘다.
Future<(String path, String name)> shrinkPhoto(String path, String name) async {
  try {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length <= _skipUnder) return (path, name);

    final resized = await _decodeDown(bytes);
    if (resized == null) return (path, name);

    final jpeg = img.encodeJpg(resized, quality: _quality);
    // 줄인 것이 더 크면(작은 PNG 등) 원본이 낫다
    if (jpeg.length >= bytes.length) return (path, name);

    final out = File(
      '${Directory.systemTemp.path}/'
      'up_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(jpeg);
    return (out.path, _jpegName(name));
  } catch (_) {
    return (path, name);
  }
}

/// 여러 장 — 한꺼번에 줄인다
Future<List<(String, String)>> shrinkPhotos(List<(String, String)> files) =>
    Future.wait([for (final (path, name) in files) shrinkPhoto(path, name)]);

/// **디코딩은 OS 에 맡긴다.** `dart:ui` 가 줄여서 풀어 주는데, 순수 Dart 로
/// 12MP 를 푸는 것보다 몇 배 빠르다. 굽는 것만 Dart 로 한다.
///
/// 크기는 [ui.ImageDescriptor] 로 **풀기 전에** 읽는다 — 재려고 한 번 풀고
/// 줄이려고 또 푸는 것을 피한다.
Future<img.Image?> _decodeDown(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final long = descriptor.width > descriptor.height
      ? descriptor.width
      : descriptor.height;
  final scale = long > _maxSide ? _maxSide / long : 1.0;

  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  descriptor.dispose();
  buffer.dispose();

  final frame = await codec.getNextFrame();
  final image = frame.image;
  // 크기는 버리기 전에 챙긴다 — dispose 한 뒤에는 못 읽는다
  final width = image.width;
  final height = image.height;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  codec.dispose();
  if (data == null) return null;

  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: data.buffer,
    numChannels: 4,
  );
}

/// `IMG_1234.HEIC` → `IMG_1234.jpg` — 내용이 JPEG 이 됐으니 이름도 맞춘다
/// (서버가 확장자로 종류를 가리고, 앱도 확장자로 사진인지 본다)
String _jpegName(String name) {
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  return '$stem.jpg';
}
