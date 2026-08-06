part of 'peer_review_section.dart';

// ---------------------------------------------------------------------------
// 제출 현황 (대표·관리자)
// ---------------------------------------------------------------------------

/// 평가를 내야 하는 사람 전원 (직원·점장)
///
/// 대표·관리자는 평가를 쓰지 않으므로 분모에서 빠진다.
List<Employee> _reviewers() => [
  for (final employee in StaffDirectory.instance.employees)
    if (employee.role.doesFieldWork) employee,
];

/// 한 사람의 이번 달 제출 현황
class _Submission {
  _Submission({
    required this.person,
    required this.done,
    required this.quota,
    this.rating,
  });

  final Employee person;

  /// 이번 달에 낸 평가 수
  final int done;

  /// 내야 하는 수 — 본인 지점에서 평가할 사람 수 (자기 자신 포함)
  final int quota;

  /// **받은** 평가의 별 평균 — 아직 못 받았으면 null
  ///
  /// 낸 건수(`done`)와 다른 축이다. 눌러서 여는 화면이 받은 평가라
  /// 목록에서 그 값을 미리 보여준다.
  final double? rating;

  bool get complete => quota > 0 && done >= quota;
}

/// 지점 고르개에 세울 지점 — 정해진 차례(화순 → 첨단 → 동광주)
///
/// **본사(HQ)는 안 세운다** — 지점이 아니라 전사다 (조직도 필터와 같은 기준).
/// **'전체'도 안 세운다** — 지점을 섞어 보면 어느 지점이 덜 냈는지가 안 보인다.
List<Branch> _branchChoices() {
  final directory = StaffDirectory.instance;
  return [...directory.branches.where((branch) => !branch.isHq)]..sort(
    (a, b) => directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
  );
}

/// 사람별 제출 현황 — 안 낸 사람이 위로 온다
///
/// 이 화면을 여는 이유가 "누가 아직 안 냈나" 이므로 그 순서로 세운다.
/// [branchId] 를 주면 그 지점 사람만 — **분모는 거르기 전에 센다.**
/// 지점마다 평가할 사람 수가 달라서 걸러낸 뒤에 세면 값이 달라진다.
List<_Submission> _submissionsOf(List<PeerReview> reviews, {String? branchId}) {
  final reviewers = _reviewers();

  final quota = <String, int>{};
  for (final employee in reviewers) {
    quota[employee.branchId] = (quota[employee.branchId] ?? 0) + 1;
  }
  final counts = <String, int>{};
  // 받은 평가의 별을 사람별로 모은다 — 자기 평가도 센다 (받은 평가 화면과 같은 범위)
  final stars = <String, List<int>>{};
  for (final review in reviews) {
    counts[review.reviewerId] = (counts[review.reviewerId] ?? 0) + 1;
    stars.putIfAbsent(review.revieweeId, () => []).addAll(review.stars.values);
  }
  final ratings = <String, double>{
    for (final entry in stars.entries)
      if (entry.value.isNotEmpty)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
  };

  return [
    for (final employee in reviewers)
      if (branchId == null || employee.branchId == branchId)
        _Submission(
          person: employee,
          done: counts[employee.id] ?? 0,
          quota: quota[employee.branchId] ?? 0,
          rating: ratings[employee.id],
        ),
  ]..sort((a, b) {
    if (a.complete != b.complete) return a.complete ? 1 : -1;
    return a.done.compareTo(b.done);
  });
}

/// 대표·관리자가 보는 화면 — 이번 달 누가 평가를 냈는지
///
/// 지점 바로 갈라서 본다. 전사를 한 목록에 두면 지점이 섞여서
/// 어느 지점이 덜 냈는지가 안 보인다.
class _SubmissionCard extends StatefulWidget {
  _SubmissionCard({required this.reviews, required this.period});

  final List<PeerReview> reviews;
  final String period;

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  /// 고른 지점 — 안 골랐으면 맨 앞 지점부터 본다
  String? _branch;

  /// 그 사람이 이번 달에 받은 평가를 열어 본다
  void _open(Employee person) => showFullPage<void>(
    context,
    (_) => _ReceivedScreen(person: person, reviews: widget.reviews),
  );

  @override
  Widget build(BuildContext context) {
    final choices = _branchChoices();
    // '전체'가 없으므로 늘 한 지점이 골라져 있다
    final branch = _branch ?? (choices.isEmpty ? null : choices.first.id);
    final rows = _submissionsOf(widget.reviews, branchId: branch);

    // 지점이 한 곳뿐이면 고를 게 없다
    final picker = [
      if (choices.length > 1) ...[
        SegmentedTabs(
          labels: [for (final b in choices) b.name],
          selected: choices
              .indexWhere((b) => b.id == branch)
              .clamp(0, choices.length - 1),
          onSelect: (i) => setState(() => _branch = choices[i].id),
        ),
        SizedBox(height: 16),
      ],
    ];

    // 폰은 사람마다 카드 한 장 — 평가 작성 목록([_PersonCard])과 같은 결이다.
    // 줄 내용은 그대로 두고 카드로만 나눈다. 전부 세우므로 전체보기가 없다.
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...picker,
          if (rows.isEmpty)
            EmptyCard(icon: Icons.group_rounded, text: '평가 대상 인원이 없어요')
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _SubmissionTile(row: rows[i], onTap: () => _open(rows[i].person)),
            ],
        ],
      );
    }

    // 카드에는 다섯 명만 — 나머지는 전체 보기에서
    final head = rows.take(5).toList();

    return Column(
      children: [
        ...picker,
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('제출 현황', style: AppTextStyles.label)),
                    SeeAllButton(
                      onTap: () => showFullPage<void>(
                        context,
                        (_) => _SubmissionScreen(
                          rows: rows,
                          reviews: widget.reviews,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
                  child: Text(
                    '평가 대상 인원이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < head.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.divider),
                  _SubmissionRow(
                    row: head[i],
                    onTap: () => _open(head[i].person),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 폰 목록의 한 장 — 줄 내용은 그대로 두고 카드로만 나눈다
///
/// [_SubmissionRow] 가 제 여백(가로 4·세로 12)을 들고 있어서 카드 여백에서
/// 그만큼 뺀다. 그래야 평가 작성 카드([_PersonCard], 가로 20·세로 18)와
/// 글자 시작점이 같아진다. 아래 별 줄의 위아래 간격도 같은 셈으로 맞춘다.
class _SubmissionTile extends StatelessWidget {
  _SubmissionTile({required this.row, required this.onTap});

  final _Submission row;

  /// 누르면 그 사람이 누구를 어떻게 평가했는지 열린다
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = row.rating;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 누름은 카드가 받으므로 줄에는 안 건다
            _SubmissionRow(row: row),
            // 받은 평점 미리보기 — 줄이 이미 아래 12를 들고 있어 2만 더한다
            Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 4, 12),
              child: Row(
                children: [
                  for (var i = 1; i <= peerStarCount; i++) ...[
                    if (i > 1) SizedBox(width: 3),
                    Icon(
                      rating != null && i <= rating.round()
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      size: 15,
                      color: rating != null
                          ? AppColors.primary
                          : AppColors.gray300,
                    ),
                  ],
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rating?.toStringAsFixed(1) ?? '아직 받은 평가가 없어요',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: rating != null
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: rating != null
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
