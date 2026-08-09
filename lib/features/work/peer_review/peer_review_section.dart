import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/peer_review_api.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/display/avatar.dart';
import '../../../core/widgets/display/person_card.dart';
import '../../../core/widgets/display/section_header.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
part 'peer_review_status.dart';
part 'peer_review_submission.dart';
part 'peer_review_people.dart';
part 'peer_review_form.dart';

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
  PeerReviewSection({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 전 지점
  ///
  /// MASTER·ADMIN 만 고를 수 있고, 그 밖에는 늘 null 이라 서버가 본인 지점으로
  /// 고정한다. 바뀌면 [didUpdateWidget] 에서 다시 받는다.
  final String? branchId;

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

  @override
  void didUpdateWidget(PeerReviewSection old) {
    super.didUpdateWidget(old);
    // 지점을 바꾸면 화면이 통째로 다른 지점 것이 된다 — 다시 받는다
    if (old.branchId != widget.branchId) _load();
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
    if (!_canReview) {
      return _SubmissionCard(
        reviews: _all,
        period: _period,
        branchId: widget.branchId,
      );
    }

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
      // 머리말 선과 카드 판이 폭을 다 쓰게 한다 (기본값은 가운데 정렬이라
      // 사람이 적으면 통째로 가운데로 밀린다 — 조직도에서 겪었다)
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewProgress(done: done.length, total: _targets.length),
        SizedBox(height: 16),
        // 흰 카드로 감싸지 않는다 — 조직도처럼 머리말 선으로만 가른다
        SectionHeader(
          title: '평가 작성',
          info: Text(
            pending.isEmpty ? '모두 마쳤어요' : '남은 ${pending.length}명',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: pending.isEmpty ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        SizedBox(height: 16),
        if (ordered.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 22),
            child: Text(
              '평가할 사람이 없어요',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          )
        else
          // 조직도 카드와 같은 틀 — 같은 사람을 보는 자리라 결이 같아야 한다
          PersonGrid(
            children: [
              for (final person in ordered)
                _PersonTile(
                  person: person,
                  isSelf: person.id == currentUser?.id,
                  done: _mine.containsKey(person.id),
                  onTap: () => _openForm(person),
                ),
            ],
          ),
      ],
    );
  }
}
