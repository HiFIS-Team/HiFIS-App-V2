import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/work/lesson_api.dart';
import 'package:hifis_app/core/api/work/workout_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/features/member/workout_log.dart';

/// 무게·횟수 입력 서식 — **숫자만 치고 단위는 칸에 붙어 있다**
///
/// 예전에는 `60kg 12회` 를 한 칸에 통째로 쳤다. 단위까지 손으로 적느라 줄마다
/// 글자를 더 쳤고, 자판이 한글↔숫자를 오갔다.
///
/// 여기서는 셋을 본다.
/// 1. 저장된 `60kg 12회` 가 숫자 두 칸으로 갈려서 뜬다
/// 2. 숫자만 고쳐도 다시 `60kg 12회` 서식으로 합쳐진다
/// 3. 우리 서식이 아닌 옛 줄(`맨몸 15회씩`)은 **건드리지 않고** 한 칸으로 둔다
Employee _me() => Employee(
  id: 'me',
  name: '트레이너',
  email: 'me@test.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: Role.member,
  avatarColor: '#2F54EB',
);

Member _member() => Member(
  id: 'm1',
  name: '이건주',
  phone: '01000000000',
  branchId: 'b1',
  ownerTrainerId: 'me',
  registeredAt: DateTime(2026, 8, 1),
);

WorkoutLog _log(List<WeightRow> weights, {List<CardioRow> cardio = const []}) =>
    WorkoutLog(
      id: 'log-1',
      memberId: 'm1',
      kind: WorkoutKind.personal,
      title: '하체',
      performedOn: DateTime(2026, 9, 1),
      weights: weights,
      cardio: cardio,
    );

Future<void> _open(WidgetTester tester, WorkoutLog log) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutLogScreen(
        member: _member(),
        kind: WorkoutKind.personal,
        editable: true,
        log: log,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 지금 칸에 들어 있는 값들 — 보기글은 안 섞인다
List<String> _typed(WidgetTester tester) => [
  for (final field in tester.widgetList<EditableText>(
    find.byType(EditableText),
  ))
    field.controller.text,
];

void main() {
  setUp(() => currentUser = _me());
  tearDown(() => currentUser = null);

  testWidgets('저장된 60kg 12회 가 숫자 두 칸으로 갈린다', (tester) async {
    await _open(
      tester,
      _log(const [
        WeightRow(part: '하체', name: '스쿼트', load: '60kg 12회', sets: '4'),
      ]),
    );

    // 단위는 칸에 붙박이로 적혀 있다 — 손으로 안 친다
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('회'), findsOneWidget);

    // 값은 숫자만 남는다
    expect(_typed(tester), containsAll(['스쿼트', '60', '12', '4']));
    expect(_typed(tester), isNot(contains('60kg 12회')));
  });

  test('숫자만 고쳐도 60kg 12회 서식으로 합쳐진다', () {
    // 칸 둘을 다시 한 줄로 붙이는 규칙 — 한쪽이 비면 그쪽 단위도 안 붙는다
    expect(joinLoad('60', '12'), '60kg 12회');
    expect(joinLoad('2.5', '20'), '2.5kg 20회');
    expect(joinLoad('', '15'), '15회', reason: '맨몸은 무게가 없다');
    expect(joinLoad('40', ''), '40kg');
    expect(joinLoad('', ''), '');
  });

  testWidgets('우리 서식이 아닌 옛 줄은 한 칸 그대로 둔다', (tester) async {
    await _open(
      tester,
      _log(const [
        WeightRow(part: '전신', name: '푸시업', load: '맨몸 15회씩', sets: '3'),
      ]),
    );

    // 숫자 칸으로 안 바꾼다 — 있는 글을 우리 마음대로 고쳐 쓰지 않는다
    expect(find.text('kg'), findsNothing);
    expect(_typed(tester), contains('맨몸 15회씩'));
  });

  testWidgets('유산소 시간도 숫자만 치고 분 은 칸에 붙어 있다', (tester) async {
    await _open(
      tester,
      _log(const [], cardio: const [CardioRow(name: '트레드밀', duration: '20분')]),
    );

    // 유산소는 아래쪽이라 내려가서 본다
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('분'), findsOneWidget);
    expect(_typed(tester), containsAll(['트레드밀', '20']));
    expect(_typed(tester), isNot(contains('20분')));
  });

  test('서식을 못 알아보면 가르지 않는다', () {
    expect(splitLoad('60kg 12회'), (weight: '60', reps: '12'));
    expect(splitLoad('40kg'), (weight: '40', reps: ''));
    expect(splitLoad('15회'), (weight: '', reps: '15'));
    expect(splitLoad(''), (weight: '', reps: ''));
    expect(splitLoad('맨몸 15회씩'), isNull);
    expect(splitLoad('20kg x 12'), isNull);

    expect(splitMinutes('20분'), '20');
    expect(splitMinutes(''), '');
    expect(splitMinutes('가볍게 20분'), isNull);
  });
}
