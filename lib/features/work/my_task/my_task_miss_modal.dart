import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/work/my_task_api.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../notifications/notification_screen.dart'
    show NotificationTarget, requestedScreen;
import '../work_screen.dart' show requestedWorkSubTab, requestedWorkTab;

// ---------------------------------------------------------------------------
// 개인 업무 누락 경고 모달 — 앱을 열 때 띄운다 (2026-08-31 대표 결정)
//
// 서버는 퇴근 스캔 뒤 **매시간** 재촉 푸시를 보내는데 앱 내 알림함에는 안
// 남는다 (하루 스물몇 번이라 남기면 알림함이 통째로 밀려난다). 푸시를 놓치면
// 흔적이 없어서, 앱을 열 때 한 번 더 짚어 준다 — 동료평가·마감 모달과 같은
// 자리, 같은 이유다.
//
// **본인 것과 남의 것이 잦기가 다르다.**
//
// | 누구 | 언제 |
// |---|---|
// | 누락한 본인 | **열 때마다** — 안 하면 다음 근무일에 −20 이다 |
// | MASTER · ADMIN · 점장 | **하루 한 번** — 남의 일로 매번 막히면 안 된다 |
//
// **판정은 서버가 한다** (`GET /my-tasks/miss-alert`). 앱이 "퇴근을 찍었나 +
// 남은 것이 있나" 를 조합하면 매시간 푸시와 갈려서, 폰은 울리는데 앱을 열면
// 아무것도 안 뜬다.
// ---------------------------------------------------------------------------

/// 남의 누락을 마지막으로 띄운 날 — 기기에 남는다 (`2026-8-31`)
///
/// **본인 것은 안 적는다.** 열 때마다 떠야 하는 쪽이라 기억할 것이 없다.
const _staffSeenKey = 'my_task_miss_staff_seen';

/// 모달 한 장에 적는 업무·이름 수 — 넘으면 `외 N개`
const _listMax = 4;

/// 환경정비 목록바에서 **내 업무** 칸 (대표·관리자에게는 직원 목록)
const _myTaskPane = 1;

/// 점장의 **직원 업무** 칸 — 점장만 세 번째 칸이 있다
const _staffPane = 2;

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _missShown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetMyTaskMissModal() => _missShown = false;

/// 앱을 열 때 누락 경고를 한 장 띄운다 — **띄웠으면 true**
///
/// 돌려주는 값을 셸이 본다. 마감 모달과 겹쳐 띄우면 X 를 두 번 눌러야 해서,
/// 이걸 띄운 회차는 마감 모달을 다음 번으로 미룬다.
///
/// 못 받으면 조용히 넘어간다 — 이것 때문에 앱 진입이 막히면 안 된다.
Future<bool> showMyTaskMissModal(BuildContext context) async {
  if (_missShown) return false;
  _missShown = true;

  final MyTaskMissAlert alert;
  try {
    alert = await MyTaskApi.missAlert();
  } catch (_) {
    return false;
  }
  if (!context.mounted) return false;

  // **본인 것이 먼저다.** 점수가 깎이는 쪽이고, 남의 것은 오늘 안에 한 번만
  // 뜨면 되므로 다음에 켤 때 그대로 남아 있다
  if (alert.mine.isNotEmpty) {
    await showAppDialog<void>(context, (_) => _MineWarning(alert: alert));
    return true;
  }
  if (alert.staff.isEmpty) return false;

  // 남의 것은 하루 한 번 — 날짜만 적어 둔다. 사람이 늘어도 그날은 다시 안 뜬다
  // (사람마다 띄우면 저녁에 퇴근이 이어지는 동안 계속 막힌다)
  final now = DateTime.now();
  final today = '${now.year}-${now.month}-${now.day}';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_staffSeenKey) == today) return false;
  await prefs.setString(_staffSeenKey, today);

  if (!context.mounted) return false;
  await showAppDialog<void>(context, (_) => _StaffWarning(alert: alert));
  return true;
}

/// 목록 몇 줄 + `외 N개` — 본인 업무와 직원 이름이 같은 모양으로 선다
String _summary(List<String> names) {
  if (names.length <= _listMax) return names.join(' · ');
  final head = names.take(_listMax).join(' · ');
  return '$head 외 ${names.length - _listMax}개';
}

/// 색 면 머리 + 본문 + 버튼 둘 — 동료평가 재촉 모달과 같은 틀
class _Shell extends StatelessWidget {
  _Shell({
    required this.tone,
    required this.badge,
    required this.title,
    required this.lead,
    required this.body,
    required this.hint,
    required this.action,
    required this.onGo,
  });

  final Color tone;
  final String badge;
  final String title;
  final String lead;
  final String body;
  final String hint;
  final String action;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 320),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 머리 — 얼마나 급한지를 색 면으로 먼저 보여준다
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22, 22, 22, 20),
            color: tone.withValues(alpha: 0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: AppTextStyles.title2.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(lead, style: AppTextStyles.body2.copyWith(color: tone)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    body,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.info_circle,
                      size: 13,
                      color: AppColors.gray400,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        hint,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '나중에',
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: action,
                        filled: true,
                        onTap: () {
                          Navigator.pop(context);
                          onGo();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 업무 화면의 환경정비 탭 + [pane] 칸으로 보낸다
///
/// **칸을 먼저 넣는다** — 화면은 탭 값이 바뀔 때 움직인다.
void _goWork(int pane) {
  requestedWorkSubTab.value = pane;
  requestedWorkTab.value = 0;
  requestedScreen.value = NotificationTarget.work;
}

/// 본인이 남기고 퇴근했다 — **열 때마다** 뜬다
class _MineWarning extends StatelessWidget {
  _MineWarning({required this.alert});

  final MyTaskMissAlert alert;

  @override
  Widget build(BuildContext context) {
    // 마지막 기회면 붉게 — 오늘 안 하면 내일 그대로 깎인다
    final tone = alert.lastChance ? AppColors.error : AppColors.warning;
    return _Shell(
      tone: tone,
      badge: alert.lastChance ? '오늘까지' : '내일까지',
      title: '안 한 업무가 있어요',
      lead: alert.lastChance ? '오늘이 지나면 누락으로 확정돼요' : '다음 근무일까지 하면 돼요',
      body: _summary(alert.mine),
      hint: '누락이 확정되면 20점이 깎여요 · 사유가 있으면 사유서를 낼 수 있어요',
      action: '하러 가기',
      onGo: () => _goWork(_myTaskPane),
    );
  }
}

/// 남이 남기고 퇴근했다 — **하루 한 번**만 뜬다
class _StaffWarning extends StatelessWidget {
  _StaffWarning({required this.alert});

  final MyTaskMissAlert alert;

  @override
  Widget build(BuildContext context) {
    final names = [for (final s in alert.staff) s.name];
    return _Shell(
      tone: AppColors.warning,
      badge: '오늘',
      title: '${names.length}명이 업무를 남기고 퇴근했어요',
      lead: '다음 근무일까지 안 하면 누락으로 확정돼요',
      body: _summary(names),
      hint: '오늘 한 번만 알려드려요',
      action: '보러 가기',
      // 점장만 세 번째 칸(직원 업무)이 있다 — 대표·관리자는 두 번째 칸이
      // 곧 사람 목록이다
      onGo: () => _goWork(myRole == Role.manager ? _staffPane : _myTaskPane),
    );
  }
}
