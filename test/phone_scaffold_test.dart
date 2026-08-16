// 폰 목록 껍데기 — 안드로이드 One UI 접히는 제목 · iOS 는 안 건드림
//
// 슬리버 제목은 **선언한 extent 만큼 위젯이 높이를 채워야** 한다. 안 채우면
// `layoutExtent exceeds paintExtent` 로 죽는데, 그게 `flutter analyze` 로는
// 안 잡히고 화면을 열어야 보인다 (실제로 여기서 잡았다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/widgets/nav/phone_scaffold.dart';

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('필터 있음 — 스크롤하면 제목이 줄어든다', (tester) async {
    await tester.pumpWidget(
      wrap(
        PhoneListScaffold(
          title: '프로젝트',
          count: 12,
          filter: SizedBox(height: 44),
          onCreate: () {},
          children: [for (var i = 0; i < 30; i++) SizedBox(height: 80)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    double titleSize() =>
        tester.widget<Text>(find.text('프로젝트')).style!.fontSize!;

    expect(titleSize(), 28, reason: '펼쳤을 때는 큰 제목');

    await tester.drag(find.byType(CustomScrollView), Offset(0, -300));
    await tester.pumpAndSettle();

    expect(titleSize(), 17, reason: '접히면 앱바 제목 크기');
    expect(find.text('12'), findsOneWidget, reason: '개수는 접혀도 남는다');
  }, variant: android);

  testWidgets('필터 없음 · 개수 없음 — 짧은 목록도 예외 없다', (tester) async {
    await tester.pumpWidget(
      wrap(PhoneListScaffold(title: '근태·월차', children: [SizedBox(height: 40)])),
    );
    await tester.pumpAndSettle();
    expect(find.text('근태·월차'), findsOneWidget);
  }, variant: android);

  testWidgets('좁은 폰(360x640)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        PhoneListScaffold(
          title: '근태·월차',
          count: 999,
          filter: SizedBox(height: 48),
          children: [for (var i = 0; i < 20; i++) SizedBox(height: 80)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), Offset(0, -400));
    await tester.pumpAndSettle();
  }, variant: android);

  testWidgets('iOS 는 예전 그대로 — 슬리버를 안 쓴다', (tester) async {
    await tester.pumpWidget(
      wrap(
        PhoneListScaffold(
          title: '공지',
          count: 3,
          children: [SizedBox(height: 40)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsNothing);
    expect(tester.widget<Text>(find.text('공지')).style!.fontSize, 24);
  }, variant: ios);
}
