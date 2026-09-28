part of 'home_screen.dart';

/// OT 신청 — 홈 카드 (2026-09-28 대표 요청)
///
/// 대표·관리자는 결재 대기와 오늘 출근 사이, 직원·점장은 프로젝트와 공지
/// 사이에 선다. 줄은 **할 일 순서**다 — 배정하는 사람에게는 미배정이,
/// 맡은 사람에게는 수락 대기가 먼저 온다. 누르면 OT 신청 화면이 열린다.
class _OtCard extends StatefulWidget {
  _OtCard();

  @override
  State<_OtCard> createState() => _OtCardState();
}

class _OtCardState extends State<_OtCard> {
  List<OtRequest> _rows = const [];

  int get _max => isDesktop ? 4 : phoneCardRows;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rows = await OtApi.list();
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // 홈이 막히면 안 된다 — 비어 있는 카드로 둔다
    }
  }

  Future<void> _open() async {
    await showFullPage<void>(context, (_) => OtScreen());
    _fetch();
  }

  /// 아직 안 끝난 것 — 확정은 오늘 이후 것만 남긴다
  List<OtRequest> get _todo {
    final today = DateUtils.dateOnly(DateTime.now());
    int rank(OtRequest r) => switch (r.status) {
      OtStatus.pending => myRole.strong ? 0 : 1,
      OtStatus.assigned => r.assigneeId == currentUser?.id ? 0 : 1,
      OtStatus.accepted => 2,
    };
    return [
      for (final r in _rows)
        if (r.status != OtStatus.accepted ||
            (r.convertedAt == null && !r.visitDate.isBefore(today)))
          r,
    ]..sort((a, b) {
      final gap = rank(a).compareTo(rank(b));
      return gap != 0 ? gap : a.visitDate.compareTo(b.visitDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _todo;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'OT 신청', count: rows.length, onOpenAll: _open),
          SizedBox(height: 14),
          if (rows.isEmpty)
            _CardBody(
              child: Center(
                child: EmptyCard(
                  icon: Icons.event_available_rounded,
                  text: '새 OT 신청이 없어요',
                  framed: false,
                ),
              ),
            )
          else
            _CardBody(
              child: _StackedRows(
                rows: [
                  for (final r in rows.take(_max))
                    Pressable(
                      onTap: _open,
                      child: _OtRow(ot: r),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OtRow extends StatelessWidget {
  _OtRow({required this.ot});

  final OtRequest ot;

  @override
  Widget build(BuildContext context) {
    final color = switch (ot.status) {
      OtStatus.pending => AppColors.warning,
      OtStatus.assigned => AppColors.primary,
      OtStatus.accepted => AppColors.success,
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ot.name}님',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                ot.assigneeName == null
                    ? ot.when
                    : '${ot.when} · ${ot.assigneeName}',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          ot.status.label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
