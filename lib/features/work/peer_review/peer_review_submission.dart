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
                        (_) => _ReceivedScreen(
                          person: rows[index].person,
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

/// 한 사람이 이번 달에 **받은** 평가 — 제출 현황에서 눌러 연다
///
/// 면담 자료라 **대표·관리자만** 본다 (서버가 `/peer-reviews` 를 그렇게 막아 뒀다).
/// 요청을 따로 안 보낸다 — 제출 현황이 이미 받아 둔 이번 달 평가에서 골라 쓴다.
///
/// 카드 한 장이 **그 사람을 평가한 사람** 하나다. 본인이 쓴 자기 평가도 같이 선다.
/// 누르면 그 사람이 어떻게 매겼는지가 읽기 전용으로 열린다.
class _ReceivedScreen extends StatelessWidget {
  _ReceivedScreen({required this.person, required this.reviews});

  /// 평가를 받은 사람 — 이 화면의 주인
  final Employee person;

  /// 이번 달 전체 평가 — 이 안에서 이 사람이 받은 것만 골라 쓴다
  final List<PeerReview> reviews;

  /// 이 사람이 받은 평가 — 쓴 사람 id 로 찾는다
  Map<String, PeerReview> get _received => {
    for (final review in reviews)
      if (review.revieweeId == person.id) review.reviewerId: review,
  };

  /// 평가를 쓴 사람을 낼 수 있는 차례대로 — 본인이 맨 앞, 그다음 같은 지점 사람들
  ///
  /// 서로 평가하는 사이라 `_targetsOf(person)` 이 곧 이 사람을 평가할 수 있는
  /// 사람들이다. **안 쓴 사람은 빠진다** — 이 화면은 받은 것만 모은다.
  List<Employee> _writers(Map<String, PeerReview> received) => [
    for (final employee in _PeerReviewSectionState._targetsOf(person))
      if (received.containsKey(employee.id)) employee,
  ];

  /// 그 사람이 어떻게 매겼는지 — 평가 작성 화면을 읽기 전용으로 연다
  void _open(BuildContext context, PeerReview review) => showFullPage<void>(
    context,
    (_) => _PeerReviewFormScreen(
      // 화면의 대상은 '평가받은 사람'이다 — 쓴 사람이 아니다
      person: person,
      isSelf: review.isSelf,
      submitted: review,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final received = _received;
    final writers = _writers(received);

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
                            person.rank.label,
                            StaffDirectory.instance.branchName(person.branchId),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '${writers.length}건 받음',
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
                  child: writers.isEmpty
                      ? Center(
                          child: Text(
                            '아직 받은 평가가 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            16,
                            20,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          itemCount: writers.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final writer = writers[index];
                            final review = received[writer.id]!;
                            // 평가 작성 목록과 같은 카드 — 이름은 **쓴 사람**이다
                            return _PersonCard(
                              person: writer,
                              isSelf: review.isSelf,
                              review: review,
                              onTap: () => _open(context, review),
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
                    '${person.name}님이 받은 평가',
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

/// 제출 현황 한 줄 — 이름·직급과 낸 건수
class _SubmissionRow extends StatelessWidget {
  _SubmissionRow({required this.row, this.onTap});

  final _Submission row;

  /// 누르면 그 사람이 누구를 어떻게 평가했는지 열린다
  ///
  /// **null 이면 안 눌린다** — 폰은 줄이 카드 한 장이라 카드 쪽이 누름을 받는다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final person = row.person;
    final color = person.color ?? avatarColorFor(person.name);
    final complete = row.complete;
    // 한 건도 안 낸 사람이 이 화면의 용건이라 눈에 띄게 둔다
    final untouched = row.done == 0;

    final content = Padding(
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

    final tap = onTap;
    if (tap == null) return content;
    return Pressable(
      onTap: tap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}
