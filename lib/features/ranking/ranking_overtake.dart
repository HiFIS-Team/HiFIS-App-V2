part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 추월 기록 (대표·관리자)
// ---------------------------------------------------------------------------

/// 랭킹 화면을 **관리 화면으로** 보는 사람 (MASTER · ADMIN)
///
/// 이 사람들은 매출·수업 실적이 없어서 '내 순위' 자리가 늘 비어 있다.
/// 그 자리에 **누가 누구를 앞질렀는지**를 대신 놓는다.
bool get _isRankBoss => myRole == Role.master || myRole == Role.admin;

/// 누가 누구를 무슨 차이로 앞질렀나 — '내 순위' 자리를 대신한다
///
/// 서버가 5분마다 순위를 찍어 직전과 비교한 결과다. 랭킹은 볼 때마다 원본에서
/// 다시 계산하는 값이라, 서버가 남겨 두지 않으면 '언제 바뀌었나'를 알 수 없다.
class _OvertakeCard extends StatefulWidget {
  _OvertakeCard({required this.metric, required this.branch});

  final _Metric metric;

  /// 지점 필터 — 전체면 [_allBranches]
  final String branch;

  @override
  State<_OvertakeCard> createState() => _OvertakeCardState();
}

class _OvertakeCardState extends State<_OvertakeCard> {
  /// 카드에 몇 줄까지 — 옆 시상대와 높이가 비슷해지는 수다
  static const _rows = 4;

  List<RankOvertake> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_OvertakeCard old) {
    super.didUpdateWidget(old);
    // 탭을 옮기면 그 항목 것으로 다시 받는다 (지점은 받아 둔 것에서 거른다)
    if (old.metric != widget.metric) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ScoreApi.overtakes(metric: widget.metric.wire);
      if (!mounted) return;
      setState(() {
        _all = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 지점을 골랐으면 **앞지른 사람**이 그 지점인 것만 남긴다
  List<RankOvertake> get _visible {
    if (widget.branch == _allBranches) return _all;
    return [
      for (final row in _all)
        if (StaffDirectory.instance.branchName(row.moverBranchId) ==
            widget.branch)
          row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible.take(_rows).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // '내 순위' 자리를 대신하는 카드라 테두리도 같게 둔다
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('추월 기록', style: AppTextStyles.label)),
              Text(
                widget.metric.short,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (_loading)
            DelayedSpinner()
          else if (rows.isEmpty)
            EmptyCard(
              icon: CupertinoIcons.arrow_up_arrow_down,
              text: '아직 순위가 바뀐 적이 없어요',
              framed: false,
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Container(height: 1, color: AppColors.divider),
                ),
              _OvertakeLine(row: rows[i], metric: widget.metric),
            ],
        ],
      ),
    );
  }
}

/// 추월 한 줄 — 누가 누구를 · 얼마 차이로 · 언제
class _OvertakeLine extends StatelessWidget {
  _OvertakeLine({required this.row, required this.metric});

  final RankOvertake row;
  final _Metric metric;

  /// '방금' · '12분 전' · '3시간 전' · '2일 전'
  String get _ago {
    final gap = DateTime.now().difference(row.createdAt);
    if (gap.inMinutes < 1) return '방금';
    if (gap.inMinutes < 60) return '${gap.inMinutes}분 전';
    if (gap.inHours < 24) return '${gap.inHours}시간 전';
    return '${gap.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(name: row.moverName, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                row.moverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                CupertinoIcons.arrow_right,
                size: 12,
                color: AppColors.textTertiary,
              ),
            ),
            Flexible(
              child: Text(
                row.passedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Spacer(),
            Text(
              _ago,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: 32),
          child: Text(
            '${_gapLabel(metric, row.gap)} 차이로 ${row.rank}위가 됐어요',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
