import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/monitoring/access_log_api.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/page_numbers.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/delayed_spinner.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/pane_transition.dart';
import 'activity_panel.dart';
import 'anomaly_panel.dart';
import 'chat_audit_panel.dart';
import 'performance_panel.dart';
part 'monitoring_grass.dart';
part 'monitoring_summary.dart';
part 'monitoring_top.dart';
part 'monitoring_recent.dart';

/// 모니터링 — 누가 언제 들어와서 무엇을 했는지 (**MASTER 만**)
///
/// 탭 다섯이다.
/// - **접속** 잔디(언제 붐볐나) · 오늘 요약 · 많이 들어온 사람 · 프로그램 · 들어온 순서
/// - **활동** 누가 무엇을 등록·수정·삭제했는지 ([ActivityPanel])
/// - **대화** 사내톡 방 목록과 주고받은 말 ([ChatAuditPanel])
/// - **성능** 서버가 얼마나 빠른가 ([PerformancePanel])
/// - **이상** 수상한 흐름 — 찾으면 대표에게 푸시가 간다 ([AnomalyPanel])
///
/// **색은 앱 토큰 그대로다.** 진하기만 바꿔서 밀도를 만든다.
/// 서버가 준 값도 그대로 쓴다 — 프로그램 이름(`userAgent`)을 해석하지 않는 건
/// 지금 앱이 기기를 안 밝혀서 해석해 봐야 틀린 말이 되기 때문이다.
///
/// 활동·대화 판은 **고른 탭에서만 만든다.** 셋을 같이 띄우면 열어 보지도 않은
/// 대화를 조회하게 되고, 서버가 그걸 '대화방 목록 열람' 으로 남긴다.
class MonitoringScreen extends StatefulWidget {
  MonitoringScreen({super.key});

  /// 이 화면을 볼 수 있는 사람 — 서버 게이트와 같다.
  ///
  /// **MASTER 만.** 남의 활동과 대화를 들여다보는 자리라 ADMIN 도 못 본다
  /// (서버도 403 이라, 열어 두면 눌렀을 때 빈 화면만 나온다).
  static bool get visible => myRole == Role.master;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

/// 잔디에 그릴 날 수 — 가로 한 줄이 하루다
const _grassDays = 14;

class _MonitoringScreenState extends State<MonitoringScreen> {
  /// 통계·잔디가 보는 창 — 최근 14일을 덮을 만큼 넉넉히 받는다.
  /// **목록은 여기서 안 뽑는다** (아래 [_rows] 가 번호 페이지로 따로 받는다).
  List<AccessLog> _logs = const [];
  bool _loading = true;

  /// 목록 한 장에 몇 줄까지
  static const _perPage = 100;

  /// 지금 보고 있는 장 (0부터)
  int _listPage = 0;

  /// 그 장에 실린 줄 — 통계용 [_logs] 와 다른 조회다
  List<AccessLog> _rows = const [];

  /// 서버가 헤더로 알려 준 전체 건수 — 장 수와 탭 라벨이 이걸 쓴다
  int _total = 0;
  int _failed = 0;

  /// 장을 넘기는 동안 고정하는 기준선
  ///
  /// **이 화면을 여는 것 자체가 접속·활동 로그로 남는다.** 기준을 안 잡으면
  /// 2장으로 넘어가는 사이에 새 줄이 앞에 끼어들어 1장 마지막 줄이 또 나온다.
  DateTime _since = DateTime.now();

  /// 0 접속 · 1 활동 · 2 대화 · 3 성능 · 4 이상
  int _page = 0;

  /// 새로고침을 누른 횟수 — 활동·대화 판을 새로 만들어 다시 받게 하는 열쇠
  int _reload = 0;

  /// 접속 탭 안쪽 — 0 전체 · 1 실패만
  int _tab = 0;

  /// 상대 시각('방금', '12분 전')이 멈춰 보이지 않게 1분마다 다시 그린다.
  /// **다시 받아오지는 않는다** — 화면만 새로 그린다.
  Timer? _tick;

  /// 모니터링 탭이 지금 보이는가 — 안 보이면 다시 그리지 않는다
  /// ([LazyIndexedStack] 이 탭을 살려 둬서 가드가 없으면 계속 돈다)
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted && _visible) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // 통계·잔디용 창 + 목록 한 장 — 보는 범위가 달라 따로 받는다
      final stats = await AccessLogApi.list(limit: 500);
      final page = await _fetchPage();
      if (!mounted) return;
      setState(() {
        _logs = stats;
        _rows = page.items;
        _total = page.total;
        _failed = page.failed;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<({List<AccessLog> items, int total, int failed})> _fetchPage() =>
      AccessLogApi.page(
        event: _tab == 1 ? AccessEvent.loginFail : null,
        limit: _perPage,
        offset: _listPage * _perPage,
        before: _since,
      );

  /// 탭·장을 옮기면 목록만 새로 받는다 (통계는 그대로 둔다)
  Future<void> _goList({int? tab, int? page}) async {
    setState(() {
      if (tab != null && tab != _tab) {
        _tab = tab;
        _listPage = 0; // 다른 탭의 5장째로 넘어가면 빈 화면이 뜬다
      }
      if (page != null) _listPage = page;
    });
    try {
      final result = await _fetchPage();
      if (!mounted) return;
      setState(() {
        _rows = result.items;
        _total = result.total;
        _failed = result.failed;
      });
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 지금 탭에 걸린 건수 — 장 수를 셀 때 쓴다
  int get _listCount => _tab == 0 ? _total : _failed;

  int get _listPages => (_listCount / _perPage).ceil();

  bool _isToday(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
  }

  List<AccessLog> get _today => [
    for (final log in _logs)
      if (_isToday(log.createdAt)) log,
  ];

  /// 오늘 들어온 사람 수 (같은 사람이 여러 번 들어와도 하나)
  int get _todayPeople => {
    for (final log in _today)
      if (!log.event.failed && log.employeeId != null) log.employeeId!,
  }.length;

  /// 접속률의 분모 — 재직 중인 사람만 센다 (퇴사·비활성은 안 들어오는 게 맞다)
  int get _staffTotal => StaffDirectory.instance.employees
      .where((e) => e.status == EmployeeStatus.active)
      .length;

  /// 어제 접속 횟수 — 오늘과 견줄 상대
  int get _yesterdayVisits {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    var count = 0;
    for (final log in _logs) {
      final at = log.createdAt;
      if (DateTime(at.year, at.month, at.day) == yesterday) count++;
    }
    return count;
  }

  /// 잔디 — `[날짜][시간]` 건수. 0번 줄이 오늘이고 아래로 갈수록 과거다
  List<List<int>> get _grass {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grid = [for (var d = 0; d < _grassDays; d++) List.filled(24, 0)];
    for (final log in _logs) {
      final at = log.createdAt;
      final day = today.difference(DateTime(at.year, at.month, at.day)).inDays;
      if (day < 0 || day >= _grassDays) continue;
      grid[day][at.hour]++;
    }
    return grid;
  }

  /// 많이 들어온 사람 — 이름을 아는 사람만 (실패·탈퇴자는 뺀다)
  List<(String, int)> get _topPeople {
    final counts = <String, int>{};
    for (final log in _logs) {
      final id = log.employeeId;
      if (log.event.failed || id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final rows = [
      for (final entry in counts.entries)
        if (StaffDirectory.instance.byId(entry.key)?.name case final name?)
          (name, entry.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(5).toList();
  }

  /// 접속한 프로그램 분포
  List<(String, int)> get _agents {
    final counts = <String, int>{};
    for (final log in _logs) {
      final raw = (log.userAgent ?? '').trim();
      final name = raw.isEmpty ? '—' : raw;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final rows = [for (final e in counts.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(5).toList();
  }

  /// 새로고침 — 보고 있는 탭만 다시 받는다
  void _refresh() {
    // 새로고침은 기준선을 지금으로 다시 잡는다 — 그동안 쌓인 것까지 본다
    setState(() {
      _reload++;
      _since = DateTime.now();
      _listPage = 0;
    });
    if (_page == 0) _load();
  }

  @override
  Widget build(BuildContext context) {
    // 탭이 바뀌면 이 값이 뒤집히면서 리빌드가 걸린다 (InheritedWidget)
    _visible = TickerMode.valuesOf(context).enabled;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(
              title: '모니터링',
              subtitle: '누가 언제 들어와서 무엇을 했는지 확인해요',
              trailing: _RefreshButton(onTap: _refresh),
            ),
            SizedBox(height: 22),
            SegmentedTabs(
              labels: ['접속', '활동', '대화', '성능', '이상'],
              selected: _page,
              onSelect: (i) => setState(() => _page = i),
            ),
            SizedBox(height: 16),
            // 탭을 옮기면 사이드바로 화면을 바꿀 때와 **같은 전환**이 걸린다
            PaneTransition(step: _page, child: _pane(context)),
          ],
        ),
      ),
    );
  }

  /// 고른 탭의 내용 — 판 하나만 만든다
  ///
  /// 다섯을 같이 띄우면 열어 보지도 않은 대화를 조회하게 되고,
  /// 서버가 그걸 '대화방 목록 열람' 으로 남긴다.
  Widget _pane(BuildContext context) {
    if (_page == 3) return PerformancePanel(key: ValueKey('perf-$_reload'));
    if (_page == 4) return AnomalyPanel(key: ValueKey('anomaly-$_reload'));
    if (_page == 1) return ActivityPanel(key: ValueKey('activity-$_reload'));
    if (_page == 2) {
      return ChatAuditPanel(
        key: ValueKey('chat-$_reload'),
        // 2단이라 스스로 높이를 못 정한다. 창 높이에서 머리말 자리를 뺀다
        height: (MediaQuery.sizeOf(context).height - 300).clamp(420.0, 1000.0),
      );
    }
    if (_loading) return DelayedSpinner();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 첫 줄 — 잔디가 주인공이고 오늘 요약이 옆에 붙는다
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _Grass(grid: _grass)),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _Today(
                  people: _todayPeople,
                  staffTotal: _staffTotal,
                  visits: _today.length,
                  failed: _today.where((l) => l.event.failed).length,
                  yesterday: _yesterdayVisits,
                  last: _logs.isEmpty ? null : _logs.first.createdAt,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // 둘째 줄 — 순위 두 판
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Ranked(
                  title: '많이 들어온 사람',
                  rows: _topPeople,
                  avatars: true,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _Ranked(
                  title: '접속한 프로그램',
                  rows: _agents,
                  avatars: false,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        SegmentedTabs(
          labels: ['전체 $_total', '실패 $_failed'],
          selected: _tab,
          onSelect: (i) => _goList(tab: i),
        ),
        SizedBox(height: 16),
        // 전체 ↔ 실패만 옮길 때 전환이 걸린다 (장을 넘길 때는 안 걸린다)
        PaneTransition(
          step: _tab,
          child: _rows.isEmpty
              ? EmptyCard(
                  icon: CupertinoIcons.checkmark_shield,
                  text: _tab == 0 ? '아직 접속 기록이 없어요' : '로그인 실패가 없어요',
                )
              : _LogList(logs: _rows),
        ),
        PageNumbers(
          page: _listPage,
          pages: _listPages,
          onPick: (i) => _goList(page: i),
        ),
      ],
    );
  }
}
