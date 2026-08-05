import 'package:flutter/cupertino.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/monitoring/monitoring_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/nav/pane_transition.dart';
import '../../../core/util/when.dart';

/// 성능 지표 — 서버가 얼마나 빠른가 (모니터링 넷째 탭)
///
/// 미들웨어가 **모든 요청**의 소요 시간을 재서 분 단위로 모아 둔 값이다.
/// 백분위는 버킷에서 보간한 근사치라 실제와 몇 % 차이가 날 수 있다.
class PerformancePanel extends StatefulWidget {
  PerformancePanel({super.key});

  @override
  State<PerformancePanel> createState() => _PerformancePanelState();
}

class _PerformancePanelState extends State<PerformancePanel> {
  /// 볼 수 있는 기간 — 라벨과 분
  static const _spans = [('1시간', 60), ('6시간', 360), ('24시간', 1440)];

  ApiMetrics? _data;
  bool _loading = true;
  int _span = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await MonitoringApi.metrics(minutes: _spans[_span].$2);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  void _pick(int index) {
    // 내용을 비우지 않는다 — 비우면 기간을 옮길 때마다 깜빡인다
    setState(() => _span = index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return DelayedSpinner();
    }

    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(
          labels: [for (final span in _spans) span.$1],
          selected: _span,
          onSelect: _pick,
        ),
        SizedBox(height: 16),
        // 기간을 옮길 때 전환이 걸린다
        PaneTransition(
          step: _span,
          child: data == null || data.requests == 0
              ? EmptyCard(
                  icon: CupertinoIcons.speedometer,
                  text: '아직 측정된 요청이 없어요',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Numbers(data: data),
                    SizedBox(height: 16),
                    _Timeline(points: data.timeline),
                    SizedBox(height: 16),
                    _Slowest(rows: data.slowest),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 큰 숫자 여섯 — 한눈에 보는 값
class _Numbers extends StatelessWidget {
  _Numbers({required this.data});

  final ApiMetrics data;

  @override
  Widget build(BuildContext context) {
    // p95 는 '스무 명 중 제일 느린 한 명'이 겪는 시간이라 체감에 제일 가깝다
    final slow = data.p95Ms >= 1000;
    final broken = data.errorRate > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('응답 속도', style: AppTextStyles.label)),
              Text(
                '요청 ${data.requests}건 · 분당 ${data.rpm}',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _cell('평균', '${data.avgMs}ms', AppColors.textPrimary),
              _divider(),
              _cell('중간(p50)', '${data.p50Ms}ms', AppColors.textPrimary),
              _divider(),
              _cell(
                '상위 5%(p95)',
                '${data.p95Ms}ms',
                slow ? AppColors.warning : AppColors.success,
              ),
              _divider(),
              _cell('상위 1%(p99)', '${data.p99Ms}ms', AppColors.textPrimary),
            ],
          ),
          SizedBox(height: 16),
          Container(height: 1, color: AppColors.gray100),
          SizedBox(height: 16),
          Row(
            children: [
              _cell(
                '서버 오류',
                '${data.errorRate}%',
                broken ? AppColors.error : AppColors.success,
              ),
              _divider(),
              _cell('요청 오류', '${data.clientErrorRate}%', AppColors.textPrimary),
              _divider(),
              _cell('가장 느렸던', '${data.maxMs}ms', AppColors.textPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 19, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.gray100);
}

/// 분마다 요청 수 — 막대 하나가 1분이다
class _Timeline extends StatelessWidget {
  _Timeline({required this.points});

  final List<MetricPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox.shrink();
    final peak = points.map((p) => p.count).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('요청 흐름', style: AppTextStyles.label)),
              Text(
                '제일 붐빈 분 $peak건',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0.6),
                      child: Container(
                        // 0건인 분도 자리는 남긴다 — 비어 있는 게 보여야 한다
                        height: (point.count / peak * 68).clamp(2.0, 68.0),
                        decoration: BoxDecoration(
                          // 그 분에 5xx 가 있었으면 빨갛게
                          color: point.errors > 0
                              ? AppColors.error
                              : AppColors.primary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                _clock(points.first.minute),
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              Spacer(),
              Text(
                _clock(points.last.minute),
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _clock(DateTime time) => clockLabel(time);
}

/// 느린 주소 — 손볼 곳이 어디인지
class _Slowest extends StatelessWidget {
  _Slowest({required this.rows});

  final List<SlowRoute> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('느린 API', style: AppTextStyles.label),
          SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.divider),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      rows[i].method,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].route,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(fontSize: 13),
                    ),
                  ),
                  SizedBox(width: 10),
                  _stat('${rows[i].count}건', AppColors.textTertiary),
                  _stat('평균 ${rows[i].avgMs}ms', AppColors.textSecondary),
                  _stat(
                    'p95 ${rows[i].p95Ms}ms',
                    rows[i].p95Ms >= 1000
                        ? AppColors.warning
                        : AppColors.textPrimary,
                  ),
                  if (rows[i].errors > 0)
                    _stat('오류 ${rows[i].errors}', AppColors.error),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String text, Color color) => SizedBox(
    width: 92,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
