import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **결재를 바꾸는 API 가 신호를 빠짐없이 쏘는지** 본다.
///
/// 신호는 화면이 아니라 API 계층에서 쏜다 — 부르는 자리가 스물 몇 곳이라
/// 화면에서 쏘면 반드시 빠뜨린다. 그런데 **API 를 새로 만들면서 빠뜨리는
/// 것**은 여전히 남는다. 빠뜨려도 화면은 멀쩡히 뜨고, 낡은 줄을 다시 눌러
/// 400 이 날 때에야 드러난다 — 그때는 원인을 찾기 어렵다.
///
/// 그래서 **주소로 찾는다.** 결재를 바꾸는 서버 주소를 부르는 메서드는
/// 반드시 `notifyApprovalChanged()` 가 있어야 한다.
///
/// 깨졌다면 그 메서드 안, **`await` 뒤 `return` 앞**에 한 줄 넣는다.
/// 성공했을 때만 쏘아야 한다 — 실패는 예외로 위에 던져진다.
void main() {
  /// 결재함에 서는 줄을 바꾸는 **주소 조각**
  ///
  /// 여섯 갈래(급여·월차·일정·프로젝트·전자결재·내 업무)의 승인·반려와,
  /// **신청·취소·회수**까지 든다 — 줄이 새로 서거나 빠지는 것도 같은 값이다.
  ///
  /// **주소를 통째로 적는다.** 처음에는 `/approve` 처럼 조각만 적었는데
  /// `/employees/me/withdraw`(계정 탈퇴)가 `/withdraw` 에 걸렸다.
  /// 느슨하게 맞추면 결재와 무관한 메서드가 걸려서, 그걸 피하려고 예외를
  /// 늘리다 보면 **정작 진짜를 놓쳐도 모르게 된다.**
  const changing = <String>[
    // 승인·반려 — 여섯 갈래
    r"/approvals/$id/approve",
    r"/approvals/$id/reject",
    r"/approvals/$id/withdraw",
    r"/events/$id/approve",
    r"/events/$id/reject",
    r"/leaves/$id/approve",
    r"/leaves/$id/reject",
    r"/my-task-misses/$missId/approve",
    r"/my-task-misses/$missId/reject",
    r"/my-task-requests/$requestId/approve",
    r"/my-task-requests/$requestId/reject",
    r"/payslips/$id/approve",
    r"/payslips/$id/reject",
    r"/projects/requests/$requestId/approve",
    r"/projects/requests/$requestId/reject",
    // 신청·취소 — 결재함에 줄이 서거나 빠진다
    "/approvals'",
    "/events'",
    r"/events/$id", // 대기 중인 일정을 지우면 결재함에서 빠진다
    "/leaves'",
    r"/my-tasks/$id/requests",
    r"/projects/$projectId/requests",
    "/payslips/me/submit",
    "/payslips/me/cancel",
    r"/payslips/$id/pay",
    r"/leaves/$id/cancel",
    r"/my-task-misses/$missId/excuse",
  ];

  /// 주소는 같은데 **조회만** 하는 메서드 — 목록과 신청이 한 주소를 쓴다
  const readOnly = <String>['getList', '_client.get('];

  final files = Directory('lib/core/api')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final text = file.readAsStringSync();
    final name = file.uri.pathSegments.last;

    for (final method in _methods(text)) {
      final touches = changing.any(method.body.contains);
      if (!touches) continue;
      // 조회 메서드는 뺀다 — `/leaves` 는 목록도 같은 주소다
      if (readOnly.any(method.body.contains)) continue;

      test('$name.${method.name} 이 결재 신호를 쏜다', () {
        expect(
          method.body.contains('notifyApprovalChanged()'),
          isTrue,
          reason:
              '$name 의 ${method.name}() 가 결재를 바꾸는데 신호를 안 쏜다.\n'
              '  → `await` 뒤 `return` 앞에 notifyApprovalChanged(); 한 줄을 넣는다.\n'
              '  → 정말 결재와 무관하면 이 테스트의 changing 목록을 손본다.',
        );
      });
    }
  }

  test('결재 신호를 쏘는 자리가 스무 곳은 넘는다', () {
    var count = 0;
    for (final file in files) {
      count += 'notifyApprovalChanged()'
          .allMatches(file.readAsStringSync())
          .length;
    }
    // 정규식이 헛돌아 **아무것도 안 재는 채로 통과**하는 것이 제일 나쁘다
    expect(
      count,
      greaterThanOrEqualTo(20),
      reason: '신호를 쏘는 자리가 $count 곳뿐이다 — 걷어낸 것이 있는지 본다',
    );
  });
}

typedef _Method = ({String name, String body});

/// `static Future<...> 이름(...) { ... }` 을 잘라 낸다 (화살표 함수 포함)
List<_Method> _methods(String text) {
  final out = <_Method>[];
  final head = RegExp(r'static Future<[^>]*>\s+(\w+)\(');
  for (final m in head.allMatches(text)) {
    // 인자 괄호를 짝 맞춰 지난다
    var i = m.end - 1, depth = 0;
    do {
      if (text[i] == '(') depth++;
      if (text[i] == ')') depth--;
      i++;
    } while (depth > 0 && i < text.length);

    // 다음 `static`·`}` 앞까지를 본문으로 본다 (화살표 함수도 이 안에 든다)
    final rest = text.substring(i);
    final stop = RegExp(r'\n\s{0,2}(static |})').firstMatch(rest);
    out.add((
      name: m.group(1)!,
      body: rest.substring(0, stop?.start ?? rest.length),
    ));
  }
  return out;
}
