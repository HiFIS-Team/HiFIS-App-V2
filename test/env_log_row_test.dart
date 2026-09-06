import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/work/env_api.dart';

/// 환경정비 기록 줄 — **적어 둔 내용과 추가 점수가 목록에 보이는지**
///
/// 요청 두 가지가 여기로 모인다 (2026-09-06).
/// 1. 클레임해결은 무엇을 해결했는지가 남아야 하고, 그게 목록에서 보여야 한다
/// 2. 대표가 얹은 추가 점수는 **줄만 보고도** 알 수 있어야 한다 —
///    예전에는 창을 열어야만 `기본 3 + 5` 가 보였다
EnvTaskLog _log({
  String itemName = '클레임해결',
  String? note,
  int points = 15,
  int bonus = 0,
}) => EnvTaskLog(
  id: 'log-1',
  employeeId: 'me',
  branchId: 'b1',
  envItemId: 'item-1',
  itemName: itemName,
  points: points,
  createdAt: DateTime(2026, 9, 6, 14, 30),
  note: note,
  bonusPoints: bonus,
);

void main() {
  test('가산점을 받은 줄만 표시가 붙는다', () {
    // 줄에 꼬리표를 붙이는 기준은 **얹어진 점수**이다 — 대표가 보긴 했는데
    // 0 을 준 줄은 붙일 것이 없다
    expect(_log(bonus: 5).bonusPoints != 0, isTrue);
    expect(_log().bonusPoints != 0, isFalse);
  });

  test('총점은 기본 배점에 가산점을 더한 값이다', () {
    expect(_log(points: 3, bonus: 5).totalPoints, 8);
    expect(_log(points: 15).totalPoints, 15);
  });

  test('깎여도 0 밑으로는 안 내려간다', () {
    expect(_log(points: 3, bonus: -10).totalPoints, 0);
  });

  test('클레임해결 기록은 이름이 안 접히고 적은 글이 따로 남는다', () {
    final log = _log(note: '샤워실 온수 민원 — 보일러 교체');
    // 항목별로 세거나 거를 때 한 줄씩 다른 항목이 되면 안 된다
    expect(log.itemName, '클레임해결');
    expect(log.note, '샤워실 온수 민원 — 보일러 교체');
  });

  test('기타는 예전처럼 이름에 접혀 온다', () {
    // 서버가 접어 주는 모양 — 항목 필터는 괄호 앞까지만 보고 걸러야 한다
    final log = _log(itemName: '기타(창고 정리)', note: '창고 정리', points: 1);
    expect(log.itemName.split('(').first, '기타');
  });
}
