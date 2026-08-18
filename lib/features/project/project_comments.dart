part of 'project_screen.dart';

// ── 폰 댓글 시트 ──
//
// 상세 화면 안에 입력칸을 두면 댓글을 쓰려고 한참 스크롤해 내려가야 하고,
// 쓰는 동안 위 내용이 안 보인다. 인스타처럼 **댓글 줄 하나**만 두고
// 누르면 화면 절반이 올라오는 시트에서 읽고 쓰게 한다.

/// 댓글 시트 열기 — 화면 절반에서 시작해 위로 끌어올릴 수 있다
void _showComments(
  BuildContext context,
  _Project project, {
  required Future<void> Function(String) onComment,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _CommentSheet(project: project, onComment: onComment),
  );
}

class _CommentSheet extends StatefulWidget {
  _CommentSheet({required this.project, required this.onComment});

  final _Project project;

  /// 서버에 올리고 오는 동안 기다려야 해서 `ValueChanged` 가 아니다
  final Future<void> Function(String) onComment;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    await widget.onComment(text);
    // 시트 안 목록도 바로 갱신한다 (올라간 뒤라야 새 줄이 보인다)
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.project.events.where((e) => e.comment).toList();

    return DraggableScrollableSheet(
      // 절반에서 시작해 끌어올리면 거의 전체까지 커진다
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _Grabber(count: comments.length),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: comments.isEmpty
                      ? _empty()
                      : ListView.builder(
                          controller: controller,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            // 아래 떠 있는 글래스 입력바에 가리지 않게
                            MediaQuery.paddingOf(context).bottom + 96,
                          ),
                          itemCount: comments.length,
                          itemBuilder: (_, i) =>
                              _CommentRow(event: comments[i]),
                        ),
                ),
              ],
            ),
            // 키보드가 올라오면 입력바도 같이 올라온다.
            //
            // **안드로이드는 시스템 하단바만큼 더 띄운다.** 화면 맨 아래를
            // 제스처 바(24)나 3버튼 바(48)가 차지해서, 12만 띄우면 입력바가
            // 그 밑으로 들어가 가린다 (3버튼이면 거의 다 덮인다).
            // 바로 위 목록은 이미 `paddingOf(context).bottom` 을 빼고 있었다 —
            // 입력바만 빠뜨린 자리다.
            //
            // 키보드가 올라오면 `paddingOf` 가 0이 되고 `viewInsetsOf` 에
            // 하단바가 포함되므로 두 값을 더해도 겹치지 않는다.
            Positioned(
              left: 16,
              right: 16,
              bottom:
                  MediaQuery.viewInsetsOf(context).bottom +
                  (isApple ? 0 : MediaQuery.paddingOf(context).bottom) +
                  12,
              child: GlassInputBar(
                onSend: _send,
                focusNode: _focus,
                hint: '댓글 남기기',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: EdgeInsets.only(bottom: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.chat_bubble, size: 30, color: AppColors.gray300),
          SizedBox(height: 10),
          Text(
            '첫 댓글을 남겨보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    ),
  );
}

/// 시트 손잡이 + 제목
class _Grabber extends StatelessWidget {
  _Grabber({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('댓글', style: AppTextStyles.title3),
              if (count > 0) ...[
                SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 시트 안 댓글 한 줄
class _CommentRow extends StatelessWidget {
  _CommentRow({required this.event});

  final _Event event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: event.author, size: 32),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.author,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      _relative(event.time),
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  event.text,
                  style: AppTextStyles.body2.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 상세 화면에 놓이는 댓글 줄 — 최근 한 건만 보여주고 누르면 시트가 올라온다
class _CommentTeaser extends StatelessWidget {
  _CommentTeaser({required this.project, required this.onTap});

  final _Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final comments = project.events.where((e) => e.comment).toList();
    final latest = comments.isEmpty ? null : comments.first;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('댓글', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${comments.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_up,
                  size: 13,
                  color: AppColors.gray400,
                ),
              ],
            ),
            SizedBox(height: 12),
            if (latest == null)
              Row(
                children: [
                  Avatar(name: me, size: 32),
                  SizedBox(width: 10),
                  Text(
                    '첫 댓글을 남겨보세요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Avatar(name: latest.author, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest.author,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          latest.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (comments.length > 1) ...[
              SizedBox(height: 10),
              Text(
                '댓글 ${comments.length}개 모두 보기',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
