import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/api/notice/reaction_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/theme/app_colors.dart';
import 'package:hifis_app/features/messages/chat_screen.dart';

/// 사내톡 공감(리액션) — **운영에서 실제로 나오는 경우들을 다 세워 본다.**
///
/// 2026-09-07 대표 지적 셋을 여기서 잡아 둔다.
/// 1. 알약이 화면 폭만큼 늘어나 이모지 하나가 가운데 떠 있었다
///    (범인은 [Container] 의 `alignment` — 값이 있으면 부모 폭을 꽉 채운다)
/// 2. 뺄 길이 숨어 있었다 → 알약을 누르면 토글, 꾹 누르면 누가 눌렀는지
/// 3. 한 사람이 한 말풍선에 여러 개를 달 수 있었다 → 서버가 하나로 묶는다
///    (`app/services/reactions.py` `ONE_PER_PERSON`) — 앱은 그 집계를 그린다

/// 알약 줄이 실제로 놓이는 자리와 같은 폭 — 상대 말풍선은 프로필 자리(52)만큼
/// 들어와서 선다
const _rowWidth = 360.0 - 52;

/// 앱과 **같은 사정**으로 놓는다 — 말풍선 아래 줄은 [Align] 안이라
/// 폭이 넉넉하되(최대 [_rowWidth]) 느슨한 제약이 내려온다.
///
/// 꽉 조인 제약(`SizedBox(width:)`)으로 감싸면 알약이 그 폭이 되는 게 당연해서
/// 정작 재려는 것(제 크기로 줄어드나)을 못 본다.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _rowWidth),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

Employee _person(String id) => Employee(
  id: id,
  name: id,
  email: '$id@hifis.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: Role.member,
  avatarColor: '#4C6FFF',
);

/// 알약 한 장의 실제 크기 (팝 애니메이션이 끝난 뒤)
Size _pillSize(WidgetTester tester, {int at = 0}) => tester.getSize(
  find
      .descendant(
        of: find.byType(ChatReactionPill),
        matching: find.byType(Container),
      )
      .at(at),
);

void main() {
  tearDown(() => currentUser = null);

  group('알약 한 장', () {
    testWidgets('내용만큼만 넓다 — 화면 폭을 채우지 않는다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatReactionPill(
            emoji: '❤️',
            count: 1,
            pressed: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pill = _pillSize(tester);
      expect(pill.height, 26);
      // 이모지 자리 16 + 좌우 여백 9×2 + 테두리 1×2 = 36.
      // **고쳐지기 전에는 308(줄 폭 전체)이었다.**
      expect(pill.width, 36);
      expect(pill.width, lessThan(_rowWidth / 4));
    });

    testWidgets('여러 명이 같은 것을 누르면 수가 붙는다 (그래도 짧다)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatReactionPill(
            emoji: '❤️',
            count: 12,
            pressed: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      // 테스트 글꼴은 글자 하나가 네모 한 칸이라 실제보다 넓게 잡힌다 —
      // 그래도 줄 폭(308)에 견주면 한참 짧다
      expect(_pillSize(tester).width, lessThan(70));
    });

    testWidgets('한 명만 누르면 수를 안 적는다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatReactionPill(
            emoji: '❤️',
            count: 1,
            pressed: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
    });

    testWidgets('누르면 토글, 꾹 누르면 누가 눌렀는지', (tester) async {
      var toggled = 0;
      var asked = 0;
      await tester.pumpWidget(
        _wrap(
          ChatReactionPill(
            emoji: '❤️',
            count: 1,
            pressed: true,
            onTap: () => toggled++,
            onLongPress: () => asked++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ChatReactionPill));
      expect((toggled, asked), (1, 0));

      await tester.longPress(find.byType(ChatReactionPill));
      expect((toggled, asked), (1, 1));
    });
  });

  group('알약 줄', () {
    /// 남이 누른 것은 안 물들고, 내가 누른 것만 파랗다 — 뺄 수 있다는 표시다
    testWidgets('내가 누른 것만 물든다', (tester) async {
      currentUser = _person('me');
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: [
              ReactionAgg(emoji: '❤️', employeeIds: ['me', 'other']),
              ReactionAgg(emoji: '😂', employeeIds: ['other']),
            ],
            mine: false,
            onToggle: (_) {},
            onWho: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pills = tester.widgetList<ChatReactionPill>(
        find.byType(ChatReactionPill),
      );
      expect(pills.length, 2);
      // 많이 눌린 ❤️(2명)가 앞, 😂(1명)가 뒤
      expect(pills.map((p) => p.emoji).toList(), ['❤️', '😂']);
      expect(pills.map((p) => p.pressed).toList(), [true, false]);
    });

    testWidgets('남의 말풍선에 남들만 눌렀으면 하나도 안 물든다', (tester) async {
      currentUser = _person('me');
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: [
              ReactionAgg(emoji: '👍', employeeIds: ['a', 'b', 'c']),
            ],
            mine: false,
            onToggle: (_) {},
            onWho: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ChatReactionPill>(
        find.byType(ChatReactionPill),
      ).pressed, isFalse);
      expect(find.text('3'), findsOneWidget);
    });

    /// 많이 눌린 것부터 선다 — 서버가 주는 차례는 행이 쌓인 순서라
    /// 다시 받을 때마다 달라질 수 있다 (알약이 자리를 바꾸면 다시 찾아야 한다)
    testWidgets('여러 사람이 여러 이모지를 달아도 차례가 흔들리지 않는다', (tester) async {
      final reactions = [
        ReactionAgg(emoji: '😢', employeeIds: ['a']),
        ReactionAgg(emoji: '🔥', employeeIds: ['a', 'b', 'c']),
        ReactionAgg(emoji: '❤️', employeeIds: ['a', 'b']),
      ];
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: reactions,
            mine: false,
            onToggle: (_) {},
            onWho: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<ChatReactionPill>(find.byType(ChatReactionPill))
            .map((p) => p.emoji)
            .toList(),
        ['🔥', '❤️', '😢'],
      );

      // 순서만 바꿔 다시 받아도 화면 차례는 그대로다
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: reactions.reversed.toList(),
            mine: false,
            onToggle: (_) {},
            onWho: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<ChatReactionPill>(find.byType(ChatReactionPill))
            .map((p) => p.emoji)
            .toList(),
        ['🔥', '❤️', '😢'],
      );
    });

    /// 고를 수 있는 이모지가 여섯 종이라 **한 말풍선에 최대 여섯 줄**이다.
    /// 다 붙어도 폰 폭 안에 들어가야 한다 (넘치면 노란 빗금이 뜬다)
    testWidgets('여섯 종이 다 붙어도 안 넘친다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: [
              for (final emoji in ['❤️', '😂', '👍', '😮', '😢', '🔥'])
                ReactionAgg(emoji: emoji, employeeIds: ['a', 'b']),
            ],
            mine: false,
            onToggle: (_) {},
            onWho: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ChatReactionPill), findsNWidgets(6));
      final row = tester.getSize(find.byType(ChatReactionPills));
      expect(row.width, lessThanOrEqualTo(_rowWidth));
      // 넘치면 아랫줄로 내려간다 ([Wrap]) — 두 줄까지가 한계다.
      // 글꼴이 바뀌어 몇 px 늘어도 깨지지 않게 줄 수로 본다
      expect(row.height, lessThanOrEqualTo(26 * 2 + 4));
    });

    testWidgets('알약을 누르면 그 이모지가 넘어온다', (tester) async {
      String? toggled;
      String? asked;
      await tester.pumpWidget(
        _wrap(
          ChatReactionPills(
            reactions: [
              ReactionAgg(emoji: '❤️', employeeIds: ['a', 'b']),
              ReactionAgg(emoji: '😂', employeeIds: ['c']),
            ],
            mine: true,
            onToggle: (emoji) => toggled = emoji,
            onWho: (emoji) => asked = emoji,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ChatReactionPill).last);
      expect(toggled, '😂');

      await tester.longPress(find.byType(ChatReactionPill).first);
      expect(asked, '❤️');
    });
  });

  testWidgets('내가 누른 알약은 파란 테두리다', (tester) async {
    currentUser = _person('me');
    await tester.pumpWidget(
      _wrap(
        ChatReactionPills(
          reactions: [
            ReactionAgg(emoji: '❤️', employeeIds: ['me']),
          ],
          mine: true,
          onToggle: (_) {},
          onWho: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ChatReactionPill),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primaryLight);
    expect((decoration.border! as Border).top.color, AppColors.primary);
  });
}
