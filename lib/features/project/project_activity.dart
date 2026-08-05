part of 'project_screen.dart';

/// 댓글·활동 타임라인
class _ActivityCard extends StatefulWidget {
  _ActivityCard({required this.project, required this.onComment});

  final _Project project;

  /// 서버에 올리고 오는 동안 기다려야 해서 `ValueChanged` 가 아니다
  final Future<void> Function(String) onComment;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 활동은 계속 쌓이므로 처음에는 최근 것만 보여준다
  static const _fold = 5;
  bool _expanded = false;

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
    // 폰은 댓글이 시트로 빠져서 여기엔 시스템 기록만 남는다
    final all = isDesktop
        ? widget.project.events
        : widget.project.events.where((e) => !e.comment).toList();
    final events = _expanded ? all : all.take(_fold).toList();
    final hidden = all.length - events.length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('활동', style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '${all.length}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          // 댓글 입력 — 폰은 시트로 빠져서 데스크톱에서만 둔다
          if (isDesktop) ...[
            SizedBox(height: 12),
            // 댓글 입력
            Row(
              children: [
                Avatar(name: me, size: 34),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
          ],
          SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '아직 활동이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (final event in events)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.comment)
                      Avatar(name: event.author, size: 28)
                    else
                      // 시스템 기록은 아바타 대신 점으로 구분한다
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
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
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _relative(event.time),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1),
                          Text(
                            event.text,
                            style: AppTextStyles.body2.copyWith(
                              color: event.comment
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (hidden > 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Pressable(
                onTap: () => setState(() => _expanded = true),
                scale: 0.99,
                pressedColor: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  '이전 활동 $hidden개 더 보기',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
