import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/work/lesson_api.dart';
import 'package:hifis_app/core/api/work/workout_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/features/member/workout_log.dart';

/// 운동일지 적기 — **자판만으로 이어 적히는지**
///
/// 신고: "적는 게 너무 불편하다". 칸마다 손으로 짚어야 했고(`textInputAction`
/// 이 없었다), 줄을 더할 때마다 `운동 추가` 를 누르고 부위를 다시 골라야 했다.
///
/// 여기서는 **손가락을 한 번도 안 대고** 운동 두 줄이 적히는지를 본다.
Employee _me() => Employee(
  id: 'me',
  name: '트레이너',
  email: 'me@test.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: Role.member,
  avatarColor: '#2F54EB',
);

/// 새 개인 운동 일지를 연다 (PT 는 등록권이 있어야 해서 개인으로 본다)
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutLogScreen(
        member: Member(
          id: 'm1',
          name: '이건주',
          phone: '01000000000',
          branchId: 'b1',
          ownerTrainerId: 'me',
          registeredAt: DateTime(2026, 8, 1),
        ),
        kind: WorkoutKind.personal,
        editable: true,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => currentUser = _me());
  tearDown(() => currentUser = null);

  testWidgets('자판 다음 으로 운동명 → 무게 → 횟수 → 다음 줄까지 이어진다', (tester) async {
    await _open(tester);

    // 첫 줄 운동명에 적고 `다음`
    final name1 = find.widgetWithText(TextField, '벤치프레스');
    expect(name1, findsOneWidget, reason: '첫 줄에 보기글이 떠 있어야 한다');
    await tester.enterText(name1, '스쿼트');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // 무게·횟수는 **숫자만** 친다 — 단위는 칸에 붙어 있다
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('회'), findsOneWidget);

    final numbers = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '0',
    );
    await tester.enterText(numbers.first, '80');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(numbers.at(1), '10');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // **줄이 저절로 하나 늘었다** — `운동 추가` 를 안 눌렀다
    expect(find.widgetWithText(TextField, '운동명'), findsOneWidget,
        reason: '다음 줄이 생겨야 한다 (보기글 없는 두 번째 줄)');

    // 이어서 두 번째 운동을 적는다
    await tester.enterText(find.widgetWithText(TextField, '운동명'), '레그프레스');
    await tester.pump();
    expect(find.text('레그프레스'), findsOneWidget);
  });

  testWidgets('빈 줄에서 다음 을 눌러도 줄이 쌓이지 않는다', (tester) async {
    await _open(tester);

    // 아무것도 안 적고 숫자 칸에서 `다음` 을 눌러 본다
    final numbers = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '0',
    );
    await tester.tap(numbers.first);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
    }

    // 줄은 그대로 하나 — 보기글 없는 둘째 줄이 안 생겼다
    expect(find.widgetWithText(TextField, '운동명'), findsNothing);
  });
}
