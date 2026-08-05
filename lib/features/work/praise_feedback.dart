part of 'praise_section.dart';

/// 피드백 크게 보기 카드 — 컴플레인은 처리 단계를 여기서 바꾼다
class _FeedbackDetailCard extends StatefulWidget {
  _FeedbackDetailCard({required this.feedback, this.onChanged});

  final _Feedback feedback;
  final VoidCallback? onChanged;

  @override
  State<_FeedbackDetailCard> createState() => _FeedbackDetailCardState();
}

class _FeedbackDetailCardState extends State<_FeedbackDetailCard> {
  /// 처리 단계를 바꾸고 창을 닫는다
  ///
  /// 해결중은 같은 버튼을 다시 누르면 미처리로 되돌린다 (잘못 누른 걸 취소할 방법).
  /// **해결 완료는 못 되돌린다** — 찍는 순간 환경정비 '클레임해결' 점수가 붙어서
  /// 되돌렸다 다시 찍으면 점수가 두 번 쌓인다. 서버도 400 으로 막는다.
  ///
  /// **고르면 바로 닫고 토스트로 알린다.** 창을 열어둔 채 색만 바꾸면
  /// 처리가 됐는지 안 됐는지 알 수가 없다.
  void _pick(_Status status) {
    final feedback = widget.feedback;
    // 완료는 되돌리는 길이 없으므로 같은 버튼을 다시 눌러도 완료다
    final next = status != _Status.done && feedback.status == status
        ? _Status.pending
        : status;
    final before = feedback.status;

    // 누르는 순간 바꾸고 서버에 올린다. 실패하면 되돌린다 —
    // 창을 닫고 나서 결과를 기다리면 목록이 잠깐 거짓말을 한다.
    feedback.status = next;
    widget.onChanged?.call();

    final id = feedback.surveyId;
    if (id != null) _push(id, feedback, next, before, widget.onChanged);

    AppToast.show(
      context,
      next == _Status.pending
          ? '미처리로 되돌렸어요'
          : '${next.label}${_particleRo(next.label)} 바꿨어요',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final withStatus = feedback.complaint && _showStatus;

    return Container(
      width: 300,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: feedback.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              feedback.name.characters.first,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            feedback.name,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
          ),
          if (withStatus) ...[
            SizedBox(height: 8),
            _StatusChip(status: feedback.status),
          ],
          SizedBox(height: 12),
          Text(
            feedback.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(_formatStamp(feedback.time), style: AppTextStyles.caption),
          if (withStatus) ...[
            SizedBox(height: 18),
            if (feedback.status == _Status.done)
              // 이미 끝난 건은 손댈 수 없다 — 버튼 대신 안내만 둔다
              Text(
                '해결 완료된 컴플레인은 되돌릴 수 없어요',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _StatusButton(
                      status: _Status.working,
                      selected: feedback.status == _Status.working,
                      onTap: () => _pick(_Status.working),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StatusButton(
                      status: _Status.done,
                      selected: false,
                      onTap: () => _pick(_Status.done),
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

/// 앞말 받침에 맞는 조사 — `해결중으로` / `해결 완료로`
///
/// 상태 이름이 늘어나도 문장이 어색해지지 않게 계산해서 붙인다.
String _particleRo(String word) {
  final code = word.runes.last;
  // 한글 음절이 아니면(영문·숫자) 그냥 '로'
  if (code < 0xAC00 || code > 0xD7A3) return '로';
  final jongseong = (code - 0xAC00) % 28;
  // 받침이 없거나 ㄹ 받침이면 '로', 그 외에는 '으로'
  return jongseong == 0 || jongseong == 8 ? '로' : '으로';
}

/// 처리 단계 알약 — 목록·상세에 같이 쓴다
class _StatusChip extends StatelessWidget {
  _StatusChip({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: status.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 처리 단계 버튼 — 고르면 그 단계 색으로 꽉 찬다
class _StatusButton extends StatelessWidget {
  _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final _Status status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      pressedColor: selected ? null : AppColors.gray100,
      borderRadius: BorderRadius.circular(14),
      // 애니메이션 없이 즉시 바꾼다 (색이 서서히 빠지면 둘 다 눌린 듯 보인다)
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? status.color : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: Colors.white),
              SizedBox(width: 4),
            ],
            Text(
              status.label,
              style: AppTextStyles.body2.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 피드백 한 줄 — 아바타, 이름, 내용, 시각과 끝의 화살표
/// 폰 목록 카드 — 프로젝트·동료 평가 목록과 같은 결로 피드백 하나에 카드 하나
///
/// 데스크톱은 아직 [_FeedbackRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _FeedbackCard extends StatelessWidget {
  _FeedbackCard({required this.feedback, required this.onTap});

  final _Feedback feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showStatus = feedback.complaint && _showStatus;

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
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: feedback.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    feedback.name.characters.first,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        // 전사로 볼 때는 누구에게 온 것인지가 먼저다
                        feedback.about == null
                            ? _formatStamp(feedback.time)
                            : '${feedback.about} · '
                                  '${_formatStamp(feedback.time)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // 컴플레인만 처리 단계가 있다 — 칭찬은 배지 자리가 빈다
                if (showStatus) ...[
                  SizedBox(width: 8),
                  _StatusChip(status: feedback.status),
                ],
              ],
            ),
            SizedBox(height: 14),
            Text(
              feedback.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  _FeedbackRow({required this.feedback, required this.onTap});

  final _Feedback feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: feedback.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              feedback.name.characters.first,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      feedback.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (feedback.complaint && _showStatus) ...[
                      SizedBox(width: 6),
                      _StatusChip(status: feedback.status),
                    ],
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  feedback.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  feedback.about == null
                      ? _formatStamp(feedback.time)
                      : '${feedback.about} · ${_formatStamp(feedback.time)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 피드백 전체 화면 — 옆에서 슬라이드되어 열리고 날짜별로 묶어 보여준다
class _FeedbackHistoryScreen extends StatefulWidget {
  _FeedbackHistoryScreen({required this.complaint});

  /// true면 컴플레인 기록
  final bool complaint;

  @override
  State<_FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<_FeedbackHistoryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${time.month}.${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final base = _feedbacks.where((f) => f.complaint == widget.complaint);
    final sorted =
        base
            .where(
              (f) =>
                  query.isEmpty ||
                  f.name.contains(query) ||
                  f.text.contains(query),
            )
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    final title = widget.complaint ? '컴플레인' : '내게 온 칭찬';
    final unresolved = widget.complaint && _showStatus
        ? sorted.where((f) => f.status == _Status.pending).length
        : 0;

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final feedback in sorted) {
      final dayLabel = _dayLabel(feedback.time);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _FeedbackRow(
          feedback: feedback,
          onTap: () => _showFeedbackDetail(
            context,
            feedback,
            onChanged: () => setState(() {}),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.complaint
                              ? (unresolved > 0
                                    ? '받은 컴플레인 기록 · 미처리 $unresolved건'
                                    : '받은 컴플레인 기록')
                              : '받은 칭찬 기록',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 ${sorted.length}건',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      query.isEmpty
                          ? (widget.complaint
                                ? '아직 컴플레인이 없어요'
                                : '아직 받은 칭찬이 없어요')
                          : '검색 결과가 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        // 하단 글래스 검색 바에 가리지 않도록 여유를 둔다
                        MediaQuery.paddingOf(context).bottom + 96,
                      ),
                      children: children,
                    ),
                  ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: Text(title, style: AppTextStyles.title3)),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '이름·내용 검색'),
        ],
      ),
    );
  }
}
