part of 'approval_screen.dart';

// ── 좌측 목록 ──

class _DocList extends StatelessWidget {
  _DocList({
    required this.docs,
    required this.selected,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
    this.onRetry,
  });

  final List<_Doc> docs;
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
                  '${docs.length}',
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
