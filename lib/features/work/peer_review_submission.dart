part of 'peer_review_section.dart';

/// 제출 현황 전체 — 면담 준비할 때 훑어보는 목록
class _SubmissionScreen extends StatelessWidget {
  _SubmissionScreen({required this.rows, required this.reviews});

  final List<_Submission> rows;

  /// 줄을 누르면 그 사람이 쓴 평가를 여는 데 쓴다
  final List<PeerReview> reviews;

  @override
  Widget build(BuildContext context) {
    final done = rows.where((r) => r.complete).length;

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
                          '${DateTime.now().month}월 동료 평가',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '$done / ${rows.length}명 제출',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) => _SubmissionRow(
                      row: rows[index],
                      onTap: () => showFullPage<void>(
                        context,
                        (_) => _ReviewerScreen(
                          reviewer: rows[index].person,
                          reviews: reviews,
                        ),
                      ),
                    ),
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
                child: Center(
                  child: Text('제출 현황', style: AppTextStyles.title3),
                ),
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
        ],
      ),
    );
  }
}

/// 한 사람이 이번 달에 누구를 어떻게 평가했는지 — 제출 현황에서 눌러 연다
///
/// 면담 자료라 **대표·관리자만** 본다 (서버가 `/peer-reviews` 를 그렇게 막아 뒀다).
/// 요청을 따로 안 보낸다 — 제출 현황이 이미 받아 둔 이번 달 평가에서 골라 쓴다.
class _ReviewerScreen extends StatefulWidget {
  _ReviewerScreen({required this.reviewer, required this.reviews});

  /// 평가를 쓴 사람
  final Employee reviewer;

  /// 이번 달 전체 평가 — 이 안에서 이 사람이 쓴 것만 골라 쓴다
  final List<PeerReview> reviews;

  @override
  State<_ReviewerScreen> createState() => _ReviewerScreenState();
}

class _ReviewerScreenState extends State<_ReviewerScreen> {
  /// 펼쳐 둔 줄 (받는 사람 id)
  final _open = <String>{};

  /// 이 사람이 쓴 평가 — 받는 사람 id 로 찾는다
  Map<String, PeerReview> get _written => {
    for (final review in widget.reviews)
      if (review.reviewerId == widget.reviewer.id) review.revieweeId: review,
  };

  @override
  Widget build(BuildContext context) {
    // 평가 화면과 같은 명단을 쓴다 — 본인이 맨 앞, 그다음 같은 지점 사람들
    final targets = _PeerReviewSectionState._targetsOf(widget.reviewer);
    final written = _written;
    final done = targets.where((t) => written.containsKey(t.id)).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            widget.reviewer.rank.label,
                            StaffDirectory.instance.branchName(
                              widget.reviewer.branchId,
                            ),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '$done / ${targets.length}건 제출',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: targets.isEmpty
                      ? Center(
                          child: Text(
                            '평가할 사람이 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          itemCount: targets.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (_, index) {
                            final person = targets[index];
                            return _GivenReviewRow(
                              person: person,
                              isSelf: person.id == widget.reviewer.id,
                              review: written[person.id],
                              open: _open.contains(person.id),
                              onTap: () => setState(() {
                                if (!_open.remove(person.id)) {
                                  _open.add(person.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    '${widget.reviewer.name}님이 쓴 평가',
                    style: AppTextStyles.title3,
                  ),
                ),
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}

/// 준 평가 한 줄 — 누르면 항목별 별과 사유가 펼쳐진다
class _GivenReviewRow extends StatelessWidget {
  _GivenReviewRow({
    required this.person,
    required this.isSelf,
    required this.review,
    required this.open,
    required this.onTap,
  });

  /// 평가를 받은 사람
  final Employee person;

  /// 자기 자신에게 쓴 평가인가 — 별 하나의 점수가 다르다(1점 vs 4점)
  final bool isSelf;

  /// 아직 안 썼으면 null
  final PeerReview? review;

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final written = review;

    final header = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Avatar(name: person.name, size: 38),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      SizedBox(width: 6),
                      Text('본인', style: AppTextStyles.caption),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  person.rank.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (written == null)
            Text(
              '아직 안 썼어요',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            )
          else ...[
            // 별 다섯 개를 다 그리면 줄이 넘쳐서 평균만 별 하나로 접는다
            Icon(CupertinoIcons.star_fill, size: 13, color: AppColors.warning),
            SizedBox(width: 3),
            Text(
              _average(written).toStringAsFixed(1),
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 10),
            Text(
              '${written.total}점',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              open ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
              size: 12,
              color: AppColors.gray400,
            ),
          ],
        ],
      ),
    );

    if (written == null) return header;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: onTap,
          scale: 1,
          borderRadius: BorderRadius.circular(14),
          child: header,
        ),
        if (open)
          Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in PeerCategory.values) ...[
                  SizedBox(height: 14),
                  // 평가 작성 화면과 같은 별 줄 — 여기서는 못 건드린다
                  _StarRow(
                    label: category.label,
                    stars: written.stars[category] ?? 0,
                    pointsPerStar: peerPointsPerStar(isSelf: isSelf),
                    onChanged: (_) {},
                    readOnly: true,
                  ),
                  if ((written.reasons[category] ?? '').isNotEmpty) ...[
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        written.reasons[category]!,
                        style: AppTextStyles.body2.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 항목 다섯 개의 별 평균 — 줄에 별을 다 그리면 넘쳐서 한 숫자로 접는다
double _average(PeerReview review) {
  final stars = [
    for (final category in PeerCategory.values) review.stars[category] ?? 0,
  ];
  return stars.reduce((a, b) => a + b) / stars.length;
}

/// 제출 현황 한 줄 — 이름·직급과 낸 건수
class _SubmissionRow extends StatelessWidget {
  _SubmissionRow({required this.row, this.onTap});

  final _Submission row;

  /// 누르면 그 사람이 누구를 어떻게 평가했는지 열린다
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final person = row.person;
    final color = person.color ?? avatarColorFor(person.name);
    final complete = row.complete;
    // 한 건도 안 낸 사람이 이 화면의 용건이라 눈에 띄게 둔다
    final untouched = row.done == 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete ? color.withValues(alpha: 0.35) : color,
              shape: BoxShape.circle,
            ),
            child: Text(
              person.name.characters.first,
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
                  person.name,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  person.rank.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${row.done} / ${row.quota}건',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: complete
                  ? AppColors.success
                  : untouched
                  ? AppColors.error
                  : AppColors.primary,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            complete
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            size: 16,
            color: complete ? AppColors.success : AppColors.gray300,
          ),
        ],
      ),
    );
  }
}
