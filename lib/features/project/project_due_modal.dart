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

/// 얼마나 자주 띄울지 — **마감이 가까울수록 자주** (2026-08-11 결정)
///
/// | 남은 날 | 언제 |
/// |---|---|
/// | 4일 이상 | 그날 **처음 켤 때 한 번** |
/// | 3 · 2 · 1일 | **접속 3번마다 한 번** |
/// | 당일 · 지남 | **켤 때마다** |
///
/// 예전에는 7일 안쪽만 대상이었고 X 를 누르면 그 회차를 접었다.
/// 이제 **프로젝트가 만들어진 날부터** 담당자에게 뜨고, 접는 버튼 대신
/// 남은 날이 잦기를 정한다 — 급해질수록 저절로 자주 뜬다.
const _dueEveryOpen = 0; // 당일·초과: 켤 때마다
const _dueEveryThird = 3; // 1~3일: 접속 3번마다
const _dueSoonFrom = 3; // 며칠 남았을 때부터 '임박'인지

/// 프로젝트별로 마지막에 띄운 날과 그 뒤 접속 횟수 — 기기에 남는다
const _dueSeenKey = 'project_due_seen';

/// 한 프로젝트에 대해 기억하는 것
///
/// [day] 는 마지막으로 띄운 날(`2026-8-11`), [opens] 는 그 뒤로 앱을 켠 횟수다.
typedef _DueSeen = ({String day, int opens});

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _dueModalShown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetProjectDueModal() => _dueModalShown = false;

/// 프로젝트 + 마감일
///
/// 마감일을 넣는 이유는 기한 연장이 승인돼 마감이 밀리면 **새 마감을 새로**
/// 알려 줘야 하기 때문이다 — 키가 달라져서 계수가 처음부터 다시 센다.
String _dueKeyOf(_Project project) =>
    '${project.id}@${project.due.toIso8601String().substring(0, 10)}';

String _dayOf(DateTime now) => '${now.year}-${now.month}-${now.day}';

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
  final today = _dayOf(now);
  final prefs = await SharedPreferences.getInstance();
  final seen = _readSeen(prefs);

  // 접속 1회 — 대상마다 계수를 올리고, 이번에 띄울 자격이 된 것을 모은다
  final next = <String, _DueSeen>{};
  final ready = <_Project>[];
  for (final project in _dueTargets()) {
    final key = _dueKeyOf(project);
    final before = seen[key];
    if (_shouldShow(project, before, now)) {
      ready.add(project);
      next[key] = before ?? (day: '', opens: 0);
    } else {
      // 못 띄운 회차도 접속 횟수는 쌓인다 — 그래야 3번째에 뜬다
      next[key] = (day: before?.day ?? '', opens: (before?.opens ?? 0) + 1);
    }
  }

  // 제일 급한 것 하나 — 마감이 가까운 순
  ready.sort((a, b) => _daysLeft(a, now).compareTo(_daysLeft(b, now)));
  final target = ready.firstOrNull;
  // **띄운 것만** 계수를 되돌린다. 나머지는 자격이 됐어도 화면에 안 났으니
  // 다음 번에 그대로 뜬다
  if (target != null) next[_dueKeyOf(target)] = (day: today, opens: 0);
  await _writeSeen(prefs, next);

  if (target == null || !context.mounted) return;
  await _showDueDialog(context, target);
}

/// 모달 대상 — **내가 참여한**, 아직 안 끝난 프로젝트
///
/// 남은 날 제한이 없다. 만들어진 날부터 마감까지 계속 대상이고,
/// 잦기는 [_shouldShow] 가 정한다.
///
/// **MASTER·ADMIN 에게는 안 띄운다** (2026-08-19 대표 결정). 직원이 만든
/// 프로젝트에 대표를 참여 멤버로 넣으면 마감까지 앱을 열 때마다 모달이 떴다.
/// 대표·관리자가 받는 것은 **마감이 지난 뒤 누가 누락했는지**이고 그건
/// 알림함으로 따로 온다. 서버 리마인더도 같은 기준으로 빠진다
/// (`_reminder_targets`).
List<_Project> _dueTargets() {
  if (myRole.boss) return const [];
  final me = currentUser?.id;
  return [
    for (final project in _projects)
      if (project.id != null &&
          project.phase != _Phase.done &&
          (me == null || project.memberIds.contains(me)))
        project,
  ];
}

/// 이번 접속에 띄울 차례인가
bool _shouldShow(_Project project, _DueSeen? seen, DateTime now) {
  final days = _daysLeft(project, now);
  // 당일·초과 — 켤 때마다
  if (days <= _dueEveryOpen) return true;
  // 처음 보는 프로젝트는 바로 한 번 짚는다
  if (seen == null) return true;
  // 1~3일 — 접속 3번마다
  if (days <= _dueSoonFrom) return seen.opens + 1 >= _dueEveryThird;
  // 그 밖 — 그날 아직 안 띄웠으면
  return seen.day != _dayOf(now);
}

Map<String, _DueSeen> _readSeen(SharedPreferences prefs) {
  final raw = prefs.getString(_dueSeenKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries)
        if (e.value case final Map<String, dynamic> v)
          e.key: (
            day: v['day'] as String? ?? '',
            opens: v['opens'] as int? ?? 0,
          ),
    };
  } catch (_) {
    // 저장된 모양이 옛것이면 버린다 — 알림 잦기라 잃어도 그만이다
    return {};
  }
}

/// **지금 대상인 것만 남긴다** — 끝났거나 마감이 밀린 프로젝트의 옛 계수를
/// 안 지우면 목록이 끝없이 길어진다
Future<void> _writeSeen(SharedPreferences prefs, Map<String, _DueSeen> state) =>
    prefs.setString(
      _dueSeenKey,
      jsonEncode({
        for (final e in state.entries)
          e.key: {'day': e.value.day, 'opens': e.value.opens},
      }),
    );

/// 마감까지 남은 날 — 지났으면 음수 (날짜만 보고 시각은 안 본다)
int _daysLeft(_Project project, DateTime today) => DateTime(
  project.due.year,
  project.due.month,
  project.due.day,
).difference(DateTime(today.year, today.month, today.day)).inDays;

/// 마감 임박 팝업 — 삭제 확인 팝업과 같은 틀(아이콘 + 제목 + 본문 + 버튼 둘)
Future<void> _showDueDialog(BuildContext context, _Project project) async {
  final days = _daysLeft(project, DateTime.now());
  final due = project.due;
  final go = await showConfirmDialog(
    context,
    icon: Icons.flag_rounded,
    iconColor: _dueTone(project, days),
    title: _dueTitle(days),
    // 얼마나 했는지를 같이 적는다 — 급한 정도만 보여주면 판단이 안 선다
    message:
        '${project.name} · 진행률 ${(project.progress * 100).round()}%\n\n'
        '마감 ${due.year}년 ${due.month}월 ${due.day}일\n'
        '${_dueSub(days)}',
    cancelLabel: '나중에',
    confirmLabel: '프로젝트 보기',
  );
  if (!go) return;
  requestedProjectId.value = project.id;
  requestedScreen.value = NotificationTarget.project;
}

/// 급할수록 붉게 — 당일부터는 빨강, 임박은 주황, 그 밖은 프로젝트 색
Color _dueTone(_Project project, int days) {
  if (days <= 0) return AppColors.error;
  if (days <= _dueSoonFrom) return AppColors.warning;
  return project.color;
}

String _dueTitle(int days) {
  if (days < 0) return '마감이 지났어요';
  if (days == 0) return '오늘이 마감이에요';
  if (days <= _dueSoonFrom) return '마감이 얼마 안 남았어요';
  return '마감이 다가와요';
}

/// `D-3 · 3일 남았어요` — 배지 자리가 없어져서 D-day 를 본문에 같이 적는다
String _dueSub(int days) {
  if (days < 0) return 'D+${-days} · ${-days}일 지났어요';
  if (days == 0) return 'D-DAY · 오늘 안에 마무리해 주세요';
  return 'D-$days · $days일 남았어요';
}
