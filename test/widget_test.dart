import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/main.dart';

void main() {
  testWidgets('홈 화면 렌더링 스모크 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(const HiFISApp());

    expect(find.text('오늘 근무 현황'), findsOneWidget);
    expect(find.text('빠른 메뉴'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('최근 활동'), 200);
    expect(find.text('최근 활동'), findsOneWidget);
  });
}
