import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/features/documents/document_screen.dart';

/// 문서함 오른쪽 아래 알약이 **겹쳐도 안 껌뻑이는지**
///
/// 예전에는 올리기만 겹침을 세고 **받기는 단순 bool** 이었다. 파일 둘을
/// 잇따라 받으면 먼저 끝난 쪽이 알약을 내려서 **아직 받는 중인데 사라졌다.**
/// 눈으로는 잘 안 잡히는 종류라 여기서 못 박는다.
void main() {
  test('아무것도 안 하면 알약이 없다', () {
    expect(BusyLabel().value, isNull);
  });

  test('올리기가 겹쳐도 끝까지 남는다', () {
    final busy = BusyLabel();
    // 폴더째 놓으면 폴더 만들기 + 폴더마다 파일 올리기가 중첩된다
    busy.beginUpload();
    busy.beginUpload();
    expect(busy.value, '올리는 중…');

    busy.endUpload();
    expect(busy.value, '올리는 중…', reason: '하나 끝났다고 내리면 안 된다');

    busy.endUpload();
    expect(busy.value, isNull);
  });

  test('받기가 겹쳐도 끝까지 남는다 — 예전에 껌뻑이던 자리다', () {
    final busy = BusyLabel();
    busy.beginDownload();
    busy.beginDownload();
    busy.endDownload();
    expect(busy.value, '받는 중…', reason: '먼저 끝난 쪽이 알약을 내리면 안 된다');

    busy.endDownload();
    expect(busy.value, isNull);
  });

  test('둘이 겹치면 올리는 중으로 적는다', () {
    final busy = BusyLabel();
    busy.beginDownload();
    busy.beginUpload();
    expect(busy.value, '올리는 중…');

    // 올리기가 끝나면 남은 받기로 내려온다
    busy.endUpload();
    expect(busy.value, '받는 중…');
  });

  test('값이 바뀔 때만 알린다 — 알약이 헛되이 다시 그려지지 않는다', () {
    final busy = BusyLabel();
    var calls = 0;
    busy.addListener(() => calls++);

    busy.beginUpload();
    busy.beginUpload(); // 라벨이 그대로라 알림이 없다
    expect(calls, 1);

    busy.endUpload();
    expect(calls, 1);

    busy.endUpload();
    expect(calls, 2);
  });

  test('화면이 사라진 뒤에 끝나도 던지지 않는다', () {
    // 받는 도중에 탭을 옮기면 끝나는 시점에 이미 dispose 된 뒤다
    final busy = BusyLabel()..beginDownload();
    busy.dispose();
    expect(busy.endDownload, returnsNormally);
  });
}
