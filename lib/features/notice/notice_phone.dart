part of 'notice_screen.dart';

// ── 폰 화면 ──

/// 폰 목록이 비었을 때 — 알림 화면과 같은 빈 카드를 목록 자리에 올린다
Widget _emptyCard({required IconData icon, required String text}) => Align(
  alignment: Alignment.topCenter,
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: EmptyCard(icon: icon, text: text),
  ),
);

/// 폰: 전체·안읽음 필터 + 공지 카드 목록.
/// 카드를 누르면 읽음 처리되고 본문이 옆에서 밀려 들어온다.
class _NoticePhone extends StatelessWidget {
  _NoticePhone({
    required this.notices,
    required this.unreadOnly,
    required this.unread,
    required this.onFilter,
    required this.onChanged,
  });

  final List<_Notice> notices;
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
    notice.readers.add(me);
    onChanged();
    final result = await Navigator.push<String>(
      context,
      CupertinoPageRoute(
        builder: (_) => _NoticePage(notice: notice, editing: editing),
      ),
    );
    if (!context.mounted) return;
    if (result == 'delete') {
      _notices.remove(notice);
      AppToast.show(context, '공지를 삭제했어요');
    } else if (notice.title.isEmpty && notice.body.trim().isEmpty) {
      // 아무것도 안 적고 나온 새 공지는 목록에 남기지 않는다
      _notices.remove(notice);
    }
    onChanged();
  }

  Future<void> _create(BuildContext context) async {
    final now = DateTime.now();
    final notice = _Notice(
      title: '',
      body: '',
      author: me,
      date: DateTime(now.year, now.month, now.day),
      readers: {me},
    );
    _notices.add(notice);
    onFilter(false);
    await _open(context, notice, editing: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 글래스 헤더 버튼 영역만큼 비워둔다
            SizedBox(height: 64),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Text('공지', style: AppTextStyles.title1),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${notices.length}',
                      style: AppTextStyles.title2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  ActionPill(
                    icon: Icons.add_rounded,
                    label: '공지 작성',
                    onTap: () => _create(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ModeSwitch(
                left: '전체',
                right: unread > 0 ? '안읽음 $unread' : '안읽음',
                value: unreadOnly,
                onChanged: onFilter,
              ),
            ),
            Expanded(
              child: notices.isEmpty
                  ? _emptyCard(
                      icon: Icons.campaign_rounded,
                      text: unreadOnly ? '안 읽은 공지가 없어요' : '올라온 공지가 없어요',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        bottomBarInset(context),
                      ),
                      itemCount: notices.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12),
                      itemBuilder: (context, i) => _NoticeCard(
                        notice: notices[i],
                        onTap: () => _open(context, notices[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
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
    final unread = !notice.readers.contains(me);

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
                  '${notice.readers.length}/${staffList.length} 확인',
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
  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '공지',
      child: _NoticeView(
        notice: widget.notice,
        editing: widget.editing,
        onChanged: () => setState(() {}),
        onDelete: () => Navigator.pop(context, 'delete'),
        phone: true,
      ),
    );
  }
}
