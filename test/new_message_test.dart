import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/staff_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';
import 'package:hifis_app/features/messages/new_message_screen.dart';

/// 새 사내톡 화면이 명단을 그리고 사람을 고를 수 있는지
///
/// 방 만들기가 안 된다는 신고가 있어서, **명단이 비어 고를 수가 없는 것인지**를
/// 화면 없이 확인한다. 실제 방 생성은 서버가 필요해서 여기서는 안 부른다.
Employee _person(String id, String name) => Employee(
  id: id,
  name: name,
  email: '$id@test.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: Role.member,
  avatarColor: '#2F54EB',
);

void main() {
  testWidgets('새 사내톡 — 명단이 뜨고 고를 수 있다', (tester) async {
    currentUser = _person('me', '나');
    StaffDirectory.instance
      ..employees = [
        currentUser!,
        _person('a', '김트레이너'),
        _person('b', '이점장'),
      ]
      ..branches = [Branch(id: 'b1', name: '화순', type: 'BRANCH')];

    await tester.pumpWidget(MaterialApp(home: NewMessageScreen()));
    await tester.pump();

    // 나는 빠지고 나머지만 뜬다
    expect(find.text('김트레이너'), findsOneWidget);
    expect(find.text('이점장'), findsOneWidget);
    expect(find.text('나'), findsNothing);

    // 아무도 안 골랐으면 '멤버 선택'
    expect(find.text('멤버 선택'), findsOneWidget);

    // 한 명 고르면 '대화하기'로 바뀐다 (= 방 만들기를 누를 수 있는 상태)
    await tester.tap(find.text('김트레이너'));
    await tester.pump();
    expect(find.text('대화하기'), findsOneWidget);

    // 두 명이면 그룹
    await tester.tap(find.text('이점장'));
    await tester.pump();
    expect(find.text('그룹 만들기 (2)'), findsOneWidget);

    StaffDirectory.instance.clear();
    currentUser = null;
  });
}
