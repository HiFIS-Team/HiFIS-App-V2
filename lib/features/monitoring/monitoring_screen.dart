import 'dart:async';

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
import '../../core/widgets/pressable.dart';

/// 모니터링 — 누가 언제 어디서 들어왔는지 (MASTER · ADMIN)
///
/// 관제실처럼 **큰 숫자 → 하루 흐름 → 들어온 순서**로 위에서 아래로 읽힌다.
/// 색·글꼴·카드는 앱 디자인 시스템 그대로다 — 배치만 모니터링 화면 결이다.
///
/// 서버가 준 값을 그대로 보여준다. 접속한 프로그램 이름(`userAgent`)도
/// 해석하지 않고 원문을 쓴다 — 지금은 앱이 기기를 안 밝혀서 해석해 봐야
/// 틀린 말이 된다.
class MonitoringScreen extends StatefulWidget {
  MonitoringScreen({super.key});

  /// 이 화면을 볼 수 있는 사람 — 서버 `/access-logs` 게이트와 같다
  static bool get visible => myRole == Role.master || myRole == Role.admin;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  List<AccessLog> _logs = const [];
  bool _loading = true;

  /// 0 전체 · 1 실패만
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
      final rows = await AccessLogApi.list(limit: 300);
      if (!mounted) return;
      setState(() {
        _logs = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

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

  List<AccessLog> get _shown => _tab == 0
      ? _logs
      : [
          for (final log in _logs)
            if (log.event.failed) log,
        ];

  /// 오늘 들어온 사람 수 (같은 사람이 여러 번 들어와도 하나)
  int get _todayPeople => {
    for (final log in _today)
      if (!log.event.failed && log.employeeId != null) log.employeeId!,
  }.length;

  int get _todayFailed => _today.where((log) => log.event.failed).length;

  /// 24시간 막대 — 시간대별 성공·실패 건수
  List<(int, int)> get _hours {
    final success = List.filled(24, 0);
    final failed = List.filled(24, 0);
    for (final log in _today) {
      final at = log.createdAt.hour;
      if (log.event.failed) {
        failed[at]++;
      } else {
        success[at]++;
      }
    }
    return [for (var i = 0; i < 24; i++) (success[i], failed[i])];
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
              subtitle: '누가 언제 어디서 들어왔는지 확인해요',
              trailing: _RefreshButton(onTap: _load),
            ),
            SizedBox(height: 22),
            if (_loading)
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
              _Numbers(
                total: _logs.length,
                people: _todayPeople,
                failed: _todayFailed,
                last: _logs.isEmpty ? null : _logs.first.createdAt,
              ),
              SizedBox(height: 16),
              _HourChart(hours: _hours),
              SizedBox(height: 16),
              SegmentedTabs(
                labels: ['전체 ${_logs.length}', '실패 $_failedTotal'],
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              SizedBox(height: 16),
              if (_shown.isEmpty)
                EmptyCard(
                  icon: CupertinoIcons.checkmark_shield,
                  text: _tab == 0 ? '아직 접속 기록이 없어요' : '로그인 실패가 없어요',
                )
              else
                _LogList(logs: _shown),
            ],
          ],
        ),
      ),
    );
  }

  int get _failedTotal => _logs.where((log) => log.event.failed).length;
}

// ---------------------------------------------------------------------------
// 큰 숫자 넷
// ---------------------------------------------------------------------------

/// 맨 위 숫자 판 — 멀리서도 읽히게 크게 세운다
class _Numbers extends StatelessWidget {
  _Numbers({
    required this.total,
    required this.people,
    required this.failed,
    required this.last,
  });

  final int total;
  final int people;
  final int failed;
  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final at = last;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: AppDecorations.card(radius: 20),
      child: Row(
        children: [
          Expanded(
            child: _Cell(value: '$total', label: '받아온 기록', color: null),
          ),
          _Divider(),
          Expanded(
            child: _Cell(
              value: '$people',
              suffix: '명',
              label: '오늘 접속한 사람',
              color: AppColors.primary,
            ),
          ),
          _Divider(),
          Expanded(
            child: _Cell(
              value: '$failed',
              label: '오늘 로그인 실패',
              // 0이면 굳이 빨갛게 물들이지 않는다 — 아무 일도 없다는 뜻이다
              color: failed > 0 ? AppColors.error : null,
            ),
          ),
          _Divider(),
          Expanded(
            child: _Cell(
              value: at == null ? '—' : _clock(at),
              label: '마지막 접속',
              color: null,
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 46, color: AppColors.divider);
}

/// 숫자 한 칸 — 값이 위, 이름이 아래
class _Cell extends StatelessWidget {
  _Cell({
    required this.value,
    required this.label,
    required this.color,
    this.suffix,
    this.small = false,
  });

  final String value;
  final String? suffix;
  final String label;

  /// null이면 기본 글자색 (강조할 것만 색을 준다)
  final Color? color;

  /// 시각처럼 글자가 긴 값
  final bool small;

  @override
  Widget build(BuildContext context) {
    // 칸 가운데에 세운다. 왼쪽에 붙이면 칸이 넓어서 값 오른쪽이 휑하게 비고,
    // 네 덩어리가 왼쪽으로 쏠린 것처럼 보인다 (실제로 그렇게 보였다).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: small ? 26 : 34,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (suffix != null)
              Text(
                suffix!,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.textSecondary,
                ),
              ),
          ],
        ),
        SizedBox(height: 4),
        // 칸이 좁아지면 '오늘 접속한 사람' 같은 이름이 두 줄로 접히면서
        // 네 칸 높이가 서로 달라진다 — 한 줄로 자른다
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 24시간 흐름
// ---------------------------------------------------------------------------

/// 오늘 시간대별 접속 — 실패는 위에 빨간 조각으로 얹는다
class _HourChart extends StatelessWidget {
  _HourChart({required this.hours});

  /// 0시부터 23시까지 (성공, 실패)
  final List<(int, int)> hours;

  @override
  Widget build(BuildContext context) {
    final top = hours.fold(0, (a, h) => h.$1 + h.$2 > a ? h.$1 + h.$2 : a);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '오늘 시간대별 접속',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ),
              SizedBox(width: 12),
              Spacer(),
              _Legend(color: AppColors.primary, text: '로그인'),
              SizedBox(width: 12),
              _Legend(color: AppColors.error, text: '실패'),
            ],
          ),
          SizedBox(height: 18),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 24; i++)
                  Expanded(
                    child: _Bar(
                      success: hours[i].$1,
                      failed: hours[i].$2,
                      top: top,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 24; i++)
                Expanded(
                  child: Center(
                    // 24칸에 숫자를 다 쓰면 뭉개진다 — 여섯 시간마다만
                    child: Text(
                      i % 6 == 0 ? '$i' : '',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
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

class _Legend extends StatelessWidget {
  _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 5),
      Text(text, style: AppTextStyles.caption.copyWith(fontSize: 12)),
    ],
  );
}

/// 막대 한 칸
class _Bar extends StatelessWidget {
  _Bar({required this.success, required this.failed, required this.top});

  final int success;
  final int failed;

  /// 제일 높은 칸의 값 (0이면 다 비어 있다)
  final int top;

  @override
  Widget build(BuildContext context) {
    final total = success + failed;
    // 최대 높이 88 — 값이 있는데 안 보일 만큼 낮아지지 않게 최소 3을 준다
    final height = top == 0
        ? 0.0
        : (total / top * 88).clamp(total > 0 ? 3 : 0, 88);
    final failedHeight = total == 0 ? 0.0 : height * failed / total;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (failedHeight > 0)
            Container(
              height: failedHeight,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          Container(
            height: height - failedHeight,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: failedHeight > 0
                  ? null
                  : BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ),
          SizedBox(height: 4),
          // 바닥 눈금 — 24칸 전부 같은 색이어야 한 줄로 이어져 보인다.
          // 지금 시각만 파랗게 해 봤더니 막대 밑에 정체 모를 선이 하나 더
          // 있는 것처럼 보였다.
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
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
