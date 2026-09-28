import 'package:flutter/material.dart';

import '../../../core/api/work/goal_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../notifications/notification_screen.dart'
    show NotificationTarget, requestedScreen;
import '../work_screen.dart' show requestedWorkTab, workGoalTab;

// ---------------------------------------------------------------------------
// 이달의 목표 재촉 모달 (2026-09-28 대표 요청)
//
// 매달 첫 월요일부터, 아직 목표를 안 낸 MANAGER·MEMBER 가 **앱을 열 때마다**
// 뜬다. 내면 멈춘다. 언제 띄울지는 서버가 정한다(`due`) — 첫 월요일 푸시와
// 같은 판단이라 둘이 갈리지 않는다.
// ---------------------------------------------------------------------------

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _shown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetGoalModal() => _shown = false;

/// 목표를 적을 때면 한 장 띄운다 — **띄웠으면 true**
///
/// 못 받으면 조용히 넘어간다 — 이것 때문에 앱 진입이 막히면 안 된다.
Future<bool> showGoalModal(BuildContext context) async {
  if (_shown) return false;
  _shown = true;

  final MyGoal mine;
  try {
    mine = await GoalApi.me();
  } catch (_) {
    return false;
  }
  if (!mine.due || !context.mounted) return false;

  final month = int.parse(mine.yearMonth.split('-').last);
  final go = await showConfirmDialog(
    context,
    icon: Icons.flag_rounded,
    iconColor: AppColors.primary,
    title: '$month월 목표를 적어 주세요',
    message: '이번 달에 이루고 싶은 것을 ${GoalApi.minItems}개 이상 적어요',
    cancelLabel: '나중에',
    confirmLabel: '적으러 가기',
  );
  if (!go) return true;
  requestedWorkTab.value = workGoalTab;
  requestedScreen.value = NotificationTarget.work;
  return true;
}
