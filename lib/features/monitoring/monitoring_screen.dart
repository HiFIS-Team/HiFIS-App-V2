import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/access_log_api.dart';
import '../../core/api/api_exception.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/desktop_header.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/page_numbers.dart';
import '../../core/widgets/pressable.dart';
import 'activity_panel.dart';
import 'chat_audit_panel.dart';

/// 모니터링 — 누가 언제 들어와서 무엇을 했는지 (MASTER · ADMIN)
///
/// 탭 세 개다.
/// - **접속** 잔디(언제 붐볐나) · 오늘 요약 · 많이 들어온 사람 · 프로그램 · 들어온 순서
/// - **활동** 누가 무엇을 등록·수정·삭제했는지 ([ActivityPanel])
/// - **대화** 사내톡 방 목록과 주고받은 말 ([ChatAuditPanel])
///
/// **색은 앱 토큰 그대로다.** 진하기만 바꿔서 밀도를 만든다.
/// 서버가 준 값도 그대로 쓴다 — 프로그램 이름(`userAgent`)을 해석하지 않는 건
/// 지금 앱이 기기를 안 밝혀서 해석해 봐야 틀린 말이 되기 때문이다.
///
/// 활동·대화 판은 **고른 탭에서만 만든다.** 셋을 같이 띄우면 열어 보지도 않은
/// 대화를 조회하게 되고, 서버가 그걸 '대화방 목록 열람' 으로 남긴다.
class MonitoringScreen extends StatefulWidget {
  MonitoringScreen({super.key});

  /// 이 화면을 볼 수 있는 사람 — 서버 `/access-logs` 게이트와 같다
  static bool get visible => myRole == Role.master || myRole == Role.admin;

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

  /// 0 접속 · 1 활동 · 2 대화
  int _page = 0;

  /// 새로고침을 누른 횟수 — 활동·대화 판을 새로 만들어 다시 받게 하는 열쇠
  int _reload = 0;

  /// 접속 탭 안쪽 — 0 전체 · 1 실패만
  int _tab = 0;

  /// 상대 시각('방금', '12분 전')이 멈춰 보이지 않게 1분마다 다시 그린다.
  /// **다시 받아오지는 않는다** — 화면만 새로 그린다.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
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
              labels: ['접속', '활동', '대화'],
              selected: _page,
              onSelect: (i) => setState(() => _page = i),
            ),
            SizedBox(height: 16),
            if (_page == 1)
              ActivityPanel(key: ValueKey('activity-$_reload'))
            else if (_page == 2)
              ChatAuditPanel(
                key: ValueKey('chat-$_reload'),
                // 2단이라 스스로 높이를 못 정한다. 창 높이에서 머리말 자리를 뺀다
                height: (MediaQuery.sizeOf(context).height - 300).clamp(
                  420.0,
                  1000.0,
                ),
              )
            else if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              )
            else ...[
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
              if (_rows.isEmpty)
                EmptyCard(
                  icon: CupertinoIcons.checkmark_shield,
                  text: _tab == 0 ? '아직 접속 기록이 없어요' : '로그인 실패가 없어요',
                )
              else
                _LogList(logs: _rows),
              PageNumbers(
                page: _listPage,
                pages: _listPages,
                onPick: (i) => _goList(page: i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 잔디 — 최근 2주 × 24시간
// ---------------------------------------------------------------------------

/// 언제 붐볐는지를 한 판으로
///
/// GitHub 잔디는 가로가 '주'인데 여기는 **가로를 시간**으로 둔다.
/// 접속은 하루 안에서 시간대가 몰리는 값이라 그쪽이 훨씬 많이 보인다
/// (12주짜리로 그려 봤더니 기록이 며칠뿐이라 판이 거의 비어 있었다).
class _Grass extends StatelessWidget {
  _Grass({required this.grid});

  /// `[날짜][시간]` — 0번이 오늘
  final List<List<int>> grid;

  /// 제일 붐빈 칸 (농도의 기준)
  int get _top {
    var top = 0;
    for (final day in grid) {
      for (final count in day) {
        if (count > top) top = count;
      }
    }
    return top;
  }

  /// 건수를 네 단계 농도로 — 0은 빈 칸
  Color _shade(int count) {
    if (count == 0) return AppColors.gray50;
    final ratio = _top == 0 ? 0.0 : count / _top;
    final step = ratio > 0.66
        ? 1.0
        : ratio > 0.33
        ? 0.7
        : ratio > 0.12
        ? 0.45
        : 0.25;
    return AppColors.primary.withValues(alpha: step);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '최근 2주 접속',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ),
              SizedBox(width: 12),
              Spacer(),
              Text('적음', style: AppTextStyles.caption.copyWith(fontSize: 11)),
              SizedBox(width: 6),
              for (final step in const [0.0, 0.25, 0.45, 0.7, 1.0])
                Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: step == 0
                        ? AppColors.gray50
                        : AppColors.primary.withValues(alpha: step),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              SizedBox(width: 3),
              Text('많음', style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          SizedBox(height: 14),
          for (var d = 0; d < grid.length; d++) ...[
            if (d > 0) SizedBox(height: 3),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    _dayLabel(now, d),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: d == 0 ? FontWeight.w700 : FontWeight.w400,
                      color: d == 0
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1.5),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _shade(grid[d][h]),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 40),
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Center(
                    // 24칸에 숫자를 다 쓰면 뭉개진다 — 여섯 시간마다만
                    child: Text(
                      h % 6 == 0 ? '$h' : '',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 잔디 왼쪽 날짜 — 오늘은 '오늘', 나머지는 '8.2'
String _dayLabel(DateTime now, int daysAgo) {
  if (daysAgo == 0) return '오늘';
  final at = DateTime(now.year, now.month, now.day - daysAgo);
  return '${at.month}.${at.day}';
}

// ---------------------------------------------------------------------------
// 오늘 요약
// ---------------------------------------------------------------------------

/// 잔디 옆 세로 요약 — 오늘 것만 본다
class _Today extends StatelessWidget {
  _Today({
    required this.people,
    required this.staffTotal,
    required this.visits,
    required this.failed,
    required this.yesterday,
    required this.last,
  });

  final int people;

  /// 재직 인원 — 접속률의 분모
  final int staffTotal;

  final int visits;
  final int failed;

  /// 어제 접속 횟수
  final int yesterday;

  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final at = last;
    final diff = visits - yesterday;
    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(radius: 20),
      // 옆 잔디에 높이를 맞추면 남는 자리가 생긴다. **Spacer 를 쓰면
      // IntrinsicHeight 가 높이를 재는 동안 터지므로**(급여 화면에서 겪었다)
      // 위·아래 두 덩어리로 나누고 빈자리를 사이에 몰아준다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 7),
                  Text('오늘', style: AppTextStyles.label),
                ],
              ),
              SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$people',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '명',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                '들어왔어요',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          // 가운데 세 칸 — 숫자만 있으면 '많은지 적은지'를 알 수 없다.
          // 분모를 가진 값만 고른다 (몇 명 중 몇 명, 몇 번 중 몇 번, 어제 대비).
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cell(
                shape: _Donut(
                  ratio: staffTotal == 0 ? 0 : people / staffTotal,
                  color: AppColors.primary,
                ),
                label: '직원 접속률',
                value: '$people / $staffTotal명',
              ),
              SizedBox(height: 8),
              _Cell(
                shape: _Donut(
                  ratio: visits == 0 ? 0 : (visits - failed) / visits,
                  color: failed > 0 ? AppColors.error : AppColors.success,
                  // 아무도 안 왔으면 0% 가 아니라 잴 것이 없는 것이다
                  text: visits == 0 ? '—' : null,
                ),
                label: '로그인 성공률',
                value: '${visits - failed} / $visits회',
              ),
              SizedBox(height: 8),
              _Cell(
                shape: _Compare(today: visits, yesterday: yesterday),
                label: '어제보다',
                value: diff == 0 ? '같아요' : '${diff > 0 ? '+' : ''}$diff회',
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16),
              Container(height: 1, color: AppColors.divider),
              SizedBox(height: 12),
              _Line(label: '접속 횟수', value: '$visits회'),
              SizedBox(height: 8),
              _Line(
                label: '로그인 실패',
                value: '$failed건',
                // 0이면 굳이 빨갛게 물들이지 않는다 — 아무 일도 없다는 뜻이다
                color: failed > 0 ? AppColors.error : null,
              ),
              SizedBox(height: 8),
              _Line(label: '마지막 접속', value: at == null ? '—' : _clock(at)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 이름 — 값 한 줄
class _Line extends StatelessWidget {
  _Line({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ),
      SizedBox(width: 8),
      Text(
        value,
        style: AppTextStyles.body2.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 왼쪽에 모양, 오른쪽에 이름·값 — 오늘 요약 가운데 세 칸이 같은 틀을 쓴다
class _Cell extends StatelessWidget {
  _Cell({required this.shape, required this.label, required this.value});

  /// 도넛이든 막대든 40~46 정사각 안에 들어오는 것
  final Widget shape;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        shape,
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 원형 게이지 — 링이 차오르고 가운데에 퍼센트
class _Donut extends StatelessWidget {
  _Donut({required this.ratio, required this.color, this.text});

  /// 0~1
  final double ratio;

  final Color color;

  /// 가운데 글자를 직접 정할 때 (잴 것이 없으면 '—')
  final String? text;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _DonutPainter(ratio: clamped, color: color),
        child: Center(
          child: Text(
            text ?? '${(clamped * 100).round()}%',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  /// 링 두께 — 46짜리 안에서 가운데 글자가 살아남는 굵기
  static const _stroke = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(_stroke / 2, _stroke / 2) &
        Size(size.width - _stroke, size.height - _stroke);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.gray200,
    );

    if (ratio <= 0) return;
    canvas.drawArc(
      rect,
      // 12시에서 시작해 시계 방향
      -math.pi / 2,
      math.pi * 2 * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.ratio != ratio || old.color != color;
}

/// 오늘·어제 막대 두 개 — 도넛만 셋이면 셋 다 같은 값처럼 보인다
class _Compare extends StatelessWidget {
  _Compare({required this.today, required this.yesterday});

  final int today;
  final int yesterday;

  static const _size = 46.0;

  /// 막대 높이 — 많은 쪽이 꽉 찬다. 0이어도 밑동은 남긴다
  double _height(int count) {
    final top = math.max(today, yesterday);
    if (top == 0) return 4;
    return 4 + (_size - 4) * (count / top);
  }

  Widget _bar(int count, Color color) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        width: 13,
        height: _height(count),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _size,
    height: _size,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(yesterday, AppColors.gray300),
        SizedBox(width: 6),
        _bar(today, AppColors.primary),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 순위 두 판
// ---------------------------------------------------------------------------

/// 가로 막대 순위 — 사람과 프로그램이 같은 모양을 쓴다
class _Ranked extends StatelessWidget {
  _Ranked({required this.title, required this.rows, required this.avatars});

  final String title;

  /// (이름, 건수) — 이미 많은 순으로 정렬돼 있다
  final List<(String, int)> rows;

  /// 왼쪽에 아바타를 둘지 (프로그램에는 안 둔다)
  final bool avatars;

  @override
  Widget build(BuildContext context) {
    final top = rows.isEmpty ? 0 : rows.first.$2;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '아직 없어요',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              Row(
                children: [
                  if (avatars) ...[
                    Avatar(name: rows[i].$1, size: 24),
                    SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: avatars ? 58 : 120,
                    child: Text(
                      rows[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 8, color: AppColors.gray50),
                          FractionallySizedBox(
                            // 1등이 꽉 차고 나머지는 그 비율만큼
                            widthFactor: top == 0 ? 0 : rows[i].$2 / top,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gradientStart,
                                    AppColors.gradientEnd,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${rows[i].$2}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 들어온 순서
// ---------------------------------------------------------------------------

/// 접속 목록 — 실패한 줄은 빨간 면으로 눈에 먼저 들어오게 둔다
class _LogList extends StatelessWidget {
  _LogList({required this.logs});

  final List<AccessLog> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Container(height: 1, color: AppColors.divider),
              ),
            _LogRow(log: logs[i]),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  _LogRow({required this.log});

  final AccessLog log;

  /// 로그인에 성공한 사람 이름 — 실패거나 명단에 없으면 null
  String? get _name {
    final id = log.employeeId;
    if (id == null) return null;
    final name = StaffDirectory.instance.byId(id)?.name;
    return name == null || name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final failed = log.event.failed;
    final name = _name;
    final color = failed ? AppColors.error : AppColors.success;

    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: failed
            ? AppColors.error.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 14),
          if (name != null)
            Avatar(name: name, size: 32)
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.question,
                size: 16,
                color: AppColors.gray500,
              ),
            ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name ?? (log.email ?? '알 수 없음'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: failed ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  failed && name != null
                      ? '${log.email ?? ''} 로 로그인 실패'
                      : log.event.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          // 접속한 프로그램 — 서버가 받은 문자열 그대로
          Expanded(
            flex: 3,
            child: Text(
              log.userAgent ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              log.ip ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 66,
            child: Text(
              _ago(log.createdAt),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 새로 받아오기 — 헤더 오른쪽
class _RefreshButton extends StatelessWidget {
  _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: AppColors.gray500),
            SizedBox(width: 6),
            Text(
              '새로고침',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '방금' · '12분 전' · '3시간 전' · '8.2.'
String _ago(DateTime time) {
  final gap = DateTime.now().difference(time);
  if (gap.inMinutes < 1) return '방금';
  if (gap.inMinutes < 60) return '${gap.inMinutes}분 전';
  if (gap.inHours < 24) return '${gap.inHours}시간 전';
  if (gap.inDays < 7) return '${gap.inDays}일 전';
  return '${time.month}.${time.day}.';
}

/// '09:14'
String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
