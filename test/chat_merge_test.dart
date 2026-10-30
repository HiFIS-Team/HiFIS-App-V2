import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/chat/chat_api.dart';
import 'package:hifis_app/features/messages/chat_store.dart';

/// 앱이 뒤에 있다 돌아올 때 **그 사이 메시지를 맞추는** 셈 (2026-10-27)
///
/// 신고: "사내톡 홈 미리보기에 최근 대화가 아니라 그 전 대화가 뜬다".
/// 소켓은 끊긴 동안의 메시지를 다시 안 보내 줘서, 돌아오면 서버에서 최근 것을
/// 다시 받아 들고 있던 것과 합친다. 합치다가 **멀쩡한 메시지를 지우거나**
/// 순서가 꼬이면 안 된다.
final _t0 = DateTime(2026, 10, 27, 9);

ChatMessage _m(String id, int minute, {bool pending = false}) => ChatMessage(
  id: id,
  roomId: 'r',
  senderId: 's',
  body: id,
  createdAt: _t0.add(Duration(minutes: minute)),
  pending: pending,
);

List<String> _ids(List<ChatMessage> rows) => [for (final m in rows) m.id];

void main() {
  test('빠진 메시지를 끼운다 (방 전체가 30개 미만)', () {
    final out = mergeLatestMessages(
      [_m('a', 1), _m('b', 2)],
      [_m('a', 1), _m('b', 2), _m('c', 3), _m('d', 4)],
    );
    expect(_ids(out.messages), ['a', 'b', 'c', 'd']);
    expect(out.hasMore, isNull);
  });

  test('구간 안에서 사라진 것은 뺀다 — 전송 취소', () {
    final out = mergeLatestMessages(
      [_m('a', 1), _m('b', 2), _m('c', 3)],
      [_m('a', 1), _m('c', 3)],
    );
    expect(_ids(out.messages), ['a', 'c']);
  });

  test('받아 온 뒤에 소켓으로 들어온 새 메시지는 지우지 않는다', () {
    final out = mergeLatestMessages(
      [_m('a', 1), _m('b', 2), _m('x', 9)],
      [_m('a', 1), _m('b', 2)],
    );
    expect(_ids(out.messages), ['a', 'b', 'x']);
  });

  test('보내는 중인 내 말풍선은 맨 뒤에 그대로 — 기기 시계가 틀려도', () {
    final out = mergeLatestMessages(
      // 기기 시계가 늦어서 임시 말풍선 시각이 서버 것보다 앞이다
      [_m('a', 1), _m('draft', -100, pending: true)],
      [_m('a', 1), _m('b', 2)],
    );
    expect(_ids(out.messages), ['a', 'b', 'draft']);
  });

  test('사이가 30개를 넘었으면 옛 구간을 버리고 위로 더 받게 한다', () {
    final fresh = [for (var i = 0; i < 30; i++) _m('n$i', 100 + i)];
    final out = mergeLatestMessages([_m('old1', 1), _m('old2', 2)], fresh);
    expect(_ids(out.messages), _ids(fresh));
    expect(out.hasMore, isTrue);
  });

  test('구간이 꽉 차도 겹치면 그 앞의 옛 메시지는 남긴다', () {
    final fresh = [for (var i = 0; i < 30; i++) _m('n$i', 100 + i)];
    final out = mergeLatestMessages([
      _m('old', 50),
      _m('n0', 100),
      _m('n1', 101),
    ], fresh);
    expect(out.messages.first.id, 'old');
    expect(out.messages.length, 31);
    expect(out.hasMore, isNull);
  });

  test('방이 비었으면 보내는 중인 것만 남는다', () {
    final out = mergeLatestMessages([
      _m('a', 1),
      _m('draft', 5, pending: true),
    ], const []);
    expect(_ids(out.messages), ['draft']);
  });

  test('같은 메시지가 두 번 서지 않는다', () {
    final out = mergeLatestMessages(
      [_m('a', 1), _m('b', 2)],
      [_m('a', 1), _m('b', 2)],
    );
    expect(_ids(out.messages), ['a', 'b']);
  });

  test('받아 온 것으로 갈아끼운다 — 읽음 수가 바뀌었다', () {
    final old = _m('a', 1);
    final fresh = old.copyWith(readCount: 3);
    final out = mergeLatestMessages([old], [fresh]);
    expect(out.messages.single.readCount, 3);
  });
}
