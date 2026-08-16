part of 'notice_screen.dart';

// ── 폰 화면 ──

/// 폰: 전체·안읽음 필터 + 공지 카드 목록.
/// 카드를 누르면 읽음 처리되고 본문이 옆에서 밀려 들어온다.
class _NoticePhone extends StatelessWidget {
  _NoticePhone({
    required this.notices,
    required this.onRetry,
    required this.unreadOnly,
    required this.unread,
    required this.onFilter,
    required this.onChanged,
  });

  final List<_Notice> notices;

  /// 못 받았을 때 다시 받는 길 — null 이면 잘 받아온 것이라 빈 카드를 낸다
  final VoidCallback? onRetry;
  final bool unreadOnly;

  /// 안 읽은 공지 수 (필터 라벨에 쓴다)
  final int unread;
  final ValueChanged<bool> onFilter;

  /// 본문에서 바꾼 내용이 목록에도 반영되도록 알린다
  final VoidCallback onChanged;

  Future<void> _open(
    BuildContext context,
    _Notice notice, {
    bool editing = false,
  }) async {
    // 열어보면 읽은 것으로 표시한다
    _markRead(notice);
    onChanged();
    final result = await Navigator.push<String>(
      context,
      appRoute((_) => _NoticePage(notice: notice, editing: editing)),
    );
    if (!context.mounted) return;
    if (result == 'delete') {
      try {
        await _deleteNotice(notice);
        if (context.mounted) AppToast.show(context, '공지를 삭제했어요');
      } catch (error) {
        if (context.mounted) AppToast.show(context, messageOf(error));
      }
    } else if (notice.id == null) {
      // 아무것도 안 적어서 서버에 못 올라간 새 공지는 목록에 남기지 않는다
      _notices.remove(notice);
    }
    onChanged();
  }

  /// 빈 글로 시작한다 — 서버에는 편집을 마칠 때 올린다
  Future<void> _create(BuildContext context) async {
    final notice = _Notice(
      title: '',
      body: '',
      author: me,
      date: DateTime.now(),
    );
    _notices.add(notice);
    onFilter(false);
    await _open(context, notice, editing: true);
  }

  @override
  Widget build(BuildContext context) {
    return PhoneListScaffold(
      title: '공지',
      count: notices.length,
      filter: ModeSwitch(
        left: '전체',
        right: unread > 0 ? '안읽음 $unread' : '안읽음',
        value: unreadOnly,
        onChanged: onFilter,
      ),
      onCreate: () => _create(context),
      children: [
        if (notices.isEmpty)
          if (onRetry case final retry?)
            FailedCard(onRetry: retry)
          else
            EmptyCard(
              icon: Icons.campaign_rounded,
              text: unreadOnly ? '안 읽은 공지가 없어요' : '올라온 공지가 없어요',
            )
        else
          for (var i = 0; i < notices.length; i++) ...[
            if (i > 0) SizedBox(height: 12),
            _NoticeCard(
              notice: notices[i],
              onTap: () => _open(context, notices[i]),
            ),
          ],
      ],
    );
  }
}

/// 폰 목록 카드 — 고정 핀·제목·안읽음 점·미리보기·작성자·확인 수
class _NoticeCard extends StatelessWidget {
  _NoticeCard({required this.notice, required this.onTap});

  final _Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notice.read;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    notice.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (unread) ...[
                  SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 5),
            Text(
              notice.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Avatar(name: notice.author, size: 20),
                SizedBox(width: 6),
                Text(
                  '${notice.author} · ${_date(notice.date)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                Spacer(),
                Text(
                  '${notice.readCount}명 확인',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 폰 본문 화면 — 삭제를 누르면 'delete'를 돌려주고 목록이 지운다
class _NoticePage extends StatefulWidget {
  _NoticePage({required this.notice, required this.editing});

  final _Notice notice;
  final bool editing;

  @override
  State<_NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<_NoticePage> {
  late bool _editing = widget.editing;

  /// 편집을 마치면 서버에 올린다 — 실패하면 적던 내용을 지키려고 편집으로 되돌린다
  Future<void> _toggleEdit() async {
    if (!_editing) return setState(() => _editing = true);

    final isNew = widget.notice.id == null;
    setState(() => _editing = false);
    try {
      await _saveNotice(widget.notice);
      if (!mounted) return;
      setState(() {});
      if (widget.notice.id != null) {
        AppToast.show(context, isNew ? '공지를 올렸어요' : '공지를 수정했어요');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _editing = true);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit(widget.notice);

    return PhoneDetailScaffold(
      title: '공지',
      // 편집·삭제는 헤더 글래스 버튼으로 올린다
      actions: [
        if (_editing)
          GlassIconButton(
            symbol: 'trash',
            symbolColor: AppColors.error,
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
        if (canEdit)
          GlassIconButton(
            // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
            stableId: 'edit',
            symbol: _editing ? 'checkmark' : 'square.and.pencil',
            symbolColor: _editing ? AppColors.primary : null,
            onPressed: _toggleEdit,
          ),
      ],
      child: _NoticeView(
        notice: widget.notice,
        editing: _editing,
        onChanged: () => setState(() {}),
        onDelete: () => Navigator.pop(context, 'delete'),
        onToggleEdit: _toggleEdit,
        phone: true,
      ),
    );
  }
}

/// 받아오는 동안의 뼈대 — 목록 카드 자리를 미리 잡아 둔다
///
/// 카드 안 구성이 진짜 카드와 같다 (제목 · 미리보기 두 줄 · 작성자 줄).
/// 개수와 안읽음 전환은 값을 알아야 그릴 수 있어서 **필터 자리만** 비워 둔다.
class _NoticeSkeleton extends StatelessWidget {
  _NoticeSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: PhoneListScaffold(
      title: '공지',
      // ModeSwitch 와 같은 높이(48) — 다 받아왔을 때 목록이 안 밀린다
      filter: Skeleton(height: 48, radius: 14),
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) SizedBox(height: 12),
          SkeletonCard(
            children: [
              Skeleton(width: 180, height: 15),
              SizedBox(height: 12),
              Skeleton(height: 11),
              SizedBox(height: 7),
              Skeleton(width: 220, height: 11),
              SizedBox(height: 16),
              Row(
                children: [
                  SkeletonCircle(size: 20),
                  SizedBox(width: 6),
                  Skeleton(width: 110, height: 11),
                  Spacer(),
                  Skeleton(width: 52, height: 11),
                ],
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
