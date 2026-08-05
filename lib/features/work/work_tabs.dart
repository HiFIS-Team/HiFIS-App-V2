part of 'work_screen.dart';

/// 업무 탭의 항목 하나 — 내용은 항목마다 전용 섹션 위젯이 그린다
class _WorkItem {
  const _WorkItem({required this.label, this.checklist = false});

  final String label;

  /// 2열 점검 체크리스트를 쓰는 항목인지 (환경정비만)
  final bool checklist;
}

/// 데스크톱 업무 항목 탭 — 회색 트랙 위에 흰 알약이 움직이는 분절 토글.
/// 커서를 올리면 선택되지 않은 칸도 옅게 반응한다.
class _WorkSegmentedTabs extends StatefulWidget {
  _WorkSegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_WorkSegmentedTabs> createState() => _WorkSegmentedTabsState();
}

class _WorkSegmentedTabsState extends State<_WorkSegmentedTabs> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < widget.labels.length; i++) _segment(i)],
      ),
    );
  }

  Widget _segment(int index) {
    final selected = index == widget.selected;
    final hovered = index == _hover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = index),
      onExit: (_) => setState(() {
        if (_hover == index) _hover = null;
      }),
      child: Pressable(
        scale: 0.97,
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onSelect(index),
        // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 선택돼 있던
        // 칸의 알약이 서서히 사라지며 둘 다 눌린 것처럼 보인다
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: segmentFill(selected: selected, hovered: hovered),
          child: Text(
            widget.labels[index],
            maxLines: 1,
            style: AppTextStyles.body2.copyWith(
              fontSize: 14,
              color: selected ? AppColors.primary : AppColors.gray600,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkTab extends StatelessWidget {
  _WorkTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// true면 주어진 칸을 채우고 가운데 정렬 (내역 화면처럼 Expanded로 쓸 때)
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      style: AppTextStyles.body2.copyWith(
        fontSize: 14,
        color: selected ? AppColors.textPrimary : AppColors.gray500,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    // 칸이 좁으면 글자를 줄여서 맞춘다 (옆으로 밀리거나 잘리지 않게)
    final fitted = FittedBox(fit: BoxFit.scaleDown, child: text);

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        // 밑줄이 글자보다 살짝 넓게 깔리도록 좌우 여유를 준다
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: expand ? Center(child: fitted) : fitted,
      ),
    );
  }
}
