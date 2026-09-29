part of 'home_screen.dart';

/// 카드 안의 줄들 — **위에서부터 간격 14로 쌓는다**
///
/// 남는 높이를 나눠 갖지 않는다(`spaceBetween`). 그러면 줄이 모자랄 때
/// **가운데가 비고** 줄이 카드 위아래로 갈라진다. 결재 대기는 승인·반려로
/// 줄이 계속 사라지는 자리라 그때마다 남은 줄이 움직이면 다음 버튼을 조준하기
/// 어렵다. 네 장(결재 대기·오늘 출근·프로젝트·공지)이 다 이 방식이다.
class _StackedRows extends StatelessWidget {
  _StackedRows({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) SizedBox(height: 14),
        rows[i],
      ],
    ],
  );
}

/// 폰에서 카드 본문이 줄어들지 않게 세 줄 높이를 잡아 주는 껍데기
///
/// 데스크톱은 두 장을 나란히 놓고 `IntrinsicHeight` 로 맞추므로 그냥 통과시킨다.
class _CardBody extends StatelessWidget {
  _CardBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => isDesktop
      ? child
      : ConstrainedBox(
          constraints: BoxConstraints(minHeight: phoneCardBody),
          child: child,
        );
}

class _CardHeader extends StatelessWidget {
  _CardHeader({
    required this.title,
    required this.count,
    this.total,
    this.onOpenAll,
  });

  final String title;
  final int count;

  /// 있으면 `12/23` 으로 — 출근 카드처럼 분모가 있어야 뜻이 생기는 자리
  final int? total;

  /// 눌리면 해당 탭으로 이동한다
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.title3),
        SizedBox(width: 6),
        Text(
          '$count',
          style: AppTextStyles.title3.copyWith(color: AppColors.gray400),
        ),
        Spacer(),
        if (onOpenAll != null) SeeAllButton(onTap: onOpenAll!),
      ],
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  _ProjectsCard({this.count = 3, this.onOpenAll, required this.onChanged});

  /// 표시할 프로젝트 수 (데스크톱은 5개까지)
  final int count;

  /// true면 카드 높이에 맞춰 행 간격을 고르게 벌린다 (데스크톱 나란히 배치용)

  final VoidCallback? onOpenAll;

  /// 상세를 보고 돌아왔을 때 홈을 갱신한다
  final VoidCallback onChanged;

  /// 폰은 상세를 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, ProjectBrief brief) async {
    if (isDesktop) {
      requestedProject.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 관련 알림 최신순, 알림이 없으면 프로젝트 생성순
    final briefs = projectBriefs(count);

    final rows = [
      for (final brief in briefs)
        _ProjectRow(brief: brief, onTap: () => _open(context, brief)),
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '프로젝트', count: rows.length, onOpenAll: onOpenAll),
          SizedBox(height: 14),
          if (rows.isEmpty && isDesktop)
            // 옆 카드에 높이를 맞추느라 늘어난 자리 — 안내를 가운데에 놓는다.
            // `Expanded` 는 Column 의 직계 자식이어야 해서 여기서 바로 감싼다.
            Expanded(
              child: Center(
                child: EmptyCard(
                  icon: Icons.folder_rounded,
                  text: '진행 중인 프로젝트가 없어요',
                  framed: false,
                ),
              ),
            )
          else if (rows.isEmpty)
            // 프로젝트 탭의 빈 상태와 같은 아이콘
            _CardBody(
              child: Center(
                child: EmptyCard(
                  icon: Icons.folder_rounded,
                  text: '진행 중인 프로젝트가 없어요',
                  framed: false,
                ),
              ),
            )
          else
            _CardBody(child: _StackedRows(rows: rows)),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  _ProjectRow({required this.brief, required this.onTap});

  final ProjectBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Row(
        children: [
          // 일정 카드 스타일의 세로 색 막대
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: brief.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(brief.members, style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brief.ddayColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              brief.dday,
              style: AppTextStyles.caption.copyWith(
                color: brief.ddayColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
