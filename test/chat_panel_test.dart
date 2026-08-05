import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/staff/staff_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';
import 'package:hifis_app/features/messages/message_screen.dart';
import 'package:hifis_app/features/messages/new_message_screen.dart';

/// PC 우하단 사내톡 패널에서 연필(새 채팅)이 실제로 열리는지
///
/// 패널은 380×560 짜리 상자 안에 **자기 내비게이터**를 두고 사내톡을 띄운다
/// (`main_shell.dart` 의 `_ChatDock`). 그 좁은 상자 안에서도 새 대화 화면이
/// 뜨는지를 본다 — 방 만들기가 안 된다는 신고가 이 경로였다.
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
  testWidgets('패널 안에서 연필을 누르면 새 사내톡이 열린다', (tester) async {
    currentUser = _person('me', '나');
    StaffDirectory.instance
      ..employees = [currentUser!, _person('a', '김트레이너')]
      ..branches = [Branch(id: 'b1', name: '화순', type: 'BRANCH')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 380,
              height: 560,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    settings: settings,
                    builder: (_) => MessageScreen(embedded: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 연필 버튼을 찾아 누른다
    final pencil = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().contains('GlassIconButton'),
    );
    expect(pencil, findsWidgets);

    await tester.tap(pencil.last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewMessageScreen), findsOneWidget);
    expect(find.text('김트레이너'), findsOneWidget);

    StaffDirectory.instance.clear();
    currentUser = null;
  });
}
