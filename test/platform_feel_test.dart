// 플랫폼별 손맛 — 안드로이드는 물결·Material 전환, 애플은 예전 그대로
//
// **iOS 가 안 바뀌었다는 것을 여기서 못 박는다.** 애플·윈도우는 코드 경로를
// 아예 안 타야 한다.
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/util/app_route.dart';
import 'package:hifis_app/core/widgets/feedback/app_dialog.dart';
import 'package:hifis_app/core/widgets/input/app_button.dart';
import 'package:hifis_app/core/widgets/input/pressable.dart';

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final apple = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  // ── 누름 감각 ──

  testWidgets('안드로이드 — 물결을 그리고 줄어들지 않는다', (tester) async {
    await tester.pumpWidget(
      wrap(Pressable(onTap: () {}, child: SizedBox(width: 100, height: 40))),
    );

    expect(find.byType(AnimatedScale), findsNothing, reason: '축소는 애플 것');

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.foregroundPainter != null);
    expect(painter, isNotEmpty, reason: '물결은 앞에 그린다');
  }, variant: android);

  testWidgets('애플 — 예전 그대로 줄어든다 (물결 없음)', (tester) async {
    await tester.pumpWidget(
      wrap(Pressable(onTap: () {}, child: SizedBox(width: 100, height: 40))),
    );

    expect(find.byType(AnimatedScale), findsOneWidget);

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);

    await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.96,
      reason: '누르면 줄어드는 것이 애플 손맛',
    );
  }, variant: apple);

  testWidgets('윈도우 — 애플 쪽에 남겨 둔다 (확인할 장비가 없다)', (tester) async {
    await tester.pumpWidget(
      wrap(Pressable(onTap: () {}, child: SizedBox(width: 100, height: 40))),
    );
    expect(find.byType(AnimatedScale), findsOneWidget);
  }, variant: windows);

  // ── 카드 안에 버튼이 든 경우 (11곳이 이 모양이다) ──

  testWidgets('안드로이드 — 카드 안 버튼이 그대로 눌린다', (tester) async {
    var card = 0;
    var inner = 0;

    await tester.pumpWidget(
      wrap(
        Pressable(
          onTap: () => card++,
          child: Container(
            width: 240,
            height: 120,
            color: Color(0xFFEEEEEE),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => inner++,
              child: Container(width: 80, height: 40, color: Color(0xFF2F54EB)),
            ),
          ),
        ),
      ),
    );

    // 안쪽 버튼을 누른다 — 물결이 위에 그려져도 터치는 안쪽이 가져가야 한다
    await tester.tap(find.byType(GestureDetector).last);
    await tester.pumpAndSettle();
    expect(inner, 1, reason: '안쪽 버튼이 먹어야 한다');
    expect(card, 0, reason: '카드가 대신 눌리면 안 된다');

    // 카드의 빈 자리를 누르면 카드가 먹는다
    await tester.tapAt(
      tester.getTopLeft(find.byType(Pressable)) + Offset(8, 8),
    );
    await tester.pumpAndSettle();
    expect(card, 1);
    expect(inner, 1);
  }, variant: android);

  // ── 물결을 자르는 모양 ──
  //
  // 못 알아보면 **둥근 버튼에 네모난 물결**이 뜬다. 실제로 그렇게 나왔다 —
  // 헤더 글래스 버튼이 `borderRadius` 가 아니라 `shape: BoxShape.circle` 이다.

  test('동그란 배경은 원으로 자른다', () {
    expect(
      rippleClipOf(
        DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle)),
      ).circle,
      isTrue,
      reason: 'GlassIconButton 의 안드로이드 폴백이 이 모양이다',
    );
    expect(rippleClipOf(ClipOval(child: SizedBox())).circle, isTrue);
  });

  test('둥근 모서리는 그 반경으로 자른다', () {
    final clip = rippleClipOf(
      Container(
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
    expect(clip.radius, BorderRadius.circular(20));
    expect(clip.circle, isFalse);

    expect(
      rippleClipOf(
        ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox()),
      ).radius,
      BorderRadius.circular(14),
    );
  });

  test('한 겹 감싸도 안쪽 배경을 찾는다', () {
    final clip = rippleClipOf(
      Padding(
        padding: EdgeInsets.all(4),
        child: Container(decoration: BoxDecoration(shape: BoxShape.circle)),
      ),
    );
    expect(clip.circle, isTrue);
  });

  test('못 찾으면 사각형 — 넘치지는 않는다', () {
    final clip = rippleClipOf(Text('그냥 글자'));
    expect(clip.radius, isNull);
    expect(clip.circle, isFalse);
  });

  // ── 되묻는 팝업 ──

  Future<void> openConfirm(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Pressable(
            onTap: () => showConfirmDialog(
              context,
              title: '이 공지를 지울까요?',
              message: '지우면 되돌릴 수 없어요.',
              confirmLabel: '삭제',
              destructive: true,
            ),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();
  }

  testWidgets('안드로이드 — 왼쪽 정렬에 글자 버튼 (Material 3)', (tester) async {
    await openConfirm(tester);

    expect(find.byType(AppButton), findsNothing, reason: '채운 버튼은 애플 것');
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    final title = tester.widget<Text>(find.text('이 공지를 지울까요?'));
    expect(title.textAlign, isNot(TextAlign.center), reason: '제목은 왼쪽');
  }, variant: android);

  testWidgets('애플 — 가운데 정렬에 채운 버튼 둘 (예전 그대로)', (tester) async {
    await openConfirm(tester);

    expect(find.byType(AppButton), findsNWidgets(2));

    final title = tester.widget<Text>(find.text('이 공지를 지울까요?'));
    expect(title.textAlign, TextAlign.center);
  }, variant: apple);

  testWidgets('안드로이드 — 확인을 누르면 true 가 돌아온다', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Pressable(
            onTap: () async {
              answer = await showConfirmDialog(context, title: '지울까요?');
            },
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  }, variant: android);

  // ── 화면 전환 ──

  testWidgets('안드로이드 — Material 전환', (tester) async {
    await tester.pumpWidget(wrap(SizedBox()));
    final route = appRoute((_) => SizedBox());
    expect(route, isA<MaterialPageRoute>());
  }, variant: android);

  testWidgets('애플 — Cupertino 전환 그대로', (tester) async {
    await tester.pumpWidget(wrap(SizedBox()));
    expect(appRoute((_) => SizedBox()), isA<CupertinoPageRoute>());
  }, variant: apple);

  testWidgets('윈도우 — Cupertino 전환 그대로', (tester) async {
    await tester.pumpWidget(wrap(SizedBox()));
    expect(appRoute((_) => SizedBox()), isA<CupertinoPageRoute>());
  }, variant: windows);

  testWidgets('fullscreenDialog 가 넘어간다', (tester) async {
    await tester.pumpWidget(wrap(SizedBox()));
    final route = appRoute((_) => SizedBox(), fullscreenDialog: true);
    expect((route as MaterialPageRoute).fullscreenDialog, isTrue);
  }, variant: android);
}
