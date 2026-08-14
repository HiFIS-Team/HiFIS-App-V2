part of 'ranking_screen.dart';

/// 환경정비 랭킹에서 사람을 누르면 — **그 사람이 항목마다 몇 점 땄나**
///
/// 랭킹판은 합계만 보여줘서 `왜 저 사람이 위인지`를 알 수 없다.
/// 여기서 세탁 12점 · 빨래정리 8점 처럼 **딴 자리를 펼쳐 준다.**
///
/// 보고 있는 **달을 그대로 따라간다** — 랭킹이 지난달을 보고 있으면 여기도 지난달이다.
///
/// 서버에 집계 엔드포인트를 새로 만들지 않았다. `/env-logs?employeeId=&period=`
/// 가 이미 있고, 한 사람 한 달치는 많아야 수백 줄이라 앱에서 묶는 편이 싸다.
class _EnvScoreDetailScreen extends StatefulWidget {
  _EnvScoreDetailScreen({required this.ranker, required this.period});

  final _Ranker ranker;

  /// `2026-08` — 랭킹이 보고 있는 달
  final String period;

  @override
  State<_EnvScoreDetailScreen> createState() => _EnvScoreDetailScreenState();
}

/// 항목 하나 — 몇 번 해서 몇 점
class _EnvItemScore {
  _EnvItemScore(this.name, this.count, this.points);

  final String name;
  final int count;
  final int points;
}

class _EnvScoreDetailScreenState extends State<_EnvScoreDetailScreen>
    with SkeletonDelay<_EnvScoreDetailScreen> {
  List<_EnvItemScore> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await EnvApi.logs(
        employeeId: widget.ranker.id,
        period: widget.period,
      );
      // 이름으로 묶는다 — '기타(창고정리)' 처럼 괄호가 붙은 것은 **따로 센다.**
      // 무엇을 했는지가 그 괄호 안에 있어서, 합쳐 버리면 '기타 30점' 만 남는다.
      final byName = <String, _EnvItemScore>{};
      for (final log in logs) {
        final row = byName[log.itemName];
        byName[log.itemName] = _EnvItemScore(
          log.itemName,
          (row?.count ?? 0) + 1,
          (row?.points ?? 0) + log.points,
        );
      }
      final rows = byName.values.toList()
        ..sort((a, b) => b.points.compareTo(a.points));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  int get _total => _rows.fold(0, (sum, r) => sum + r.points);

  @override
  Widget build(BuildContext context) {
    final body = showSkeleton
        ? SkeletonGroup(
            child: SkeletonRows(rows: 6, avatar: 0, gap: 22, trailing: 44),
          )
        : _rows.isEmpty
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '이 달에 한 환경정비가 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.divider),
                _EnvScoreRow(row: _rows[i], max: _rows.first.points),
              ],
            ],
          );

    final card = Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Row(
              children: [
                Expanded(child: Text('항목별 점수', style: AppTextStyles.label)),
                if (!showSkeleton)
                  Text(
                    '총 $_total점',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          body,
        ],
      ),
    );

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: widget.ranker.name,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            bottomBarInset(context),
          ),
          children: [card],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.fromLTRB(28, 26, 28, 26),
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 18),
            child: Text(widget.ranker.name, style: AppTextStyles.title3),
          ),
          card,
        ],
      ),
    );
  }
}

/// 항목 한 줄 — 이름 · 몇 번 · 점수, 뒤에 옅은 막대
class _EnvScoreRow extends StatelessWidget {
  _EnvScoreRow({required this.row, required this.max});

  final _EnvItemScore row;

  /// 제일 많이 딴 항목의 점수 — 막대 길이의 기준이다
  final int max;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 11, horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${row.count}회',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            SizedBox(width: 10),
            Text(
              '${row.points}점',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ProgressBar(ratio: max == 0 ? 0 : row.points / max),
      ],
    ),
  );
}
