part of 'work_screen.dart';

/// 환경정비 점검 — 항목이 2열로 내려가며 배치되고,
/// 각 항목의 좌우 −/+ 버튼으로 오늘 수행 횟수를 조절한다.
///
/// **흰 카드를 안 두른다** (2026-09-01 대표 요청). 머리말은 세션 기록·회원
/// 친절도처럼 바탕 위에 서고, 칩은 화면 폭을 다 쓴다 — 카드 여백 20이 좌우로
/// 빠지면서 칩이 그만큼 넓어져서 누르기 편하다.
class _ChecklistCard extends StatelessWidget {
  _ChecklistCard({
    required this.items,
    required this.counts,
    required this.onAdjust,
    required this.onShowHistory,
  });

  final List<EnvItem> items;

  /// 항목 id 별 오늘 수행 횟수
  final Map<String, int> counts;

  /// (항목, 증감량) — +1 또는 -1
  final void Function(EnvItem item, int delta) onAdjust;

  /// 오늘 내역 시트 열기 (폰 전용)
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, c) => sum + c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 머리말은 **카드 밖**이다 — 세션 기록과 같은 모양이다
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                '오늘 점검 항목',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              // 데스크톱은 아래에 내역 카드가 있어 총 횟수만 적고,
              // 폰은 누르면 오늘 수행 내역이 열린다
              if (isDesktop)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '총 $total회',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                SeeAllButton(onTap: onShowHistory, label: '총 $total회'),
            ],
          ),
        ),
        SizedBox(height: 12),
        // 데스크톱은 폭이 넓어 한 줄에 여러 개를 넣는다.
        // 칩이 찌그러지지 않게 남는 폭에 맞춰 개수를 정한다(최대 4개).
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = isDesktop
                ? (constraints.maxWidth / 220).floor().clamp(2, 4)
                : 2;
            // 칩마다 글자를 알아서 줄이면 긴 라벨('화장실청소')만 작아 보인다.
            // 제일 긴 라벨이 들어가는 크기를 구해 모든 칩이 같이 쓴다 —
            // 폰은 칸이 좁아 애플·안드로이드 모두 필요하다.
            final chipWidth =
                (constraints.maxWidth - 10 * (columns - 1)) / columns;
            final fontSize = _chipFontSize([
              for (final item in items) item.name,
            ], chipWidth);
            return Column(
              children: [
                for (var i = 0; i < items.length; i += columns) ...[
                  if (i > 0) SizedBox(height: 10),
                  Row(
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) SizedBox(width: 10),
                        Expanded(
                          child: i + col < items.length
                              ? _CountChip(
                                  label: items[i + col].name,
                                  count: counts[items[i + col].id] ?? 0,
                                  fontSize: fontSize,
                                  onAdjust: (delta) =>
                                      onAdjust(items[i + col], delta),
                                )
                              : SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 좌 − / 우 + 버튼이 달린 횟수 칩
/// 칩 안에서 글자가 쓸 수 있는 폭에 맞춰, 모든 라벨이 함께 쓸 글자 크기를 구한다.
///
/// 제일 긴 라벨이 들어가는 크기를 찾아 전부에 같은 값을 준다.
/// 굵은 글씨(수행한 칩)를 기준으로 재서, 눌렀을 때 글자 크기가 흔들리지 않는다.
double _chipFontSize(List<String> items, double chipWidth) {
  const base = 14.0;
  final available = chipWidth - _CountChip.buttonWidth * 2 - 6;
  if (available <= 0) return base;

  var size = base;
  for (final label in items) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTextStyles.body2.copyWith(
          fontSize: base,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    if (painter.width > available) {
      final fit = base * available / painter.width;
      if (fit < size) size = fit;
    }
  }
  return size.clamp(10.0, base);
}

class _CountChip extends StatelessWidget {
  _CountChip({
    required this.label,
    required this.count,
    required this.onAdjust,
    required this.fontSize,
  });

  final String label;
  final int count;
  final ValueChanged<int> onAdjust;

  /// 모든 칩이 함께 쓰는 글자 크기 — 길이와 상관없이 같아 보이게 한다
  final double fontSize;

  /// 좌우 −/+ 버튼 한 개의 폭
  ///
  /// **48 이다** (2026-09-01 대표 요청 — "누르기 편하게"). 흰 카드를 걷으면서
  /// 칩이 좌우로 40 넓어졌는데, 그 자리를 글자만 쓰면 버튼은 그대로 좁다.
  static const double buttonWidth = 48;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
      // 애플 손가락 최소 44 보다 넉넉하게 — 하루에 수십 번 누르는 자리다
      height: 56,
      decoration: BoxDecoration(
        // **안 한 칩은 흰 면이다** (2026-09-01 대표 지적). 예전에는 `gray50`
        // 이었는데, 흰 카드를 걷으면서 그 색이 화면 바탕과 **완전히 같아졌다**
        // (라이트에서 둘 다 `#F2F4F6`) — 칩 테두리가 사라져 −/+ 버튼만
        // 떠 있는 것처럼 보였다. 폼 화면을 흰 바탕으로 두는 것과 같은 사정이다
        // (`PhoneDetailScaffold.background`).
        color: active ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        // 활성 칩은 파란 테두리, 안 한 칩은 옅은 회색 — 흰 면끼리 붙어 있어도
        // 칸이 갈려 보여야 한다
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.gray100,
        ),
      ),
      child: Row(
        children: [
          _AdjustButton(
            // 감소는 빨강, 횟수가 없으면 비활성 회색
            icon: CupertinoIcons.minus,
            color: active ? AppColors.error : AppColors.gray300,
            onTap: () => onAdjust(-1),
          ),
          // 글자 크기는 [_chipFontSize]가 모든 칩에 같은 값을 주므로
          // 여기서 줄어들 일은 없다. 계산이 한 픽셀 모자랄 때를 대비한
          // 안전망으로만 둔다 — 잘라내는(…) 것보다는 줄이는 게 낫다.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTextStyles.body2.copyWith(
                  fontSize: fontSize,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          _AdjustButton(
            icon: CupertinoIcons.plus,
            color: AppColors.primary,
            onTap: () => onAdjust(1),
          ),
        ],
      ),
    );
  }
}

/// 스테퍼 버튼
///
/// **눌림 표시를 안 준다** (2026-08-21). 예전에는 누르는 동안 원이 0.82 로
/// 줄면서 버튼 색으로 물들었다 — [Pressable] 을 걷어낸 것과 같은 이유다.
/// 누른 결과가 **옆 숫자로 바로 보여서** 따로 표시할 것이 없다.
class _AdjustButton extends StatelessWidget {
  _AdjustButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: _CountChip.buttonWidth,
        height: 48,
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}

/// 수행 기록 한 줄 — 시각 · (이름) · 항목 · 완료 체크.
/// 내역 화면과 데스크톱 인라인 내역 카드가 함께 쓴다.
class _LogRow extends StatefulWidget {
  _LogRow({required this.log, required this.showName});

  final EnvTaskLog log;

  /// 전체 내역처럼 누가 했는지 함께 보여줄지
  final bool showName;

  static String formatTime(DateTime time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  /// 이 줄이 그리는 기록 — **가산점을 매기면 여기서 갈린다**
  ///
  /// 부모가 목록을 다시 받아 올 때까지 기다리면, 창을 닫고 나서도 줄에는
  /// 옛 점수가 남는다 (기록 목록이 세 화면에 흩어져 있어서 부모마다 다시
  /// 받게 하면 그중 하나를 반드시 빠뜨린다).
  late EnvTaskLog _log = widget.log;

  @override
  void didUpdateWidget(covariant _LogRow old) {
    super.didUpdateWidget(old);
    // 목록을 다시 받았으면 새 값이 이긴다
    if (!identical(widget.log, old.log)) _log = widget.log;
  }

  /// 남긴 사진이 있는지 — 현수막·족자만 채워진다 ([_photoRequiredItems])
  bool get _hasPhoto => (_log.photoUrl ?? '').isNotEmpty;

  /// 눌러서 볼 것이 있는지 — 블로그는 주소와 가산점이 창에 있다
  bool get _hasBlog => _isAwardable(_log);

  @override
  Widget build(BuildContext context) {
    final row = _row();
    // **줄 모양은 그대로 둔다.** 볼 것이 있는 줄만 눌리게 하고, 없는 줄은
    // 예전처럼 아무 반응이 없다 — 아이콘·썸네일을 붙이면 사진이 있는 줄과
    // 없는 줄이 다르게 생겨서 목록이 들쭉날쭉해진다.
    if (!_hasPhoto && !_hasBlog) return row;
    return Pressable(
      onTap: () => showAppDialog<void>(
        context,
        (_) => _hasBlog
            ? _BlogLogCard(
                log: _log,
                onAwarded: (saved) => setState(() => _log = saved),
              )
            : _PhotoLogCard(log: _log),
      ),
      child: row,
    );
  }

  Widget _row() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _LogRow.formatTime(_log.createdAt),
              style: AppTextStyles.caption,
            ),
          ),
          SizedBox(width: 8),
          if (widget.showName) ...[
            Text(
              _logAuthor(_log),
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _log.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else
            Expanded(
              child: Text(
                _log.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // 그때 받은 점수 — 항목 배점이 나중에 바뀌어도 이 값은 안 바뀐다
          Text(
            '+${_log.totalPoints}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 16,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

/// 받아오는 동안의 뼈대 — 점검 항목 칩이 앉을 자리를 잡아 둔다
///
/// 칩 높이(48)·간격(10)·한 줄 두 칸이 진짜 카드와 같다.
class _ChecklistSkeleton extends StatelessWidget {
  _ChecklistSkeleton();

  @override
  Widget build(BuildContext context) {
    final columns = isDesktop ? 3 : 2;
    return SkeletonGroup(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Skeleton(width: 88, height: 13),
                  Spacer(),
                  Skeleton(width: 56, height: 13),
                ],
              ),
            ),
            SizedBox(height: 14),
            for (var row = 0; row < 5; row++) ...[
              if (row > 0) SizedBox(height: 10),
              Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: 10),
                    Expanded(child: Skeleton(height: 48, radius: 14)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
