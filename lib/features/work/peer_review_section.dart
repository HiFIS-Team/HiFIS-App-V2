import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/peer_review_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/see_all_button.dart';

/// 동료 평가 탭 콘텐츠
///
/// 보는 사람에 따라 화면이 갈린다.
/// - **직원·점장** — 같은 지점 사람이 한 줄씩 나열되고 눌러서 평가를 쓴다
/// - **대표·관리자** — 평가를 쓰지 않는다. 대신 누가 냈는지 현황만 본다
///   (면담할 때 쓰는 자료다)
///
/// 점수는 항목마다 별 5개로 매기고, 별 하나의 가치가 대상에 따라 다르다
/// (본인 1점 → 전체 최대 25점 / 동료 4점 → 전체 최대 100점).
///
/// 평가는 **달마다 새로 쓴다.** 한 달 안에서는 같은 사람에게 한 번만 낼 수
/// 있고 낸 뒤에는 못 고친다 — 다시 누르면 그때 쓴 내용을 읽기만 한다.
class PeerReviewSection extends StatefulWidget {
  PeerReviewSection({super.key});

  @override
  State<PeerReviewSection> createState() => _PeerReviewSectionState();
}

/// 폰 목록 필터 — 평가는 냈거나 안 냈거나 둘뿐이라 두 칸이다
enum _Filter {
  pending('평가 전'),
  done('평가 완료');

  const _Filter(this.label);

  final String label;
}

class _PeerReviewSectionState extends State<PeerReviewSection> {
  bool _loading = true;

  /// 평가 대상 — 같은 지점 사람들, 본인이 맨 앞
  List<Employee> _targets = const [];

  /// 이번 달에 내가 낸 평가 (받는 사람 id → 평가)
  Map<String, PeerReview> _mine = const {};

  /// 이번 달 전체 평가 — 대표·관리자의 제출 현황에 쓴다
  List<PeerReview> _all = const [];

  /// 폰 목록 필터 — 남은 게 용건이라 '평가 전'부터 연다
  _Filter _filter = _Filter.pending;

  String get _period => periodKey(DateTime.now());

  /// 평가를 쓰는 사람인가 — 대표·관리자는 현황만 본다
  bool get _canReview => currentUser?.role.doesFieldWork ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = currentUser;
    try {
      final reviews = await PeerReviewApi.list(period: _period);
      if (!mounted) return;
      setState(() {
        _targets = _targetsOf(me);
        _all = reviews;
        // 대표·관리자는 남이 쓴 평가까지 오므로 내가 쓴 것만 남긴다
        // (직원·점장에게는 어차피 본인 것만 온다)
        _mine = {
          for (final review in reviews)
            if (review.reviewerId == me?.id) review.revieweeId: review,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _targets = _targetsOf(me);
        _loading = false;
      });
      AppToast.show(context, messageOf(error));
    }
  }

  /// 평가 대상 — 같은 지점에서 **현장 업무를 하는 사람**(직원·점장), 본인이 맨 앞
  ///
  /// 대표·관리자는 운영 전담이라 평가하지도, 평가받지도 않는다.
  static List<Employee> _targetsOf(Employee? me) {
    if (me == null || !me.role.doesFieldWork) return const [];
    return [
      me,
      for (final employee in StaffDirectory.instance.employees)
        if (employee.branchId == me.branchId &&
            employee.id != me.id &&
            employee.role.doesFieldWork)
          employee,
    ];
  }

  /// 평가 작성 — 폰은 밀려 들어오고 PC는 모달로 뜬다
  ///
  /// 이미 낸 사람이면 그때 쓴 내용을 읽기 전용으로 연다.
  Future<void> _openForm(Employee person) async {
    final submitted = await showFullPage<bool>(
      context,
      (_) => _PeerReviewFormScreen(
        person: person,
        isSelf: person.id == currentUser?.id,
        submitted: _mine[person.id],
      ),
    );
    if (submitted == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    // 대표·관리자는 평가를 쓰지 않는다 — 누가 냈는지만 본다
    if (!_canReview) return _SubmissionCard(reviews: _all, period: _period);

    // 아직 안 한 사람이 위로 온다 — 무엇이 남았는지가 이 화면의 용건이다
    final pending = [
      for (final person in _targets)
        if (!_mine.containsKey(person.id)) person,
    ];
    final done = [
      for (final person in _targets)
        if (_mine.containsKey(person.id)) person,
    ];
    final ordered = [...pending, ...done];

    // 폰은 필터 탭 + 사람 카드 (프로젝트 목록과 같은 결).
    // 데스크톱은 2단 화면이라 카드가 과해서 기존 줄 목록을 그대로 쓴다.
    if (!isDesktop) {
      final shown = _filter == _Filter.pending ? pending : done;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterTabs(
            selected: _filter,
            onSelect: (filter) => setState(() => _filter = filter),
          ),
          SizedBox(height: 16),
          if (shown.isEmpty)
            EmptyCard(
              icon: Icons.group_rounded,
              text: _targets.isEmpty
                  ? '평가할 사람이 없어요'
                  : _filter == _Filter.pending
                  ? '이번 달 평가를 모두 마쳤어요'
                  : '아직 평가한 사람이 없어요',
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _PersonCard(
                person: shown[i],
                isSelf: shown[i].id == currentUser?.id,
                review: _mine[shown[i].id],
                onTap: () => _openForm(shown[i]),
              ),
            ],
        ],
      );
    }

    return Column(
      children: [
        _ReviewProgress(done: done.length, total: _targets.length),
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
                    Expanded(child: Text('평가 작성', style: AppTextStyles.label)),
                    Text(
                      pending.isEmpty ? '모두 마쳤어요' : '남은 ${pending.length}명',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pending.isEmpty
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              if (ordered.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
                  child: Text(
                    '평가할 사람이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < ordered.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.divider),
                  _PersonRow(
                    person: ordered[i],
                    isSelf: ordered[i].id == currentUser?.id,
                    done: _mine.containsKey(ordered[i].id),
                    onTap: () => _openForm(ordered[i]),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

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

/// 지점 고르개 — `(지점 id, 이름)`. 맨 앞은 전체(id 가 null)
///
/// **본사(HQ)는 안 세운다** — 지점이 아니라 전사다 (조직도 필터와 같은 기준).
List<(String?, String)> _branchChoices() {
  final directory = StaffDirectory.instance;
  final sorted = [...directory.branches.where((branch) => !branch.isHq)]
    ..sort(
      (a, b) =>
          directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
    );
  return [(null, '전체'), for (final branch in sorted) (branch.id, branch.name)];
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
  /// 고른 지점 (null 이면 전체)
  String? _branch;

  @override
  Widget build(BuildContext context) {
    final choices = _branchChoices();
    final rows = _submissionsOf(widget.reviews, branchId: _branch);
    final done = rows.where((r) => r.complete).length;
    // 카드에는 다섯 명만 — 나머지는 전체 보기에서
    final head = rows.take(5).toList();

    return Column(
      children: [
        // 지점이 한 곳뿐이면 고를 게 없다 ('전체' + 그 지점 = 2)
        if (choices.length > 2) ...[
          SegmentedTabs(
            labels: [for (final (_, name) in choices) name],
            selected: choices.indexWhere((c) => c.$1 == _branch).clamp(0, 99),
            onSelect: (i) => setState(() => _branch = choices[i].$1),
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
                        (_) => _SubmissionScreen(rows: rows),
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
                  _SubmissionRow(row: head[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 제출 현황 전체 — 면담 준비할 때 훑어보는 목록
class _SubmissionScreen extends StatelessWidget {
  _SubmissionScreen({required this.rows});

  final List<_Submission> rows;

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
                    itemBuilder: (_, index) => _SubmissionRow(row: rows[index]),
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

/// 제출 현황 한 줄 — 이름·직급과 낸 건수
class _SubmissionRow extends StatelessWidget {
  _SubmissionRow({required this.row});

  final _Submission row;

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

// ---------------------------------------------------------------------------
// 평가 작성 (직원·점장)
// ---------------------------------------------------------------------------

/// 이번 달 평가 진행 — 몇 명 중 몇 명을 마쳤는지
class _ReviewProgress extends StatelessWidget {
  _ReviewProgress({
    required this.done,
    required this.total,
    this.finishedText = '이번 달 평가를 모두 마쳤어요',
    this.pendingLabel = _defaultPending,
  });

  final int done;
  final int total;

  /// 다 끝났을 때 아래에 뜨는 문구
  final String finishedText;

  /// 남았을 때 뜨는 문구 (남은 인원을 받는다)
  final String Function(int left) pendingLabel;

  static String _defaultPending(int left) => '$left명 남았어요';

  @override
  Widget build(BuildContext context) {
    final left = total - done;
    final finished = left == 0;
    final color = finished ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 동료 평가',
                  style: AppTextStyles.label,
                ),
              ),
              Text('$done', style: AppTextStyles.title2.copyWith(color: color)),
              Text(
                ' / $total명',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: total == 0 ? 0 : done / total, color: color),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                finished
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.pencil_circle_fill,
                size: 14,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  finished ? finishedText : pendingLabel(left),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 폰 목록 필터 — 프로젝트 목록의 단계 탭과 같은 모양
class _FilterTabs extends StatelessWidget {
  _FilterTabs({required this.selected, required this.onSelect});

  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          for (final filter in _Filter.values)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(filter),
                scale: 0.97,
                // 배경은 애니메이션 없이 즉시 바꾼다 (페이드가 있으면 두 칸이
                // 같이 눌린 것처럼 보인다)
                child: Container(
                  decoration: segmentFill(selected: filter == selected),
                  child: Center(
                    child: Text(
                      filter.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: filter == selected
                            ? AppColors.textPrimary
                            : AppColors.gray600,
                        fontWeight: filter == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 폰 목록 카드 — 프로젝트 카드와 같은 결로 사람 하나에 카드 하나
///
/// 아바타·이름·상태 배지 / 직급 / 별점 요약. 아직 안 한 사람은 빈 별이라
/// **무엇이 남았는지가 한눈에 보인다.**
///
/// 데스크톱은 아직 [_PersonRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _PersonCard extends StatelessWidget {
  _PersonCard({
    required this.person,
    required this.isSelf,
    required this.review,
    required this.onTap,
  });

  final Employee person;
  final bool isSelf;

  /// 이미 낸 평가 — 없으면 아직 안 한 사람이다
  final PeerReview? review;

  final VoidCallback onTap;

  /// 준 별점의 평균 (5개 항목)
  double get _average {
    final stars = review!.stars.values;
    return stars.isEmpty ? 0 : stars.reduce((a, b) => a + b) / stars.length;
  }

  @override
  Widget build(BuildContext context) {
    final done = review != null;
    final color = done ? AppColors.success : AppColors.primary;

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
                Avatar(name: person.name, size: 40),
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
                              style: AppTextStyles.body1.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            SizedBox(width: 6),
                            _Chip(text: '나', color: AppColors.primary),
                          ],
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        isSelf ? '본인 평가' : person.rank.label,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _StatusBadge(done: done),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                for (var i = 1; i <= peerStarCount; i++) ...[
                  if (i > 1) SizedBox(width: 3),
                  Icon(
                    done && i <= _average.round()
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    size: 15,
                    color: done ? color : AppColors.gray300,
                  ),
                ],
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done ? _average.toStringAsFixed(1) : '아직 평가하지 않았어요',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                      color: done ? color : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 오른쪽 위 상태 — 프로젝트 카드의 D-day 배지 자리
class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => _Chip(
    text: done ? '완료' : '평가하기',
    color: done ? AppColors.success : AppColors.primary,
    filled: false,
  );
}

/// 작은 알약 배지
class _Chip extends StatelessWidget {
  _Chip({required this.text, required this.color, this.filled = true});

  final String text;
  final Color color;

  /// true 면 색을 꽉 채우고 글자를 흰색으로 (이름 옆 '나' 배지)
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: filled ? 6 : 10, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: filled ? 10 : 12,
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 사람 한 줄 — 아바타·이름·소속과 끝의 이동 화살표
///
/// 이미 평가한 사람은 아바타가 한 톤 흐려지고 끝에 체크가 붙는다.
/// (눌러서 그때 쓴 내용을 다시 볼 수는 있다 — 고치지는 못한다)
class _PersonRow extends StatelessWidget {
  _PersonRow({
    required this.person,
    required this.isSelf,
    required this.onTap,
    this.done = false,
  });

  final Employee person;
  final bool isSelf;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = person.color ?? avatarColorFor(person.name);

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? color.withValues(alpha: 0.35) : color,
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
                Row(
                  children: [
                    Text(
                      person.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isSelf) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '나',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  done
                      ? '평가 완료'
                      : isSelf
                      ? '본인 평가'
                      : person.rank.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    color: done
                        ? AppColors.success
                        : isSelf
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.chevron_right,
            size: 16,
            color: done ? AppColors.success : AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 평가 작성 화면 — 사람 줄을 누르면 옆에서 슬라이드되어 열린다.
/// 5개 항목에 별점과 사유를 적고 제출한다.
///
/// [submitted] 가 있으면 이미 낸 평가라 **읽기만 한다.**
/// 서버가 같은 사람·같은 달 재제출을 409 로 막는다.
class _PeerReviewFormScreen extends StatefulWidget {
  _PeerReviewFormScreen({
    required this.person,
    required this.isSelf,
    this.submitted,
  });

  final Employee person;
  final bool isSelf;

  /// 이미 낸 평가 — 없으면 새로 쓰는 중
  final PeerReview? submitted;

  @override
  State<_PeerReviewFormScreen> createState() => _PeerReviewFormScreenState();
}

class _PeerReviewFormScreenState extends State<_PeerReviewFormScreen> {
  /// 항목별 별 개수 (점수가 아니라 별 개수를 담는다)
  late final Map<PeerCategory, int> _stars = {
    for (final category in PeerCategory.values)
      category: widget.submitted?.stars[category] ?? 0,
  };

  late final Map<PeerCategory, TextEditingController> _reasons = {
    for (final category in PeerCategory.values)
      category: TextEditingController(
        text: widget.submitted?.reasons[category] ?? '',
      ),
  };

  /// 이미 낸 평가를 열어 본 것 — 고칠 수 없다
  bool get _readOnly => widget.submitted != null;

  bool _saving = false;

  int get _perStar => peerPointsPerStar(isSelf: widget.isSelf);

  int get _total => _stars.values.fold(0, (sum, v) => sum + v) * _perStar;

  int get _maxTotal => peerStarCount * _perStar * PeerCategory.values.length;

  /// 모든 항목에 별점과 사유가 채워져야 제출이 열린다
  bool get _complete => PeerCategory.values.every(
    (c) => (_stars[c] ?? 0) > 0 && _reasons[c]!.text.trim().isNotEmpty,
  );

  @override
  void initState() {
    super.initState();
    // 사유 입력에 따라 제출 버튼 상태가 바뀌도록 갱신한다
    for (final controller in _reasons.values) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in _reasons.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setStars(PeerCategory category, int stars) {
    if (_readOnly || (_stars[category] ?? 0) == stars) return;
    // 드래그로 별을 훑을 때 한 칸씩 걸리는 느낌을 준다
    HapticFeedback.selectionClick();
    setState(() => _stars[category] = stars);
  }

  Future<void> _submit() async {
    if (!_complete) {
      AppToast.show(context, '모든 항목의 점수와 사유를 입력해주세요');
      return;
    }
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await PeerReviewApi.create(
        revieweeId: widget.person.id,
        period: periodKey(DateTime.now()),
        stars: _stars,
        reasons: {
          for (final entry in _reasons.entries)
            entry.key: entry.value.text.trim(),
        },
      );
      if (!mounted) return;
      AppToast.show(
        context,
        widget.isSelf ? '내 평가를 제출했습니다' : '${widget.person.name}님 평가를 제출했습니다',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;

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
                          '${widget.isSelf ? '본인 평가' : person.rank.label}'
                          ' · 별 1개 $_perStar점',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 $_total / $_maxTotal점',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (_readOnly)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                    color: AppColors.gray50,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock_fill,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '이미 제출한 평가예요. 고칠 수 없어요',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      // 하단 글래스 제출 버튼에 가리지 않도록 여유를 둔다
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      for (final category in PeerCategory.values) ...[
                        _StarRow(
                          label: category.label,
                          stars: _stars[category] ?? 0,
                          pointsPerStar: _perStar,
                          readOnly: _readOnly,
                          onChanged: (v) => _setStars(category, v),
                        ),
                        SizedBox(height: 12),
                        // 왜 이 점수인지 사유를 적는 칸 — 여러 줄 입력
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _reasons[category],
                            readOnly: _readOnly,
                            style: AppTextStyles.body2,
                            cursorColor: AppColors.primary,
                            keyboardType: TextInputType.multiline,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '왜 이 점수인지 적어주세요',
                              hintStyle: AppTextStyles.body2.copyWith(
                                color: AppColors.gray400,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],
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
                  child: Text(
                    widget.isSelf ? '내 평가' : '${person.name} 평가',
                    style: AppTextStyles.title3,
                  ),
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
          // 하단 고정: 제출 버튼 (키보드와 함께 상승)
          // 이미 낸 평가는 낼 것이 없으므로 버튼 자체를 두지 않는다
          if (!_readOnly)
            Align(
              alignment: Alignment.bottomCenter,
              child: BottomActionBar(
                children: [
                  Expanded(
                    child: BottomActionButton(
                      id: 'pr-submit',
                      label: _saving ? '제출 중...' : '평가 제출',
                      // 전 항목이 채워져야 채워진 상태가 되고,
                      // 미완성 시 동작은 _submit에서 무시한다
                      filled: _complete && !_saving,
                      onPressed: _submit,
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

/// 항목 한 칸 — 라벨·환산 점수 줄 + 별점 줄
class _StarRow extends StatelessWidget {
  _StarRow({
    required this.label,
    required this.stars,
    required this.pointsPerStar,
    required this.onChanged,
    this.readOnly = false,
  });

  final String label;
  final int stars;
  final int pointsPerStar;
  final ValueChanged<int> onChanged;

  /// 이미 낸 평가를 보는 중이면 별을 못 건드린다
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final active = stars > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                text: '${stars * pointsPerStar}',
                style: AppTextStyles.body2.copyWith(
                  color: active ? AppColors.primary : AppColors.gray400,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' / ${peerStarCount * pointsPerStar}점',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        IgnorePointer(
          ignoring: readOnly,
          child: _StarPicker(stars: stars, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// 별 5개 선택기 — 누르거나 가로로 쭉 그어서 한 번에 매긴다.
/// 이미 선택된 별을 다시 누르면 0으로 지워진다.
class _StarPicker extends StatelessWidget {
  _StarPicker({required this.stars, required this.onChanged});

  final int stars;
  final ValueChanged<int> onChanged;

  /// 별 하나가 차지하는 가로 칸 (아이콘 + 여백) — 이 값으로 좌표를 나눠 인덱스를 구한다
  static const _slot = 40.0;
  static const _icon = 32.0;
  static const _height = 40.0;

  int _starsAt(double dx) =>
      (dx / _slot).floor().clamp(0, peerStarCount - 1) + 1;

  void _tap(double dx) {
    final next = _starsAt(dx);
    // 같은 별을 다시 누르면 해제 (잘못 준 점수를 지울 방법)
    onChanged(next == stars ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _tap(d.localPosition.dx),
      onHorizontalDragStart: (d) => onChanged(_starsAt(d.localPosition.dx)),
      onHorizontalDragUpdate: (d) => onChanged(_starsAt(d.localPosition.dx)),
      child: SizedBox(
        width: _slot * peerStarCount,
        height: _height,
        child: Row(
          children: [
            for (var i = 0; i < peerStarCount; i++)
              SizedBox(
                width: _slot,
                child: Icon(
                  Icons.star_rounded,
                  size: _icon,
                  color: i < stars ? AppColors.primary : AppColors.gray200,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
