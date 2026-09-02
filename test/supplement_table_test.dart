/// 영양제가 **넓으면 표, 좁으면 카드**로 서는지
///
/// 표는 세로선을 줄 높이만큼 늘리려고 `IntrinsicHeight` + `stretch` +
/// `Expanded` 를 겹쳐 쓴다 — 이 조합은 제약이 어긋나면 **그릴 때 터진다**
/// (컴파일에는 안 걸린다). 에뮬레이터 화면 캡처가 GPU 서피스라 검게만 나와서
/// 눈으로 확인할 길이 없었다 (2026-09-03).
///
/// 서버는 안 부른다 — `ApiClient` 의 Dio 어댑터만 갈아 끼워 정해진 답을 준다.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/api/client/api_client.dart';
import 'package:hifis_app/core/api/staff/staff_api.dart';
import 'package:hifis_app/core/api/work/lesson_api.dart';
import 'package:hifis_app/core/data/current_user.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';
import 'package:hifis_app/features/member/member_detail.dart';

const _trainerId = 'e-trainer';
const _memberId = 'm-1';

final _member = Member(
  id: _memberId,
  name: '이건주',
  phone: '01012345678',
  branchId: 'b1',
  ownerTrainerId: _trainerId,
  registeredAt: DateTime(2026, 8, 1),
);

/// 노션 표에서 그대로 가져온 줄 — 가장 긴 값으로 잡아 둔다
const _rows = [
  {
    'id': 's1',
    'memberId': _memberId,
    'name': '오메가3',
    'dose': '1000~3000mg',
    'timing': '아침식후',
    'reason': '성인병 예방, 염증완화, 세포 단위 개선',
    'note': '식사 직후',
    'sortOrder': 0,
    'authorId': _trainerId,
  },
  {
    'id': 's2',
    'memberId': _memberId,
    'name': '종합비타민',
    'dose': '하루 1~2알 (제품마다 상이)',
    'timing': '점심 저녁 사이 (위장장애시 식후)',
    'reason': '피부 보습, 피부 주름 개선, 손톱 건강, 관절 건강, 혈관 건강',
    // 빈 칸이 섞여도 `—` 로 자리를 지키는지 같이 본다
    'note': '',
    'sortOrder': 1,
    'authorId': _trainerId,
  },
];

/// 회원 상세가 부르는 세 곳에만 답한다
class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    final body = switch (options.path) {
      '/supplements' => _rows,
      _ => const [],
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _app(double width) => MediaQuery(
  data: MediaQueryData(size: Size(width, 900)),
  child: MaterialApp(home: MemberDetailScreen(member: _member)),
);

void main() {
  setUpAll(() {
    ApiClient.instance.dio.httpClientAdapter = _FakeAdapter();
  });

  setUp(() {
    currentUser = Employee(
      id: _trainerId,
      name: '테스트 트레이너',
      email: 'trainer@hifis.local',
      branchId: 'b1',
      rank: Rank.trainer,
      role: Role.member,
      avatarColor: '#2F54EB',
    );
    StaffDirectory.instance
      ..employees = [currentUser!]
      ..branches = [Branch(id: 'b1', name: '화순', type: 'BRANCH')];
  });

  tearDown(() {
    currentUser = null;
    StaffDirectory.instance.clear();
  });

  testWidgets('넓은 화면(PC·태블릿)에서는 표로 선다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(1200));
    await tester.pumpAndSettle();

    // 다섯 칸 머리말이 다 서 있다
    for (final label in ['영양제', '얼마나?', '언제?', '왜?', '기억하기']) {
      expect(find.text(label), findsWidgets, reason: '$label 칸이 없다');
    }
    expect(find.text('오메가3'), findsOneWidget);
    expect(find.text('1000~3000mg'), findsOneWidget);
    // 안 적은 칸은 자리를 비우지 않고 가운뎃줄로 지킨다
    expect(find.text('—'), findsOneWidget);
    // 카드 줄에만 있는 `이름 · 얼마나 · 언제` 요약은 안 뜬다
    expect(find.text('1000~3000mg · 아침식후'), findsNothing);
  });

  testWidgets('좁은 화면(폰)에서는 카드로 선다', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(390));
    await tester.pumpAndSettle();

    // 카드는 이름 밑에 `얼마나 · 언제` 를 한 줄로 요약한다
    expect(find.text('1000~3000mg · 아침식후'), findsOneWidget);
    // 표 머리말(`얼마나?`)은 안 선다 — 폼 팝업이 안 떠 있으니 어디에도 없다
    expect(find.text('얼마나?'), findsNothing);
    expect(find.text('기억하기'), findsNothing);
  });
}
