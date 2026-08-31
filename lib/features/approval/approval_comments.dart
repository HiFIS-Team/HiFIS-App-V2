part of 'approval_screen.dart';

// ── 결재 댓글 ──
//
// 승인·반려하며 남기는 **의견**(`steps[].comment`)과 다르다. 그건 처리하면서
// 한 번 남기고 끝인데, 여기는 처리 전에 **되묻는 자리**다.
// "견적서 첨부해 주세요" 같은 말이 오간다.
//
// ## 공지·회의록·프로젝트와 같은 창을 쓴다 (2026-08-31)
//
// 예전에는 결재만 제 시트와 제 카드를 따로 갖고 있었다. 겉은 비슷했는데
// 셋이 달랐다 — **최신순**(다른 곳은 오래된 것부터) · **수정·삭제 없음** ·
// **키보드가 올라오면 댓글이 통째로 가림**. 대표가 짚어서 [showPostComments]
// 하나로 모았다.
//
// 서버도 같이 옮겼다. 결재 댓글은 `approvals.comments` JSONB 였는데 줄마다
// id 가 없어서 고치고 지울 수가 없었다 (마이그레이션 `apc000000001`).

/// 상세 아래의 댓글 줄 — 누르면 공용 댓글 시트가 올라온다
///
/// **폰·PC 가 같은 줄을 쓴다.** 예전에는 PC 만 입력칸이 붙은 카드였는데,
/// 그러면 같은 댓글이 화면마다 다르게 보인다.
class _ApprovalComments extends StatefulWidget {
  _ApprovalComments({required this.doc});

  final _Doc doc;

  @override
  State<_ApprovalComments> createState() => _ApprovalCommentsState();
}

class _ApprovalCommentsState extends State<_ApprovalComments> {
  List<PostComment> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ApprovalComments old) {
    super.didUpdateWidget(old);
    // PC 는 목록에서 다른 결재를 고르면 이 위젯이 그대로 다시 쓰인다
    if (old.doc.id != widget.doc.id) {
      _rows = const [];
      _load();
    }
  }

  /// 못 받으면 조용히 빈 채로 둔다 — 댓글 때문에 상세가 안 열리면 안 된다
  Future<void> _load() async {
    try {
      final rows = await CommentApi.list(
        target: CommentTarget.approval,
        targetId: widget.doc.id,
      );
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      /* 조용히 */
    }
  }

  Future<void> _open() async {
    await showPostComments(
      context,
      target: CommentTarget.approval,
      targetId: widget.doc.id,
      // 시트가 닫힌 뒤 아래에서 통째로 다시 받는다 — 여기서는 안 쓴다
      onCount: (_) {},
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    // **오래된 것부터** 온다 (다른 댓글 자리와 같다) — 최근 것은 맨 뒤다
    final latest = _rows.isEmpty ? null : _rows.last;

    return Pressable(
      onTap: _open,
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
                    '${_rows.length}',
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
            if (_rows.length > 1) ...[
              SizedBox(height: 10),
              Text(
                '댓글 ${_rows.length}개 모두 보기',
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
