part of 'work_screen.dart';

/// 환경정비 점검 카드 — 항목이 2열로 내려가며 배치되고,
/// 각 항목의 좌우 −/+ 버튼으로 오늘 수행 횟수를 조절한다.
class _ChecklistCard extends StatefulWidget {
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
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  final _search = TextEditingController();

  /// 검색어 — 항목이 22개라 눈으로 훑기 어렵다
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final counts = widget.counts;
    final total = counts.values.fold(0, (sum, c) => sum + c);

    // 이름을 맞출 때는 공백·대소문자를 지운다 ('화장실 청소' 로 쳐도 찾히게)
    final key = _WorkScreenState._envKey(_query);
    final shown = key.isEmpty
        ? items
        : [
            for (final item in items)
              if (_WorkScreenState._envKey(item.name).contains(key)) item,
          ];

    return Container(
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
                Expanded(child: Text('오늘 점검 항목', style: AppTextStyles.label)),
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
                  SeeAllButton(onTap: widget.onShowHistory, label: '총 $total회'),
              ],
            ),
          ),
          SizedBox(height: 12),
          _SearchField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
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
              // 글자 크기는 **거른 목록이 아니라 전체**로 잰다 —
              // 검색으로 긴 라벨이 빠질 때마다 남은 칩들이 커졌다 작아진다
              final fontSize = _chipFontSize([
                for (final item in items) item.name,
              ], chipWidth);
              if (shown.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      '찾는 항목이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < shown.length; i += columns) ...[
                    if (i > 0) SizedBox(height: 10),
                    Row(
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) SizedBox(width: 10),
                          Expanded(
                            child: i + col < shown.length
                                ? _CountChip(
                                    label: shown[i + col].name,
                                    count: counts[shown[i + col].id] ?? 0,
                                    fontSize: fontSize,
                                    onAdjust: (delta) =>
                                        widget.onAdjust(shown[i + col], delta),
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
      ),
    );
  }
}

/// 항목을 이름으로 거르는 칸 — **조직도 검색칸과 같은 모양**이다
/// (회색 면 + 돋보기, [staff_filters.dart] 의 `_SearchBar`).
///
/// `GlassSearchBar` 는 화면 아래에 떠 있는 블러 바라 흰 카드 안에는 안 맞는다.
class _SearchField extends StatelessWidget {
  _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      // 흰 카드와 겹쳐 보이지 않게 눕히는 회색 면
      color: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(CupertinoIcons.search, size: 15, color: AppColors.gray500),
        SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            style: AppTextStyles.body2.copyWith(fontSize: 14),
            cursorColor: AppColors.primary,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '항목 찾기',
              hintStyle: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: AppColors.gray400,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
      ],
    ),
  );
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
  static const double buttonWidth = 42;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 48,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        // 활성 칩에만 은은한 파란 테두리
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.transparent,
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

/// 스테퍼 버튼 — 누르는 동안 원이 줄어들며 버튼 색으로 물든다
class _AdjustButton extends StatefulWidget {
  _AdjustButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AdjustButton> createState() => _AdjustButtonState();
}

class _AdjustButtonState extends State<_AdjustButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: _CountChip.buttonWidth,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.82 : 1.0,
            duration: Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 110),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.18)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 13, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 수행 기록 한 줄 — 시각 · (이름) · 항목 · 완료 체크.
/// 내역 화면과 데스크톱 인라인 내역 카드가 함께 쓴다.
class _LogRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              formatTime(log.createdAt),
              style: AppTextStyles.caption,
            ),
          ),
          SizedBox(width: 8),
          if (showName) ...[
            Text(
              _logAuthor(log),
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                log.itemName,
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
                log.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // 그때 받은 점수 — 항목 배점이 나중에 바뀌어도 이 값은 안 바뀐다
          Text(
            '+${log.points}',
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
