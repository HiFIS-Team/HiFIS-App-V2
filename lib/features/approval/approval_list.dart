part of 'approval_screen.dart';

// ── 좌측 목록 ──

class _DocList extends StatelessWidget {
  _DocList({
    required this.docs,
    required this.month,
    required this.tally,
    required this.loading,
    required this.onPrev,
    required this.onNext,
    required this.selected,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
    this.onRetry,
  });

  final List<_Doc> docs;

  /// 보고 있는 달 — **올린 달** 기준이다
  final DateTime month;

  /// 그 달 통계 — 갈래 탭과 상관없이 **그 달 전부**를 센다
  final _MonthTally tally;

  final bool loading;
  final VoidCallback onPrev;

  /// null 이면 다음 달 화살표를 잠근다 (아직 오지 않은 달)
  final VoidCallback? onNext;

  final _Doc? selected;
  final _State filter;
  final ValueChanged<_State> onFilter;
  final ValueChanged<_Doc> onSelect;

  /// null 이면 올리기 버튼을 안 그린다 (MASTER·ADMIN)
  final VoidCallback? onCreate;

  /// 못 받았다 — 넘어오면 빈 문구 대신 **다시 시도**를 낸다 (2026-08-21)
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 글래스 헤더 버튼 영역만큼 비워둔다
        SizedBox(height: 64),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text('전자결재', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tally.total}',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (onCreate case final create?)
                Pressable(
                  onTap: create,
                  padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '결재 올리기',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        MonthBar(
          month: month,
          count: tally.total,
          loading: loading,
          onPrev: onPrev,
          onNext: onNext,
          padding: EdgeInsets.fromLTRB(16, 0, 24, 8),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: _MonthStats(tally: tally),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _StateTabs(selected: filter, onSelect: onFilter),
        ),
        Expanded(
          child: docs.isEmpty
              // 못 받은 것과 없는 것을 가른다 — 다른 화면과 같은 규칙이다
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: onRetry == null
                      ? Text(
                          '${filter.label} 결재가 없어요',
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        )
                      : FailedCard(onRetry: onRetry!),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _DocTile(
                    doc: docs[i],
                    selected: docs[i] == selected,
                    onTap: () => onSelect(docs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 대기 / 승인 / 반려 세그먼트
/// 상태 탭
///
/// **폰은 프로젝트 목록바(`_PhaseTabs`)와 같은 토큰**을 쓴다 — 두 목록이
/// 나란히 쓰이는 자리라 결이 다르면 바로 눈에 띈다.
/// 공용 [SegmentedTabs] 는 고른 칸 글자가 파랑이라 안 쓴다.
///
/// **PC 는 예전 모양 그대로** 둔다. 거기는 320 좌측 판 안이라 폰 목록바와
/// 같은 자리가 아니다.
class _StateTabs extends StatelessWidget {
  _StateTabs({required this.selected, required this.onSelect});

  final _State selected;
  final ValueChanged<_State> onSelect;

  /// 고른 칸에 깔리는 면 — 폰과 PC 가 모양이 다르다 (테두리 유무)
  BoxDecoration _fill(bool phone) => phone
      ? segmentFill(selected: true)
      : BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray100),
        );

  @override
  Widget build(BuildContext context) {
    final phone = !isDesktop;
    final index = _State.tabs.indexOf(selected);

    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: phone
          ? segmentTrack()
          : BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
            ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / _State.tabs.length;
          return Stack(
            children: [
              // 고른 면 **하나**가 미끄러진다 (2026-08-21 대표 요청).
              // 칸마다 켰다 껐다 하면 툭 튄다 — 다른 목록바와 같은 빠르기다
              if (index >= 0)
                AnimatedPositioned(
                  duration: slideDuration,
                  curve: slideCurve,
                  left: cell * index,
                  width: cell,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: _fill(phone)),
                ),
              Row(
                children: [
                  // 회수는 탭을 따로 두지 않는다 — 반려 칸에 같이 들어간다
                  for (final state in _State.tabs)
                    Expanded(
                      child: Pressable(
                        onTap: () => onSelect(state),
                        child: Center(
                          child: Text(
                            state.label,
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 13,
                              color: state == selected
                                  ? AppColors.primary
                                  : (phone
                                        ? AppColors.gray600
                                        : AppColors.gray500),
                              fontWeight: state == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DocTile extends StatefulWidget {
  _DocTile({required this.doc, required this.selected, required this.onTap});

  final _Doc doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends State<_DocTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(doc.kind.icon, size: 15, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              doc.kind.label,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
            Spacer(),
            _StateBadge(state: doc.state),
          ],
        ),
        SizedBox(height: 6),
        Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Avatar(name: doc.writer, size: 18),
            SizedBox(width: 6),
            Text(
              '${doc.writer} · ${_date(doc.date)}',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
            Spacer(),
            if (doc.amount > 0)
              Text(
                _won(doc.amount),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );

    // 폰은 회색 바탕 위에 카드 한 장씩 — 프로젝트 목록과 같은 결이다.
    // 데스크톱은 흰 판(`_DocList`) 안의 줄이라 제 배경이 없다.
    if (!isDesktop) {
      return Pressable(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: AppDecorations.card(),
          child: content,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  _EmptyDetail({required this.filter, required this.onCreate});

  final _State filter;

  /// null 이면 올리기 버튼을 안 그린다 (MASTER·ADMIN)
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.assignment_turned_in_outlined,
    title: '전자결재',
    text: '${filter.label} 결재가 아직 없어요',
    actionLabel: '결재 올리기',
    onAction: onCreate,
  );
}

/// 그 달 결재 통계 — 갈래별 금액과 건수, 그리고 종류별 금액 (2026-09-16 요청)
///
/// **접힌 채로 시작한다.** 펴 두면 목록 위를 예닐곱 줄이 차지해서, 정작
/// 보러 들어온 결재 줄이 아래로 밀린다. 한 줄로 요약하고 누르면 펼친다.
///
/// **금액이 없어도 그린다 (2026-09-16).** 달이 시작될 때 카드가 없다가
/// 어느 날 갑자기 생기면 **자리가 밀리고**, 0원이라는 것도 하나의 값이다 —
/// 올리자마자 여기 숫자가 오르는 것이 이 카드의 쓸모다.
class _MonthStats extends StatefulWidget {
  const _MonthStats({required this.tally});

  final _MonthTally tally;

  @override
  State<_MonthStats> createState() => _MonthStatsState();
}

class _MonthStatsState extends State<_MonthStats> {
  /// 펼쳤나 — **달을 넘겨도 유지된다.** 편 사람은 계속 보고 싶은 것이다
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tally = widget.tally;
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_open)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // **대기가 먼저다** — 아직 안 나간 돈이 판단할 거리라서.
                  // 0건이어도 줄을 남긴다 — 달이 갈 때 줄이 생겼다 없어지면
                  // 아래 종류 줄이 계속 오르내린다
                  for (final state in _State.tabs)
                    _line(
                      label: state.label,
                      count: tally.countOf(state),
                      amount: tally.amountOf(state),
                      tone: state.color,
                    ),
                  if (tally.kinds.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Container(height: 1, color: AppColors.gray100),
                    ),
                    for (final row in tally.kinds)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              row.key.icon,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.key.label,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              _money(row.value),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  SizedBox(height: 8),
                  Container(height: 1, color: AppColors.gray100),
                ],
              ),
            ),
          // **총액이 맨 아래다** (2026-09-16 요청) — 영수증처럼 갈래를 먼저
          // 훑고 합계로 끝난다. 접으면 이 줄만 남는다
          Pressable(
            onTap: () => setState(() => _open = !_open),
            padding: EdgeInsets.fromLTRB(16, 13, 14, 13),
            child: Row(
              children: [
                Text(
                  '결재 금액',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tally.live}건',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  _money(tally.liveAmount),
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  _open
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line({
    required String label,
    required int count,
    required int amount,
    required Color tone,
  }) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            // 없는 갈래는 점을 흐리게 — 있는 줄이 먼저 눈에 들어와야 한다
            color: count == 0 ? AppColors.gray200 : tone,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w600,
            color: count == 0 ? AppColors.textTertiary : null,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '$count건',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
        Text(
          _money(amount),
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: count == 0 ? AppColors.textTertiary : null,
            // 금액이 줄마다 자리를 맞춰야 견줄 수 있다
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// `1,240,000원` — 세 자리마다 끊는다
String _money(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer원';
}
