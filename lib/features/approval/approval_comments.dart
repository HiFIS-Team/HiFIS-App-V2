part of 'approval_screen.dart';

// ── 결재 댓글 ──
//
// 승인·반려하며 남기는 **의견**(`steps[].comment`)과 다르다. 그건 처리하면서
// 한 번 남기고 끝인데, 여기는 처리 전에 **되묻는 자리**다.
// "견적서 첨부해 주세요" 같은 말이 오간다.
//
// 프로젝트 활동 카드(`project_activity.dart`)와 같은 모양이다 — 아바타 32,
// 회색 입력칸, 오른쪽 파란 보내기 버튼. 두 화면에서 댓글 모양이 갈리면 안 된다.

/// 결재 문서에 달린 댓글 카드
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
