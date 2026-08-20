import 'package:flutter/material.dart';

import '../../api/client/api_exception.dart';
import '../../api/notice/comment_api.dart';
import '../../data/current_user.dart';
import '../../data/staff_directory.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../util/when.dart';
import '../display/avatar.dart';
import '../feedback/app_dialog.dart';
import '../feedback/app_toast.dart';
import '../glass/glass_input_bar.dart';

/// 댓글 시트를 연다
///
/// [onCount] 로 **댓글 수가 바뀔 때마다** 알려준다 — 부르는 쪽이 아이콘 옆
/// 숫자를 갱신한다. 닫을 때 값을 돌려주는 대신 이 길을 쓰는 이유는,
/// 시트를 손으로 쓸어내려 닫으면 돌려줄 자리가 없어서다.
Future<void> showPostComments(
  BuildContext context, {
  required CommentTarget target,
  required String targetId,
  required ValueChanged<int> onCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) =>
        _CommentSheet(target: target, targetId: targetId, onCount: onCount),
  );
}

/// 아래에서 올라오는 댓글 시트 (인스타 결)
///
/// ## 키보드가 올라올 때가 이 화면의 전부다
///
/// 입력칸을 누르면 키보드가 올라오는데, 시트 높이가 그대로면 **댓글이 한 줄도
/// 안 남는다** — 입력칸만 키보드 위에 붙어 있는 꼴이다. 그래서 키보드가
/// 올라오면 시트도 [_tallSize] 로 같이 커진다 (2026-08-19 대표 요청).
///
/// 키보드 높이는 `MediaQuery.viewInsetsOf` 로 읽는다. 시트 안쪽 여백에 그
/// 값을 그대로 더해서 **입력칸이 키보드 바로 위**에 서게 한다.
class _CommentSheet extends StatefulWidget {
  _CommentSheet({
    required this.target,
    required this.targetId,
    required this.onCount,
  });

  final CommentTarget target;
  final String targetId;

  /// 댓글 수가 바뀔 때마다 — 뒤에 있는 아이콘 숫자를 따라 바꾼다
  final ValueChanged<int> onCount;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _controller = DraggableScrollableController();
  final _focus = FocusNode();

  List<PostComment>? _rows;
  bool _failed = false;

  /// 보내는 중 — 두 번 눌리지 않게
  bool _sending = false;

  /// 처음 열릴 때 높이 — 화면 절반쯤 (댓글 두어 개 + 입력칸)
  static const _initialSize = 0.55;

  /// 키보드가 올라왔을 때 — 위로 더 열어서 댓글이 한두 개 남게 한다
  static const _tallSize = 0.92;

  /// 지금 키보드를 따라 올려 둔 상태인가 — 내려갈 때 되돌리려고 기억한다
  bool _raised = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  /// 입력칸을 누르면 시트를 위로 — 키보드가 먹는 만큼 자리를 만든다
  void _onFocus() {
    if (!_controller.isAttached) return;
    if (_focus.hasFocus) {
      if (_raised) return;
      _raised = true;
      _controller.animateTo(
        _tallSize,
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    // 키보드가 내려가면 원래 높이로 — 손으로 끌어 올린 것보다 낮을 때만
    if (!_raised) return;
    _raised = false;
    if (_controller.size <= _tallSize + 0.01) {
      _controller.animateTo(
        _initialSize,
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _load() async {
    try {
      final rows = await CommentApi.list(
        target: widget.target,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
      widget.onCount(rows.length);
    } catch (error) {
      if (!mounted) return;
      setState(() => _failed = true);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final saved = await CommentApi.add(
        target: widget.target,
        targetId: widget.targetId,
        body: body,
      );
      if (!mounted) return;
      setState(() => _rows = [...?_rows, saved]);
      widget.onCount(_rows!.length);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _remove(PostComment comment) async {
    final yes = await showConfirmDialog(
      context,
      title: '댓글을 지울까요?',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await CommentApi.remove(comment.id);
      if (mounted) {
        setState(() => _rows = [...?_rows?.where((r) => r.id != comment.id)]);
        widget.onCount(_rows?.length ?? 0);
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 지울 수 있는 사람 — 본인 (서버는 관리자도 열어 두지만 화면에는 본인만 낸다)
  bool _canRemove(PostComment comment) => comment.authorId == currentUser?.id;

  @override
  Widget build(BuildContext context) {
    // 키보드가 먹는 높이 — 입력칸을 그 위로 올린다
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final rows = _rows;

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: _initialSize,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [_initialSize, _tallSize],
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  '댓글',
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Container(height: 1, color: AppColors.gray100),
                // **댓글이 없어도 스크롤이다.** 여기가 [scroll] 을 안 쓰면
                // 시트의 컨트롤러에 붙는 스크롤이 없어서 `isAttached` 가 false 가
                // 되고, 키보드가 올라올 때 시트를 키우는 [_onFocus] 가 통째로
                // 건너뛴다 — 그러면 0.55 짜리 시트를 키보드가 덮어서 **입력칸이
                // 가린다** (안드로이드에서 실제로 겪었다, 2026-08-20).
                // 손으로 끌어 올리는 것도 같은 이유로 안 먹었다.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // 아래 떠 있는 글래스 입력바에 가리지 않게
                      final under = MediaQuery.paddingOf(context).bottom + 96;
                      // 빈 상태는 **예전처럼 가운데**에 뜬다 — 스크롤 안에
                      // 넣으면서 남는 높이를 그대로 채워 준다
                      final fill = (box.maxHeight - 14 - under).clamp(
                        0.0,
                        double.infinity,
                      );
                      return ListView(
                        controller: scroll,
                        padding: EdgeInsets.fromLTRB(20, 14, 20, under),
                        children: [
                          if (rows == null)
                            // 받아오는 중엔 빈칸 — 실패해야 문구가 뜬다
                            SizedBox(
                              height: fill,
                              child: _failed
                                  ? _Empty(text: '댓글을 불러오지 못했어요')
                                  : null,
                            )
                          else if (rows.isEmpty)
                            SizedBox(
                              height: fill,
                              child: _Empty(text: '첫 댓글을 남겨보세요'),
                            )
                          else
                            for (final row in rows)
                              _CommentRow(
                                comment: row,
                                onRemove: _canRemove(row)
                                    ? () => _remove(row)
                                    : null,
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            // 키보드가 올라오면 입력바도 같이 올라온다 — 아래 안전 영역만큼
            // 더 띄운다 (프로젝트 댓글 시트와 같은 계산이다)
            Positioned(
              left: 16,
              right: 16,
              bottom: keyboard + MediaQuery.paddingOf(context).bottom + 12,
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
}

/// 댓글 한 줄 — 아바타 · 이름 · 시각 · 본문
class _CommentRow extends StatelessWidget {
  _CommentRow({required this.comment, required this.onRemove});

  final PostComment comment;

  /// 본인 댓글일 때만 — 꾹 누르면 지울 수 있다
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name =
        StaffDirectory.instance.byId(comment.authorId)?.name ?? '알 수 없음';

    return GestureDetector(
      onLongPress: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: name, size: 34),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        agoLabel(comment.createdAt),
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      if (comment.edited) ...[
                        SizedBox(width: 4),
                        Text(
                          '수정됨',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(comment.body, style: AppTextStyles.body2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
    ),
  );
}
