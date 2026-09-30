part of 'ranking_screen.dart';

/// 매출 랭킹에서 사람을 누르면 — **어느 회원에게 얼마를 받아** 그 금액이 됐나
///
/// 환경정비 내역([_EnvScoreDetailScreen])과 같은 모양이다. 랭킹이 보고 있는
/// **달을 그대로 따라간다.** 서버가 랭킹과 같은 규칙으로 걸러 주므로
/// (워크인 신규는 빠진다) 합이 랭킹 금액과 맞는다.
class _SalesDetailScreen extends StatefulWidget {
  _SalesDetailScreen({required this.ranker, required this.period});

  final _Ranker ranker;

  /// `2026-09` — 랭킹이 보고 있는 달
  final String period;

  @override
  State<_SalesDetailScreen> createState() => _SalesDetailScreenState();
}

class _SalesDetailScreenState extends State<_SalesDetailScreen>
    with SkeletonDelay<_SalesDetailScreen> {
  List<SalesLine> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ScoreApi.sales(
        employeeId: widget.ranker.id,
        period: widget.period,
      );
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

  int get _total => _rows.fold(0, (sum, r) => sum + r.pricePaid);

  @override
  Widget build(BuildContext context) {
    final body = showSkeleton
        ? SkeletonGroup(
            child: SkeletonRows(rows: 6, avatar: 0, gap: 22, trailing: 60),
          )
        : _rows.isEmpty
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '이 달에 잡힌 매출이 없어요',
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
                _SalesRow(row: _rows[i]),
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
                Expanded(child: Text('회원별 매출', style: AppTextStyles.label)),
                if (!showSkeleton)
                  Text(
                    '총 ${_comma(_total)}원',
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

/// 등록 한 줄 — 회원 이름 · 신규/재등록 · 결제일 · 회차 · 금액
class _SalesRow extends StatelessWidget {
  _SalesRow({required this.row});

  final SalesLine row;

  @override
  Widget build(BuildContext context) {
    final renewal = row.type == RegistrationType.renewal;
    final tagColor = renewal ? AppColors.success : AppColors.primary;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        row.type.label,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: tagColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  '${row.purchasedAt.month}월 ${row.purchasedAt.day}일 · ${row.totalSessions}회',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '${_comma(row.pricePaid)}원',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
