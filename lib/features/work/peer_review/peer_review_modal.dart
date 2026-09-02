import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/work/peer_review_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../notifications/notification_screen.dart'
    show NotificationTarget, requestedScreen;
import '../work_screen.dart' show requestedWorkTab, workPeerReviewTab;

// ---------------------------------------------------------------------------
// 동료평가 재촉 모달 — 앱을 열 때 띄운다
//
// 서버는 평가 창(말일·1일) 동안 매시간 푸시를 보내는데 **앱 내 알림함에는
// 안 남는다** (이틀에 서른 번이라 남기면 알림함이 도배된다). 푸시를 놓치면
// 흔적이 없어서, 앱을 열 때 한 번 더 짚어 준다 — 프로젝트 마감 모달과 같은
// 자리, 같은 이유다.
//
// **창이 이틀뿐이고 안 내면 20점이 깎인다.** 그래서 마감 모달보다 자주 뜬다.
// ---------------------------------------------------------------------------

/// 얼마나 자주 띄울지 — **마지막 날에 두 배로 자주** (2026-08-31 대표 결정)
///
/// | 날 | 잦기 |
/// |---|---|
/// | 말일 | 3시간마다 |
/// | 다음 달 1일 (마지막 날) | 1시간마다 |
///
/// 접속 횟수가 아니라 **시계**로 잰다. 마감 모달은 남은 날이 잦기를 정해서
/// 접속 횟수로 셌는데, 여기는 창이 이틀이라 "몇 번 켰나" 로는 하루에 한 번도
/// 안 뜨는 사람과 열 번 뜨는 사람이 갈린다.
const _everyOnLastDay = Duration(hours: 1);
const _everyOnMonthEnd = Duration(hours: 3);

/// 마지막으로 띄운 시각 — 기기에 남는다 (기간별로 따로)
const _seenKey = 'peer_review_nudge_seen';

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _nudgeShown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetPeerReviewModal() => _nudgeShown = false;

/// 앱을 열 때 동료평가 재촉을 한 장 띄운다 — **띄웠으면 true**
///
/// 돌려주는 값을 셸이 본다. 마감 모달과 겹치는 날에 둘을 겹쳐 띄우면 X 를
/// 두 번 눌러야 해서, 이걸 띄운 날은 마감 모달을 다음 번으로 미룬다.
///
/// 못 받으면 조용히 넘어간다 — 이것 때문에 앱 진입이 막히면 안 된다.
Future<bool> showPeerReviewModal(BuildContext context) async {
  if (_nudgeShown) return false;
  _nudgeShown = true;

  final PeerWindow window;
  try {
    window = await PeerReviewApi.window();
  } catch (_) {
    return false;
  }
  // 닫혔거나 다 낸 사람 — 대표·관리자는 대상이 0명이라 여기서 저절로 빠진다
  if (!window.needsNudge || !context.mounted) return false;

  final now = DateTime.now();
  // 창은 말일과 다음 달 1일 이틀이다 — 1일이 마지막 날이다
  final lastDay = now.day == 1;
  final gap = lastDay ? _everyOnLastDay : _everyOnMonthEnd;

  final prefs = await SharedPreferences.getInstance();
  final key = '$_seenKey:${window.period}';
  final seen = DateTime.tryParse(prefs.getString(key) ?? '');
  if (seen != null && now.difference(seen) < gap) return false;
  await prefs.setString(key, now.toIso8601String());

  if (!context.mounted) return false;
  await _nudge(context, window, lastDay: lastDay);
  return true;
}

/// 재촉 팝업 — 삭제 확인 팝업과 같은 틀(아이콘 + 제목 + 본문 + 버튼 둘)
Future<void> _nudge(
  BuildContext context,
  PeerWindow window, {
  required bool lastDay,
}) async {
  // 평가하는 달 — `2026-08` 의 8
  final month = int.parse((window.period ?? '').split('-').last);
  final done = window.total - window.remaining;
  final go = await showConfirmDialog(
    context,
    icon: Icons.star_rounded,
    // 마지막 날은 붉게 — 오늘 안 하면 그대로 깎인다
    iconColor: lastDay ? AppColors.error : AppColors.warning,
    title: '$month월 동료평가를 해 주세요',
    // 얼마나 했는지를 같이 적는다 — 남은 수만 보여주면 판단이 안 선다
    message:
        '${window.total}명 중 $done명 했어요 · ${window.remaining}명 남았어요\n\n'
        '${lastDay ? '오늘이 지나면 낼 수 없어요' : '내일(1일)까지만 낼 수 있어요'}\n'
        '한 명이라도 안 내면 20점이 깎여요',
    cancelLabel: '나중에',
    confirmLabel: '평가하러 가기',
  );
  if (!go) return;
  // 업무 화면의 **동료 평가 탭**으로 — 그냥 보내면 첫 탭(환경정비)이 열려서
  // 한 번 더 찾아야 한다
  requestedWorkTab.value = workPeerReviewTab;
  requestedScreen.value = NotificationTarget.work;
}
