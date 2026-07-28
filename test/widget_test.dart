import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/main.dart';

void main() {
  testWidgets('홈 화면 렌더링 스모크 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(HiFISApp());

    expect(find.text('오늘 근무'), findsOneWidget);
    expect(find.text('프로젝트'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('공지'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('공지'), findsOneWidget);
  });
}
