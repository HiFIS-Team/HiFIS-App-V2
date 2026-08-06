import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/util/photo.dart';
import 'package:image/image.dart' as img;

/// 사진 줄이기 — 아이폰 원본만 한 크기를 실제로 태워 본다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('photo_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// 아이폰 사진만 한 JPEG 한 장 만들기 (4032×3024 ≈ 12MP)
  String makePhoto(int width, int height, {String name = 'IMG_0001.jpg'}) {
    final image = img.Image(width: width, height: height);
    // 단색이면 JPEG 이 너무 작게 눌려서 실제 사진과 크기가 다르다 — 무늬를 넣는다
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, (x * 7) % 256, (y * 11) % 256, (x ^ y) % 256);
      }
    }
    final path = '${dir.path}/$name';
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 92));
    return path;
  }

  test('12MP 사진을 줄인다', () async {
    final path = makePhoto(4032, 3024);
    final before = File(path).lengthSync();

    final (small, name) = await shrinkPhoto(path, 'IMG_0001.jpg');
    final after = File(small).lengthSync();

    // ignore: avoid_print
    print('원본 ${before ~/ 1024}KB → ${after ~/ 1024}KB ($name)');
    expect(small, isNot(path), reason: '줄인 파일이 따로 나와야 한다');
    expect(after, lessThan(before));

    final out = img.decodeJpg(File(small).readAsBytesSync())!;
    expect(out.width, 1600);
    expect(out.height, 1200);
  });

  test('세로로 긴 사진도 긴 변을 맞춘다', () async {
    final path = makePhoto(3024, 4032, name: 'IMG_0002.jpg');
    final (small, _) = await shrinkPhoto(path, 'IMG_0002.jpg');
    final out = img.decodeJpg(File(small).readAsBytesSync())!;
    expect(out.height, 1600);
    expect(out.width, 1200);
  });

  test('여러 장을 한꺼번에 줄인다', () async {
    final files = [
      for (var i = 0; i < 3; i++)
        (makePhoto(4032, 3024, name: 'IMG_1$i.jpg'), 'IMG_1$i.jpg'),
    ];
    final out = await shrinkPhotos(files);
    expect(out.length, 3);
    for (var i = 0; i < out.length; i++) {
      final (path, name) = out[i];
      expect(File(path).existsSync(), isTrue);
      expect(name, endsWith('.jpg'));
      // 셋 다 실제로 줄어야 한다 — 하나라도 원본이면 그 장만 느려진다
      expect(path, isNot(files[i].$1));
      expect(File(path).lengthSync(), lessThan(File(files[i].$1).lengthSync()));
    }
  });

  test('작은 사진은 그대로 둔다', () async {
    final path = makePhoto(320, 240, name: 'small.png');
    final (same, name) = await shrinkPhoto(path, 'small.png');
    expect(same, path);
    expect(name, 'small.png');
  });
}
