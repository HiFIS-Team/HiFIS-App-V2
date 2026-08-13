part of 'approval_screen.dart';

// ── 우측 상세 ──

class _DocDetail extends StatelessWidget {
  _DocDetail({
    super.key,
    required this.doc,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
    required this.onComment,
  });

  final _Doc doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onWithdraw;

  /// 댓글 달기 — 서버에 올리고 오는 동안 기다린다
  final Future<void> Function(String) onComment;

  @override
  Widget build(BuildContext context) {
    final phone = !isDesktop;

    return ListView(
      // 폰은 밀려 들어오는 한 장이라 좌우 20 · 제목 아래에서 시작한다.
      // 하단바가 없는 화면이라 아래는 프로젝트 상세와 같은 여백만 남긴다
      padding: phone
          ? EdgeInsets.fromLTRB(
              20,
              PhoneDetailScaffold.topPadding,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            )
          : EdgeInsets.fromLTRB(32, 64, 32, bottomBarInset(context)),
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                doc.kind.icon,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              doc.kind.label,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 10),
            _StateBadge(state: doc.state),
          ],
        ),
        SizedBox(height: 12),
        // 폰은 제목을 한 단계 줄인다 (프로젝트 폰 머리말과 같은 크기)
        Text(
          doc.title,
          style: phone ? AppTextStyles.title2 : AppTextStyles.title1,
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Avatar(name: doc.writer, size: 22),
            SizedBox(width: 8),
            // 이름·직군·날짜가 이어져서 폰 폭을 넘긴다 — 말줄임으로 자른다
            Expanded(
              child: Text(
                '${doc.writer} ${_rankOf(doc.writerId)} · ${_date(doc.date)} 신청',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        if (doc.state == _State.pending) ...[
          _PendingCard(
            doc: doc,
            onApprove: onApprove,
            onReject: onReject,
            onWithdraw: onWithdraw,
          ),
          SizedBox(height: 16),
        ],
        if (doc.amount > 0) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: AppDecorations.card(),
            child: Row(
              children: [
                Text('금액', style: AppTextStyles.label),
                Spacer(),
                Text(
                  _won(doc.amount),
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        if (doc.startDate case final start?) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('기간', style: AppTextStyles.label),
                    Spacer(),
                    Text(
                      _period(start, doc.endDate),
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if ((doc.place ?? '').isNotEmpty) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text('장소', style: AppTextStyles.label),
                      Spacer(),
                      Text(
                        doc.place!,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내용', style: AppTextStyles.label),
              SizedBox(height: 10),
              Text(
                doc.body.isEmpty ? '적어둔 내용이 없어요' : doc.body,
                style: AppTextStyles.body2.copyWith(
                  height: 1.6,
                  color: doc.body.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (doc.state != _State.pending) ...[
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: doc.state.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (doc.state) {
                    _State.approved => Icons.check_circle_rounded,
                    _State.withdrawn => Icons.undo_rounded,
                    _ => Icons.cancel_rounded,
                  },
                  size: 20,
                  color: doc.state.color,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            switch (doc.state) {
                              _State.approved => '승인됨',
                              _State.withdrawn => '회수됨',
                              _ => '반려됨',
                            },
                            style: AppTextStyles.body2.copyWith(
                              color: doc.state.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          // 처리한 사람은 결재선에서 꺼낸다 — 회수는 올린 사람이다
                          Text(
                            _decidedBy(doc),
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      if (doc.lastActed?.comment case final comment?
                          when comment.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          comment,
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 16),
        // 처리 뒤에도 오간 말은 남는다 — 그래서 결과 카드 아래다.
        // 폰은 프로젝트와 같이 시트로 빼고 여기엔 눌러서 여는 줄만 둔다
        if (phone)
          _CommentTeaser(
            doc: doc,
            onTap: () => _showComments(context, doc, onComment: onComment),
          )
        else
          _CommentCard(doc: doc, onComment: onComment),
      ],
    );
  }
}

/// 결재 대기 카드 — 아이콘 + 옅은 색 바탕 + 처리 버튼
///
/// 프로젝트 기한 연장 카드([_ExtensionCard])와 같은 틀이다.
/// **폰은 버튼을 옆에 두면 안내 글이 눌려서 아래로 내린다.**
/// 버튼은 내 차례일 때만 나온다 (아니면 서버가 403 을 준다).
class _PendingCard extends StatelessWidget {
  _PendingCard({
    required this.doc,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
  });

  final _Doc doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onWithdraw;

  /// 올린 사람은 아직 아무도 처리하지 않은 결재를 물릴 수 있다
  Widget _withdrawButton() => Pressable(
    onTap: onWithdraw,
    scale: 0.96,
    pressedColor: AppColors.gray100,
    borderRadius: BorderRadius.circular(10),
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Text(
      '회수',
      style: AppTextStyles.body2.copyWith(
        fontSize: 14,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '결재 승인 대기',
          style: AppTextStyles.body2.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          // 승인은 어차피 대표만 한다 — 누구 차례인지는 안 적는다
          doc.myTurn ? '의견을 남겨야 처리돼요' : '대표 결재를 기다리고 있어요',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );

    final icon = Icon(
      Icons.hourglass_empty_rounded,
      size: 18,
      color: AppColors.warning,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                SizedBox(width: 10),
                Expanded(child: info),
                if (doc.canWithdraw) ...[
                  SizedBox(width: 12),
                  _withdrawButton(),
                ],
                if (doc.myTurn) ...[
                  SizedBox(width: 12),
                  DecideButtons(onApprove: onApprove, onReject: onReject),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    SizedBox(width: 10),
                    Expanded(child: info),
                  ],
                ),
                if (doc.canWithdraw || doc.myTurn) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      if (doc.canWithdraw) ...[
                        _withdrawButton(),
                        SizedBox(width: 8),
                      ],
                      if (doc.myTurn)
                        Expanded(
                          child: DecideButtons(
                            onApprove: onApprove,
                            onReject: onReject,
                            fill: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// 처리 상태 알약
class _StateBadge extends StatelessWidget {
  _StateBadge({required this.state});

  final _State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: state.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
