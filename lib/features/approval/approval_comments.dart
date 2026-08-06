part of 'approval_screen.dart';

// ── 결재 댓글 ──
//
// 승인·반려하며 남기는 **의견**(`steps[].comment`)과 다르다. 그건 처리하면서
// 한 번 남기고 끝인데, 여기는 처리 전에 **되묻는 자리**다.
// "견적서 첨부해 주세요" 같은 말이 오간다.
//
// 프로젝트 활동 카드(`project_activity.dart`)와 같은 모양이다 — 아바타 32,
// 회색 입력칸, 오른쪽 파란 보내기 버튼. 두 화면에서 댓글 모양이 갈리면 안 된다.

// ── 폰 댓글 시트 ──
//
// 프로젝트 상세와 같다 (`project_comments.dart`) — 상세 안에 입력칸을 두면
// 댓글을 쓰려고 한참 스크롤해 내려가야 하고, 쓰는 동안 위 내용이 안 보인다.
// **댓글 줄 하나**만 두고 누르면 화면 절반이 올라오는 시트에서 읽고 쓴다.

/// 댓글 시트 열기 — 화면 절반에서 시작해 위로 끌어올릴 수 있다
void _showComments(
  BuildContext context,
  _Doc doc, {
  required Future<void> Function(String) onComment,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _CommentSheet(doc: doc, onComment: onComment),
  );
}

class _CommentSheet extends StatefulWidget {
  _CommentSheet({required this.doc, required this.onComment});

  final _Doc doc;

  /// 서버에 올리고 오는 동안 기다려야 해서 `ValueChanged` 가 아니다
  final Future<void> Function(String) onComment;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _focus = FocusNode();

  /// 시트가 연 뒤에 붙은 댓글 — 서버가 문서를 통째로 갈아끼워서
  /// (`_replace`) 열 때 받은 [widget.doc] 에는 안 붙는다
  _Doc get _doc {
    for (final doc in _docs) {
      if (doc.id == widget.doc.id) return doc;
    }
    return widget.doc;
  }

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
    // 최근 것이 위로 오게 뒤집는다 (서버는 뒤에 붙인다) — 카드와 같은 차례다
    final comments = _doc.comments.reversed.toList();

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
                              _CommentRow(comment: comments[i]),
                        ),
                ),
              ],
            ),
            // 키보드가 올라오면 입력바도 같이 올라온다
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
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
  _CommentRow({required this.comment});

  final ApprovalComment comment;

  @override
  Widget build(BuildContext context) {
    final name = _nameOf(comment.authorId);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: name, size: 32),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      agoLabel(comment.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  comment.body,
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
  _CommentTeaser({required this.doc, required this.onTap});

  final _Doc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final comments = doc.comments;
    final latest = comments.isEmpty ? null : comments.last;

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
                  Avatar(name: _nameOf(latest.authorId), size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameOf(latest.authorId),
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          latest.body,
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

/// 결재 문서에 달린 댓글 카드 (PC)
class _CommentCard extends StatefulWidget {
  _CommentCard({required this.doc, required this.onComment});

  final _Doc doc;

  /// 서버에 올리고 오는 동안 기다려야 해서 `ValueChanged` 가 아니다
  final Future<void> Function(String) onComment;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // 입력칸은 먼저 비운다 — 서버를 기다리는 동안 두 번 눌리지 않게
    _controller.clear();
    // 보낸 뒤에도 계속 쓸 수 있게 포커스를 되돌린다
    _focus.requestFocus();
    await widget.onComment(text);
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.doc.comments;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('댓글', style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '${comments.length}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Avatar(name: me, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: AppDecorations.field(),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '댓글을 남겨보세요',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Pressable(
                onTap: _send,
                scale: 0.94,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          if (comments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '아직 댓글이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            // 최근 것이 위로 오게 뒤집는다 (서버는 뒤에 붙인다)
            for (final comment in comments.reversed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(name: _nameOf(comment.authorId), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _nameOf(comment.authorId),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                agoLabel(comment.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1),
                          Text(comment.body, style: AppTextStyles.body2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
