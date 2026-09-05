import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/staff/staff_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';
import 'package:hifis_app/features/work/my_task/my_task_section.dart';

/// 개인 업무 추가 화면이 **지금 로그인한 사람의 근무일**을 도는지
///
/// 신고: "개인업무 추가가 안 된다" — 특정 사람에게만.
///
/// 실제로는 추가가 **되긴 된다.** 다만 앞사람 근무일로 저장돼서 본인 목록에
/// 안 뜬다 (`due_tasks` 가 요일로 거른다). 토·일 근무자가 앞사람(월~금)의
/// 요일로 담으면 **평생 안 보이는 업무**가 생긴다.
///
/// 한 기기를 여럿이 쓰는 자리(센터 데스크)에서 로그아웃 → 다른 사람 로그인이
/// 흔하다. 그래서 로그아웃이 캐시를 열다섯 개나 비우는데(`resetMyTaskCache`
/// 등), 이 값만 `static final` 이라 **비울 수가 없었다.**
Employee _person(String id, String name, List<int> workDays) => Employee(
  id: id,
  name: name,
  email: '$id@test.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: Role.member,
  avatarColor: '#2F54EB',
  workDays: workDays,
);

/// 추가 화면을 열고 첫 요일 칸이 뜰 때까지 기다린다
///
/// 먼저 빈 화면을 한 번 그린다 — 안 그러면 앞서 띄운 화면이 트리에 남아
/// `열기` 버튼이 가려진다 (같은 모양이라 엘리먼트를 재활용한다)
Future<void> _openAdd(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => addMyTasks(context),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    StaffDirectory.instance
      ..employees = const []
      ..branches = [Branch(id: 'b1', name: '화순', type: 'BRANCH')];
  });

  tearDown(() {
    StaffDirectory.instance.clear();
    currentUser = null;
  });

  testWidgets('월~금 근무자는 월요일부터 5칸을 돈다', (tester) async {
    currentUser = _person('a', '평일이', const [1, 2, 3, 4, 5]);
    await _openAdd(tester);

    expect(find.text('월요일'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets(
    '다른 사람으로 바뀌면 그 사람 근무일을 돈다 — 앞사람 것이 남으면 안 된다',
    (tester) async {
      // 앞사람이 먼저 열어 본다 (여기서 값이 굳는 것이 버그였다)
      currentUser = _person('a', '평일이', const [1, 2, 3, 4, 5]);
      await _openAdd(tester);
      expect(find.text('월요일'), findsOneWidget);

      // 로그아웃 → 주말 근무자가 로그인 (앱은 안 껐다 — 한 기기를 여럿이 쓴다)
      currentUser = null;
      currentUser = _person('b', '주말이', const [6, 7]);
      await _openAdd(tester);

      expect(
        find.text('토요일'),
        findsOneWidget,
        reason: '앞사람 근무일(월~금)이 남아 있으면 안 뜬다 — 담은 업무가 본인 목록에서 사라진다',
      );
      expect(find.text('1 / 2'), findsOneWidget);
    },
  );

  testWidgets('근무일을 안 정한 사람은 이레를 다 돈다', (tester) async {
    currentUser = _person('c', '미설정', const []);
    await _openAdd(tester);

    expect(find.text('월요일'), findsOneWidget);
    expect(find.text('1 / 7'), findsOneWidget);
  });
}
