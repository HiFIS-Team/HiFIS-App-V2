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
  _Submission({required this.person, required this.done, required this.quota});

  final Employee person;

  /// 이번 달에 낸 평가 수
  final int done;

  /// 내야 하는 수 — 본인 지점에서 평가할 사람 수 (자기 자신 포함)
  final int quota;

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
  for (final review in reviews) {
    counts[review.reviewerId] = (counts[review.reviewerId] ?? 0) + 1;
  }

  return [
    for (final employee in reviewers)
      if (branchId == null || employee.branchId == branchId)
        _Submission(
          person: employee,
          done: counts[employee.id] ?? 0,
          quota: quota[employee.branchId] ?? 0,
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

  /// 그 사람이 이번 달에 누구를 어떻게 평가했는지 열어 본다
  void _open(Employee reviewer) => showFullPage<void>(
    context,
    (_) => _ReviewerScreen(reviewer: reviewer, reviews: widget.reviews),
  );

  @override
  Widget build(BuildContext context) {
    final choices = _branchChoices();
    // '전체'가 없으므로 늘 한 지점이 골라져 있다
    final branch = _branch ?? (choices.isEmpty ? null : choices.first.id);
    final rows = _submissionsOf(widget.reviews, branchId: branch);
    final done = rows.where((r) => r.complete).length;
    // 카드에는 다섯 명만 — 나머지는 전체 보기에서
    final head = rows.take(5).toList();

    return Column(
      children: [
        // 지점이 한 곳뿐이면 고를 게 없다
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
        _ReviewProgress(
          done: done,
          total: rows.length,
          finishedText: '모두 제출했어요',
          pendingLabel: (left) => '아직 $left명이 안 냈어요',
        ),
        SizedBox(height: 16),
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
