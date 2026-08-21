import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/monitoring/monitoring_api.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/display/page_numbers.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/nav/pane_transition.dart';
import 'activity_panel.dart' show ago;

/// 이상 징후 — 접속·활동 로그에서 찾아낸 수상한 흐름 (모니터링 다섯째 탭)
///
/// 서버가 5분마다 훑어 채운다. 찾으면 대표에게 푸시가 간다.
/// **확인 처리는 MASTER 만** — 판단하는 자리라 ADMIN 은 보기만 한다.
class AnomalyPanel extends StatefulWidget {
  AnomalyPanel({super.key});

  @override
  State<AnomalyPanel> createState() => _AnomalyPanelState();
}

class _AnomalyPanelState extends State<AnomalyPanel> {
  static const _perPage = 100;

  List<Anomaly> _rows = const [];
  bool _loading = true;

  /// 0 미확인 · 1 전체 — 챙길 것이 먼저다
  int _tab = 0;
  int _page = 0;
  int _total = 0;
  int _open = 0;

  /// 장을 넘기는 동안 고정하는 기준선 (접속·활동 목록과 같은 이유)
  final DateTime _since = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await MonitoringApi.anomalies(
        unresolvedOnly: _tab == 0,
        limit: _perPage,
        offset: _page * _perPage,
        before: _since,
      );
      if (!mounted) return;
      setState(() {
        _rows = result.items;
        _total = result.total;
        _open = result.failed;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  void _go({int? tab, int? page}) {
    setState(() {
      if (tab != null && tab != _tab) {
        _tab = tab;
        _page = 0;
      }
      if (page != null) _page = page;
      // 내용을 비우지 않는다 — 비우면 탭을 옮길 때마다 깜빡인다
      // (activity_panel 과 같은 이유)
    });
    _load();
  }

  Future<void> _resolve(Anomaly item) async {
    try {
      await MonitoringApi.resolve(item.id);
      if (!mounted) return;
      AppToast.show(context, '확인 처리했어요');
      _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  int get _count => _tab == 0 ? _open : _total;

  int get _pages => (_count / _perPage).ceil();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return DelayedSpinner();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(
          labels: ['미확인 $_open', '전체 $_total'],
          selected: _tab,
          onSelect: (i) => _go(tab: i),
        ),
        SizedBox(height: 16),
        // 탭을 옮길 때만 전환이 걸린다 (장을 넘길 때는 안 걸린다)
        PaneTransition(
          step: _tab,
          child: _rows.isEmpty
              ? EmptyCard(
                  icon: CupertinoIcons.checkmark_shield,
                  text: _tab == 0 ? '확인할 이상 징후가 없어요' : '아직 이상 징후가 없어요',
                )
              : Container(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: AppDecorations.card(radius: 20),
                  child: Column(
                    children: [
                      for (var i = 0; i < _rows.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              height: 1,
                              color: AppColors.divider,
                            ),
                          ),
                        _Row(
                          item: _rows[i],
                          onResolve: _rows[i].open && myRole == Role.master
                              ? () => _resolve(_rows[i])
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        PageNumbers(
          page: _page,
          pages: _pages,
          onPick: (i) => _go(page: i),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  _Row({required this.item, this.onResolve});

  final Anomaly item;

  /// null 이면 버튼을 안 그린다 (이미 확인했거나 ADMIN 이라)
  final VoidCallback? onResolve;

  /// 종류마다 색 — 계정 탈취 계열이 제일 급하다
  Color get _color => switch (item.kind) {
    AnomalyKind.bruteForce || AnomalyKind.newDevice => AppColors.error,
    AnomalyKind.forbiddenBurst || AnomalyKind.bulkDelete => AppColors.warning,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        // 아직 확인 안 한 것은 면으로 먼저 눈에 들어오게 둔다
        color: item.open ? color.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.kind.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              item.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              item.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 118,
            child: Text(
              item.ip ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 66,
            child: Text(
              ago(item.createdAt),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 62,
            child: onResolve == null
                ? Text(
                    item.open ? '' : '확인함',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  )
                : Pressable(
                    onTap: onResolve!,
                    child: Container(
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '확인',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
