part of 'home_screen.dart';

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
  _ProjectsCard({
    this.count = 3,
    this.fill = false,
    this.onOpenAll,
    required this.onChanged,
  });

  /// 표시할 프로젝트 수 (데스크톱은 5개까지)
  final int count;

  /// true면 카드 높이에 맞춰 행 간격을 고르게 벌린다 (데스크톱 나란히 배치용)
  final bool fill;

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
    // 진행 중인 프로젝트를 마감 임박순으로
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
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '진행 중인 프로젝트가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else if (fill)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
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
      scale: 0.98,
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

class _NoticeCard extends StatelessWidget {
  _NoticeCard({this.onOpenAll, required this.onChanged});

  final VoidCallback? onOpenAll;

  /// 본문을 보고 돌아왔을 때 홈을 갱신한다 (읽음 표시)
  final VoidCallback onChanged;

  /// 폰은 본문을 바로 밀어 올리고, 데스크톱은 2단 화면으로 옮겨 선택시킨다
  Future<void> _open(BuildContext context, NoticeBrief brief) async {
    if (isDesktop) {
      requestedNotice.value = brief;
      onOpenAll?.call();
      return;
    }
    await brief.open(context);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 고정 공지가 위, 그다음 최신순으로 5개
    final briefs = noticeBriefs(5);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '공지', count: noticeCount, onOpenAll: onOpenAll),
          SizedBox(height: 4),
          if (briefs.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(0, 18, 0, 26),
              child: Center(
                child: Text(
                  '올라온 공지가 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < briefs.length; i++) ...[
              if (i > 0) Divider(),
              _NoticeRow(
                brief: briefs[i],
                onTap: () => _open(context, briefs[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  _NoticeRow({required this.brief, required this.onTap});

  final NoticeBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = brief.title;
    final pinned = brief.pinned;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PIN',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 아직 안 읽은 공지는 목록과 같은 파란 점으로 표시한다
                if (brief.unread) ...[
                  SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              '${brief.author} · ${brief.time}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
