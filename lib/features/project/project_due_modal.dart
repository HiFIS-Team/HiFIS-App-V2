part of 'project_screen.dart';

// ---------------------------------------------------------------------------
// 마감 임박 알림 모달 — 앱을 열 때 한 장 띄운다
//
// 서버는 마감 리마인더를 푸시로만 보내는데(`project_due_soon`·`project_due_today`)
// **앱 내 알림함에는 안 남는다.** 푸시를 놓치면 흔적이 없어서, 앱을 열 때
// 한 번 더 짚어 준다.
//
// **한 번에 한 장만 띄운다.** 여러 개를 쌓으면 X 를 몇 번이나 눌러야 하고,
// 안 닫고 나가면 다음에 또 그만큼 쌓인다. 제일 급한 것 하나만 낸다.
// ---------------------------------------------------------------------------

/// 며칠 남았을 때부터 띄울지 — 이 안에 들면 대상이다
///
/// 서버 푸시는 남은 날이 며칠이든 매일 보내는데(`project_due_soon`), 모달까지
/// 그러면 한 달 남은 프로젝트로도 매일 뜬다. 눈앞의 것만 짚는다.
const _dueModalWithin = 7;

/// X 를 눌러 닫은 프로젝트 — 기기에 남는다
///
/// **영영 안 뜨는 게 아니라 그 회차만 접는다** (2026-08-06 결정).
/// 서버가 알림을 다시 보낼 때가 되면 모달도 다시 떠야 한다.
const _dueDismissKey = 'project_due_dismissed';

/// 지금이 몇 번째 알림 회차인지 — **서버 리마인더 주기와 같게 잡는다**
///
/// - 마감 전 : 서버가 매일 09시에 한 번 → 닫으면 그날만 접히고 **다음 날 다시**
/// - 마감 당일 : 매시간 → 닫으면 그 시간만 접히고 **다음 시간에 다시**
/// - 마감 초과 : 서버는 1회지만 모달은 **날마다** 다시 짚는다 (제일 급한 것이라)
String _windowOf(_Project project, DateTime now) {
  final day = '${now.year}-${now.month}-${now.day}';
  return _daysLeft(project, now) == 0 ? '$day/${now.hour}' : day;
}

/// 프로젝트 + 마감일 + 회차
///
/// 마감일을 넣는 이유는 기한 연장이 승인돼 마감이 밀리면 **새 마감을 새로
/// 알려 줘야** 하기 때문이다 — 키가 달라져서 저절로 다시 뜬다.
String _dismissKeyOf(_Project project, DateTime now) =>
    '${project.id}@${project.due.toIso8601String().substring(0, 10)}'
    '#${_windowOf(project, now)}';

/// 이번 실행에서 이미 띄웠는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _dueModalShown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetProjectDueModal() => _dueModalShown = false;

/// 앱을 열 때 마감 임박 프로젝트를 한 장 띄운다
///
/// 목록을 아직 안 받았으면 받아 온다. 못 받아도 조용히 넘어간다 — 이것 때문에
/// 앱 진입이 막히면 안 된다.
Future<void> showProjectDueModal(BuildContext context) async {
  if (_dueModalShown) return;
  _dueModalShown = true;
  await loadProjectsIfNeeded();
  if (!context.mounted) return;

  final now = DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final dismissed = prefs.getStringList(_dueDismissKey) ?? const <String>[];
  final target = _mostUrgent(dismissed, now);
  if (target == null || !context.mounted) return;

  final closed = await showAppDialog<bool>(
    context,
    (_) => _ProjectDueDialog(project: target),
  );
  // **X 를 눌렀을 때만** 접는다. 바깥을 눌러 닫거나 프로젝트를 열어 본 것은
  // '봤다'로 안 친다 — 다음에 열 때 다시 짚어 준다.
  if (closed != true) return;
  final key = _dismissKeyOf(target, now);
  // **지난 회차 기록은 버린다** — 안 버리면 목록이 끝없이 길어지고,
  // 어차피 회차가 지나면 다시 떠야 하는 것들이라 들고 있을 이유가 없다
  final today = '${now.year}-${now.month}-${now.day}';
  await prefs.setStringList(_dueDismissKey, [
    // 회차는 `#날짜` 또는 `#날짜/시` 라 끝이거나 뒤에 `/` 가 온다.
    // `contains` 만 쓰면 `#2026-8-1` 이 `#2026-8-10` 에도 걸린다
    ...dismissed.where(
      (k) => k != key && (k.endsWith('#$today') || k.contains('#$today/')),
    ),
    key,
  ]);
}

/// 제일 급한 프로젝트 하나 — 없으면 null
///
/// 누락이 제일 급하고, 그다음이 마감일이 가까운 순이다.
_Project? _mostUrgent(List<String> dismissed, DateTime now) {
  final candidates = <_Project>[
    for (final project in _projects)
      if (project.id != null &&
          project.phase != _Phase.done &&
          _daysLeft(project, now) <= _dueModalWithin &&
          !dismissed.contains(_dismissKeyOf(project, now)))
        project,
  ];
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => _daysLeft(a, now).compareTo(_daysLeft(b, now)));
  return candidates.first;
}

/// 마감까지 남은 날 — 지났으면 음수 (날짜만 보고 시각은 안 본다)
int _daysLeft(_Project project, DateTime today) => DateTime(
  project.due.year,
  project.due.month,
  project.due.day,
).difference(DateTime(today.year, today.month, today.day)).inDays;

/// 마감 임박 모달 — 닫으면 `true`(X), 그 외에는 null
class _ProjectDueDialog extends StatelessWidget {
  _ProjectDueDialog({required this.project});

  final _Project project;

  /// `9월 이벤트 프로젝트 마감기한이 3일 남았습니다`
  String get _line {
    final days = _daysLeft(project, DateTime.now());
    if (days < 0) return '${project.name} 프로젝트 마감기한이 지났습니다';
    if (days == 0) return '${project.name} 프로젝트 마감기한이 오늘입니다';
    return '${project.name} 프로젝트 마감기한이 $days일 남았습니다';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 340),
      padding: EdgeInsets.fromLTRB(22, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('마감이 다가와요', style: AppTextStyles.title3)),
              Pressable(
                onTap: () => Navigator.pop(context, true),
                scale: 0.9,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 18,
                    color: AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(_line, style: AppTextStyles.body2),
          SizedBox(height: 18),
          AppButton(
            label: '프로젝트 보기',
            filled: true,
            onTap: () {
              // 닫기(X)가 아니라 이동이다 — 다음에 열 때 다시 뜬다
              Navigator.pop(context);
              requestedProjectId.value = project.id;
              requestedScreen.value = NotificationTarget.project;
            },
          ),
        ],
      ),
    );
  }
}
