import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/api/client/period.dart';
import 'package:hifis_app/core/api/staff/staff_api.dart';
import 'package:hifis_app/core/api/work/lesson_api.dart';
import 'package:hifis_app/core/api/work/peer_review_api.dart';
import 'package:hifis_app/core/api/work/pt_survey_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';
import 'package:hifis_app/features/notifications/notification_screen.dart';
import 'package:hifis_app/features/work/lesson/pt_survey_screen.dart';
import 'package:hifis_app/features/work/peer_review/peer_review_section.dart';
import 'package:hifis_app/features/work/work_screen.dart';

/// 2026-09-05 에 더한 것들 — 운동일지 스킵 · PT 만족도 화면 · 동료평가 월별
///
/// **폰과 PC 를 둘 다 그려 본다.** 이 앱은 화면마다 갈래가 둘이라 한쪽만 보면
/// 다른 쪽에서 넘치는 것을 못 잡는다 (위젯 테스트는 넘치면 그 자리에서 죽는다).
Employee _person(String id, String name, {Role role = Role.member}) => Employee(
  id: id,
  name: name,
  email: '$id@test.local',
  branchId: 'b1',
  rank: Rank.trainer,
  role: role,
  avatarColor: '#2F54EB',
);

/// 폰·PC 를 같은 본문으로 한 번씩 돌린다
void bothPlatforms(String name, Future<void> Function(WidgetTester) body) {
  for (final entry in {
    '폰': TargetPlatform.android,
    'PC': TargetPlatform.macOS,
  }.entries) {
    testWidgets('$name (${entry.key})', (tester) async {
      debugDefaultTargetPlatformOverride = entry.value;
      // PC 는 넓은 창, 폰은 좁은 기기 — 좁은 쪽에서 넘침이 난다
      tester.view.physicalSize = entry.value == TargetPlatform.macOS
          ? const Size(1440, 900)
          : const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      try {
        await body(tester);
      } finally {
        // **본문 안에서 되돌려야 한다.** 프레임워크가 tearDown 보다 먼저
        // '디버그 변수가 그대로인가'를 확인해서, addTearDown 에 두면 늦는다
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

void main() {
  // ── 기간 문자열 되돌리기 ──────────────────────────────────
  group('periodMonth — 서버가 준 기간을 달로 되돌린다', () {
    test('정상 값', () {
      expect(periodMonth('2026-08'), DateTime(2026, 8));
      expect(periodMonth('2026-01'), DateTime(2026, 1));
      expect(periodMonth('2026-12'), DateTime(2026, 12));
    });

    test('periodKey 와 왕복한다', () {
      for (var m = 1; m <= 12; m++) {
        final month = DateTime(2026, m);
        expect(periodMonth(periodKey(month)), month);
      }
    });

    test('이상한 값은 null 이다 — 부르는 쪽이 이번 달로 떨어뜨린다', () {
      expect(periodMonth(null), isNull);
      expect(periodMonth(''), isNull);
      expect(periodMonth('2026'), isNull);
      expect(periodMonth('2026-13'), isNull, reason: '13월은 없다');
      expect(periodMonth('2026-00'), isNull);
      expect(periodMonth('202608'), isNull);
      expect(periodMonth('abcd-ef'), isNull);
      expect(periodMonth('2026-08-01'), isNull, reason: '하루짜리는 이 함수가 아니다');
    });
  });

  // ── 운동일지 스킵 ────────────────────────────────────────
  group('SessionSign — 싸인 생략 표시', () {
    Map<String, dynamic> base() => {
      'id': 's1',
      'registrationId': 'r1',
      'memberId': 'm1',
      'performedByTrainerId': 't1',
      'sessionNo': 7,
      'signedAt': '2026-09-05T01:00:00Z',
    };

    test('생략한 기록은 서명 이미지가 없다', () {
      final sign = SessionSign.fromJson({
        ...base(),
        'signatureUrl': null,
        'signatureSkipped': true,
        'signatureSkippedByName': '김트레이너',
      });
      expect(sign.signatureSkipped, isTrue);
      expect(sign.signatureUrl, isNull);
      // 이미지가 없으면 주소도 없다 — 화면이 이걸 보고 빈 칸을 그린다
      expect(sign.signatureFullUrl, isNull);
      expect(sign.signatureSkippedByName, '김트레이너');
    });

    test('평소 싸인은 이미지가 있다', () {
      final sign = SessionSign.fromJson({
        ...base(),
        'signatureUrl': '/files/a.png',
        'signatureSkipped': false,
      });
      expect(sign.signatureSkipped, isFalse);
      expect(sign.signatureFullUrl, isNotNull);
    });

    test('칸이 아예 없어도 안 죽는다 — 옛 서버를 만나도 화면은 뜬다', () {
      final sign = SessionSign.fromJson({
        ...base(),
        'signatureUrl': '/files/a.png',
      });
      expect(sign.signatureSkipped, isFalse);
      expect(sign.signatureSkippedByName, isNull);
    });
  });

  // ── PT 만족도 폼 ─────────────────────────────────────────
  group('PtSurvey — 서버 응답 읽기', () {
    Map<String, dynamic> base() => {
      'id': 'p1',
      'registrationId': 'r1',
      'memberId': 'm1',
      'trainerId': 't1',
      'sessionNo': 7,
      'createdAt': '2026-09-01T00:00:00Z',
    };

    test('아직 안 낸 설문', () {
      final s = PtSurvey.fromJson({...base(), 'url': 'https://hifis.app/pt/tok'});
      expect(s.answered, isFalse);
      expect(s.satisfaction, isNull);
      expect(s.renew, isNull);
      expect(s.url, 'https://hifis.app/pt/tok');
      // 이름이 없으면 빈 칸이 아니라 '알 수 없음' 이다 (목록이 비어 보이면 안 된다)
      expect(s.displayMember, '알 수 없음');
      expect(s.displayTrainer, '알 수 없음');
    });

    test('답이 온 설문', () {
      final s = PtSurvey.fromJson({
        ...base(),
        'memberName': '이건주',
        'trainerName': '김트레이너',
        'answeredAt': '2026-09-05T02:00:00Z',
        'satisfaction': 5,
        'request': '스트레칭을 더 해주세요',
        'renew': 'YES',
      });
      expect(s.answered, isTrue);
      expect(s.satisfaction, 5);
      expect(s.renew, RenewIntent.yes);
      expect(s.displayMember, '이건주');
    });

    test('연장 의향 세 가지가 다 붙는다', () {
      expect(RenewIntent.parse('YES'), RenewIntent.yes);
      expect(RenewIntent.parse('MAYBE'), RenewIntent.maybe);
      expect(RenewIntent.parse('NO'), RenewIntent.no);
      // 모르는 값·빈 값에 죽지 않는다 — 서버가 항목을 늘려도 화면은 뜬다
      expect(RenewIntent.parse(null), isNull);
      expect(RenewIntent.parse('LATER'), isNull);
    });

    test('이름이 비어도 아바타 첫 글자를 뽑을 수 있다', () {
      // 목록이 `name.characters.first` 를 쓴다 — 빈 글자가 새면 거기서 죽는다
      final s = PtSurvey.fromJson({...base(), 'memberName': '', 'trainerName': '   '});
      expect(s.displayMember, '알 수 없음');
      expect(s.displayTrainer, '알 수 없음');
      expect(() => s.displayMember.characters.first, returnsNormally);
    });
  });

  // ── 알림을 누르면 볼 자리로 가나 ──────────────────────────
  group('PT 만족도 알림 딥링크', () {
    test('업무의 수업 개수 칸까지 열어 준다', () {
      requestedWorkTab.value = null;
      requestedScreen.value = null;

      expect(goToNotificationLink('/work/pt-surveys'), isTrue);
      // 탭까지 안 옮기면 첫 칸(환경정비)이 열려서 볼 자리를 다시 찾아야 한다
      expect(requestedWorkTab.value, workLessonTab);
      expect(requestedScreen.value, NotificationTarget.work);

      requestedWorkTab.value = null;
      requestedScreen.value = null;
    });

    test('그냥 /work 는 탭을 안 건드린다 — 점수·칭찬 알림이 쓰는 길이다', () {
      requestedWorkTab.value = null;
      requestedScreen.value = null;

      expect(goToNotificationLink('/work'), isTrue);
      expect(requestedWorkTab.value, isNull);
      expect(requestedScreen.value, NotificationTarget.work);

      requestedScreen.value = null;
    });
  });

  // ── 화면이 실제로 그려지나 (폰·PC) ─────────────────────────
  bothPlatforms('PT 만족도 화면이 그려진다 — 넘침 없이', (tester) async {
    currentUser = _person('me', '나', role: Role.master);
    await tester.pumpWidget(MaterialApp(home: PtSurveyScreen()));
    await tester.pump(); // 서버가 없으니 곧 빈 목록으로 떨어진다
    // 뼈대가 걷힐 때까지 (SkeletonDelay 최소 노출 300ms)
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PT 만족도'), findsOneWidget);
    expect(find.text('답변'), findsOneWidget);
    expect(find.text('미응답'), findsOneWidget);
    // 서버가 없으니 빈 목록이다 — '없다'고 알려 줘야지 빈 화면이면 안 된다
    expect(find.textContaining('아직 들어온 답변이 없어요'), findsOneWidget);

    // 탭을 옮겨도 안 죽고, 안내 문구가 그 탭 것으로 바뀐다
    await tester.tap(find.text('미응답'));
    await tester.pump();
    expect(find.textContaining('아직 답을 안 준 회원'), findsOneWidget);
    expect(find.text('기다리는 설문이 없어요'), findsOneWidget);

    currentUser = null;
  });

  bothPlatforms('동료평가에 달 이동 줄이 선다', (tester) async {
    currentUser = _person('me', '나');
    StaffDirectory.instance
      ..employees = [currentUser!, _person('a', '김트레이너')]
      ..branches = [Branch(id: 'b1', name: '화순', type: 'BRANCH')];

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PeerReviewSection()))),
    );
    await tester.pump();
    // 뼈대가 걷힐 때까지 (SkeletonDelay 최소 노출 300ms)
    await tester.pump(const Duration(milliseconds: 400));

    final now = DateTime.now();
    expect(
      find.text('${now.year}년 ${now.month}월'),
      findsOneWidget,
      reason: '창을 못 받으면 이번 달로 선다',
    );

    StaffDirectory.instance.clear();
    currentUser = null;
  });
}
