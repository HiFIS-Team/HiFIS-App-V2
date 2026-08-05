import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/widgets/feedback/app_loading.dart';
import 'package:hifis_app/main.dart';

/// 앱이 뜨는지만 본다.
///
/// 로그인 상태가 아니면 스플래시를 지나 로그인 화면이 나온다.
/// 예전에는 홈이 바로 뜬다고 보고 '오늘 근무' 를 찾았는데,
/// 홈이 `/me/home` 을 보게 되면서 **로그인 없이는 그 문구가 안 나온다.**
void main() {
  testWidgets('앱을 켜면 스플래시를 지나 로그인 화면이 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(HiFISApp());

    // 런치 스크린에서 이어지는 마크 애니메이션
    expect(find.byType(AppLoading), findsOneWidget);

    // 스플래시는 2.6초 뒤 뒷화면을 만들고 0.42초에 걸쳐 걷힌다.
    // 마크가 계속 도는 애니메이션이라 pumpAndSettle 은 끝나지 않는다
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('다시 만나서 반가워요'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });
}
