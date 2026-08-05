part of 'work_screen.dart';

/// 업무 탭의 항목 하나 — 내용은 항목마다 전용 섹션 위젯이 그린다
class _WorkItem {
  const _WorkItem({required this.label, this.checklist = false});

  final String label;

  /// 2열 점검 체크리스트를 쓰는 항목인지 (환경정비만)
  final bool checklist;
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
