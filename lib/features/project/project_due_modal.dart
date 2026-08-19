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
  await showAppDialog<void>(context, (_) => _ProjectDueDialog(project: target));
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
  if (myRole == Role.master || myRole == Role.admin) return const [];
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

/// 마감 임박 모달
class _ProjectDueDialog extends StatelessWidget {
  _ProjectDueDialog({required this.project});

  final _Project project;

  int get _days => _daysLeft(project, DateTime.now());

  /// 배지에 크게 찍는 말 — `D-3` · `D-DAY` · `D+2`
  String get _dday {
    final days = _days;
    if (days == 0) return 'D-DAY';
    if (days < 0) return 'D+${-days}';
    return 'D-$days';
  }

  String get _title {
    final days = _days;
    if (days < 0) return '마감이 지났어요';
    if (days == 0) return '오늘이 마감이에요';
    if (days <= _dueSoonFrom) return '마감이 얼마 안 남았어요';
    return '마감이 다가와요';
  }

  String get _sub {
    final days = _days;
    if (days < 0) return '${-days}일 지났어요. 지금 확인해 주세요';
    if (days == 0) return '오늘 안에 마무리해 주세요';
    return '$days일 뒤 마감이에요';
  }

  /// 급할수록 붉게 — 당일부터는 빨강, 임박은 주황, 그 밖은 프로젝트 색
  Color get _tone {
    final days = _days;
    if (days <= 0) return AppColors.error;
    if (days <= _dueSoonFrom) return AppColors.warning;
    return project.color;
  }

  String get _dueLabel =>
      '${project.due.year}년 ${project.due.month}월 ${project.due.day}일';

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final percent = (project.progress * 100).round();

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
          // 머리 — 급한 정도를 색 면으로 먼저 보여준다
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
                    _dday,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _title,
                  style: AppTextStyles.title2.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(_sub, style: AppTextStyles.body2.copyWith(color: tone)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
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
                    Expanded(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // 얼마나 했는지 — 급한 정도만 보여주면 판단이 안 선다
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: project.progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation(project.color),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '$percent%',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '마감 $_dueLabel',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
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
                        label: '프로젝트 보기',
                        filled: true,
                        onTap: () {
                          Navigator.pop(context);
                          requestedProjectId.value = project.id;
                          requestedScreen.value = NotificationTarget.project;
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
