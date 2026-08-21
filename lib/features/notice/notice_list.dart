part of 'notice_screen.dart';

// ── 좌측 목록 ──

class _NoticeList extends StatelessWidget {
  _NoticeList({
    required this.notices,
    required this.onRetry,
    required this.selected,
    required this.unreadOnly,
    required this.unread,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Notice> notices;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;
  final _Notice? selected;
  final bool unreadOnly;

  /// 안 읽은 공지 수 (필터 라벨에 쓴다)
  final int unread;
  final ValueChanged<bool> onFilter;
  final ValueChanged<_Notice> onSelect;
  final VoidCallback onCreate;

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
              Text('공지', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notices.length}',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Pressable(
                onTap: onCreate,
                padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text(
                      '공지 작성',
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
          child: ModeSwitch(
            left: '전체',
            right: unread > 0 ? '안읽음 $unread' : '안읽음',
            value: unreadOnly,
            onChanged: onFilter,
          ),
        ),
        Expanded(
          child: notices.isEmpty
              // Expanded 안에서 카드가 세로로 늘어나지 않게 위에 붙인다
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: onRetry != null
                        ? FailedCard(onRetry: onRetry!)
                        : EmptyCard(
                            icon: Icons.campaign_rounded,
                            text: unreadOnly ? '안 읽은 공지가 없어요' : '올라온 공지가 없어요',
                          ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _NoticeTile(
                    notice: notices[i],
                    selected: notices[i] == selected,
                    onTap: () => onSelect(notices[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoticeTile extends StatefulWidget {
  _NoticeTile({
    required this.notice,
    required this.selected,
    required this.onTap,
  });

  final _Notice notice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final unread = !notice.read;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notice.pinned) ...[
                    Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      notice.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (unread) ...[
                    SizedBox(width: 6),
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
              SizedBox(height: 3),
              Text(
                notice.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Avatar(name: notice.author, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '${notice.author} · ${_date(notice.date)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  Text(
                    '${notice.readCount}명 확인',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  _EmptyNotice({required this.unreadOnly, required this.onCreate});

  final bool unreadOnly;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.campaign_rounded,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('공지', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            unreadOnly ? '안 읽은 공지가 없어요' : '지점에 알릴 내용을 적어보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: 24),
          Pressable(
            onTap: onCreate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '공지 작성',
                style: AppTextStyles.body2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
