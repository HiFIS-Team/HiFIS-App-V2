import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/features/notifications/notification_screen.dart';

/// 알림 링크가 갈 화면으로 옮겨지는지 — **서버가 보내는 링크 그대로** 넣는다.
///
/// 결재(`/approvals/{id}`)가 여기 없어서 **눌러도 아무 일도 안 일어났다**
/// (2026-09-07 — "안드로이드 결재 대기에 결재가 없다"). 서버는 진작부터
/// `결재할 게 있어요` 알림에 그 링크를 실어 보내고 있었다
/// (`app/services/notification_texts.py`).
void main() {
  setUp(() {
    requestedScreen.value = null;
    requestedApprovalId.value = null;
  });

  test('결재 알림은 결재 화면으로 가고 문서 id 를 들고 간다', () {
    final moved = goToNotificationLink('/approvals/abc-123');

    expect(moved, isTrue);
    expect(requestedScreen.value, NotificationTarget.approval);
    expect(requestedApprovalId.value, 'abc-123');
  });

  test('프로젝트 알림은 그대로다 (같은 방식이라 같이 본다)', () {
    final moved = goToNotificationLink('/projects/p-1');

    expect(moved, isTrue);
    expect(requestedScreen.value, NotificationTarget.project);
    // 결재 id 는 안 건드린다 — 다른 알림이 남긴 값을 물고 가면 안 된다
    expect(requestedApprovalId.value, isNull);
  });

  test('모르는 링크는 갈 데가 없다 (읽음 처리만 한다)', () {
    expect(goToNotificationLink('/nowhere/9'), isFalse);
    expect(goToNotificationLink(null), isFalse);
    expect(requestedScreen.value, isNull);
  });
}
