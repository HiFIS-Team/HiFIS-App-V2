import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/kindness_api.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/display/person_card.dart';
import '../../../core/widgets/display/section_header.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
import '../../../core/widgets/nav/pane_transition.dart';
import '../work_skeleton.dart';
part 'praise_data.dart';
part 'praise_feedback.dart';
part 'praise_survey.dart';

/// 회원 친절도 탭 콘텐츠
///
/// 회원들이 남긴 칭찬과 컴플레인을 세그먼트로 나눠 본다.
///
/// **폰**은 최근 5건만 보여주고 전체 보기에서 날짜별로 모아 본다.
/// **PC**는 전체 보기 없이 다 세운다 (조직도와 같은 카드 판).
class PraiseSection extends StatefulWidget {
  PraiseSection({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 전 지점
  ///
  /// MASTER·ADMIN 만 고를 수 있고, 그 밖에는 늘 null 이라 서버가 본인 지점으로
  /// 고정한다. 바뀌면 [didUpdateWidget] 에서 다시 받는다.
  final String? branchId;

  @override
  State<PraiseSection> createState() => _PraiseSectionState();
}

class _PraiseSectionState extends State<PraiseSection>
    with SkeletonDelay<PraiseSection> {
  /// 0 칭찬 · 1 컴플레인 · 2 전체(설문 원본)
  int _tab = 0;

  bool get _complaint => _tab == 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PraiseSection old) {
    super.didUpdateWidget(old);
    // 지점을 바꾸면 화면이 통째로 다른 지점 것이 된다 — 다시 받는다
    if (old.branchId != widget.branchId) _load();
  }

  /// 받아오는 동안 뼈대를 깐다 — 수업·기여도·동료 평가와 같은 방식이다
  ///
  /// 안 깔면 그동안 `아직 받은 칭찬이 없어요` 가 떠서 **없다고 잘못 알려준다.**
  /// 지점을 바꿀 때는 [beginLoad] 를 안 부른다 — 옛 줄을 둔 채로 갈아끼운다
  /// (다른 업무 칸도 같다).
  Future<void> _load() async {
    try {
      await _loadSurveys(branchId: widget.branchId);
      if (!mounted) return;
      setState(endLoad);
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  void _openHistory() {
    showFullPage<void>(
      context,
      (_) => _FeedbackHistoryScreen(complaint: _complaint),
    );
  }

  void _openSurveys() {
    showFullPage<void>(context, (_) => _SurveyHistoryScreen());
  }

  /// 세그먼트 — '전체'는 설문 원본(응답자·동기·대상자)을 그대로 본다
  ///
  /// **'칭찬' 은 지점 것을 다 본다.** 예전에는 직원·점장에게만 '내게 온 칭찬'
  /// 이었는데, 지점 사람은 다 볼 수 있어야 해서 이름이 하나가 됐다
  /// (2026-08-31 대표 요청). 누구에 대한 것인지는 카드에 이름으로 붙는다.
  Widget _tabs() {
    return SegmentedTabs(
      labels: ['칭찬', '컴플레인', '전체'],
      selected: _tab,
      onSelect: (i) => setState(() => _tab = i),
    );
  }

  /// 목록바 + 그 아래 내용 — 탭을 옮기면 내용만 갈린다
  ///
  /// 가지가 넷(폰·데스크톱 × 전체 탭 여부)이라 껍데기를 한 곳에 둔다.
  /// 전환은 업무·랭킹·모니터링과 같은 [PaneTransition] 이다.
  Widget _framed(List<Widget> body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(),
        PaneTransition(
          step: _tab,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      ],
    );
  }

  /// 폰 목록 머리말 — 제목·건수와 전체 보기
  Widget _listHead({
    required String title,
    required int count,
    required VoidCallback onOpenAll,
    List<Widget> extra = const [],
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(width: 8),
          Text('$count', style: AppTextStyles.caption),
          ...extra,
          Spacer(),
          SeeAllButton(onTap: onOpenAll),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return WorkSectionSkeleton();

    if (_tab == 2) {
      final sorted = _surveys;
      // 카드에는 최근 5건만 — 나머지는 전체 보기 화면에서
      final recent = sorted.take(5).toList();

      if (!isDesktop) {
        return _framed([
          SizedBox(height: 20),
          _listHead(
            title: '설문 응답',
            count: sorted.length,
            onOpenAll: _openSurveys,
          ),
          SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(icon: Icons.assignment_rounded, text: '아직 들어온 설문이 없어요')
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _SurveyCardItem(
                survey: recent[i],
                onTap: () => _showSurveyDetail(context, recent[i]),
              ),
            ],
        ]);
      }

      return _framed([SizedBox(height: 16), _SurveyCard()]);
    }

    final items = _feedbacks.where((f) => f.complaint == _complaint).toList();
    // 카드에는 최근 5건만 — 나머지는 전체 보기 화면에서
    final recent = items.take(5).toList();
    final title = _complaint ? '컴플레인' : '칭찬';
    final unresolved = _complaint && _showStatus
        ? items.where((f) => f.status == _Status.pending).length
        : 0;

    // 폰은 피드백마다 카드 하나 (프로젝트·동료 평가 목록과 같은 결).
    // 데스크톱은 2단 화면이라 카드가 과해서 기존 줄 목록을 그대로 쓴다.
    if (!isDesktop) {
      return _framed([
        SizedBox(height: 20),
        _listHead(
          title: title,
          count: items.length,
          onOpenAll: _openHistory,
          // 컴플레인은 아직 손대지 않은 건수를 같이 알려준다
          extra: [
            if (unresolved > 0) ...[
              SizedBox(width: 8),
              Text(
                '미처리 $unresolved',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12),
        if (recent.isEmpty)
          EmptyCard(
            icon: _complaint
                ? Icons.report_gmailerrorred_rounded
                : Icons.favorite_rounded,
            text: _complaint ? '아직 컴플레인이 없어요' : '아직 받은 칭찬이 없어요',
          )
        else
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) SizedBox(height: 12),
            _FeedbackCard(
              feedback: recent[i],
              onTap: () => _showFeedbackDetail(
                context,
                recent[i],
                onChanged: () => setState(() {}),
              ),
            ),
          ],
      ]);
    }

    return _framed([
      SizedBox(height: 16),
      // 흰 카드로 감싸지 않는다 — 조직도처럼 머리말 선으로만 가른다
      SectionHeader(
        title: title,
        info: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${items.length}', style: AppTextStyles.caption),
            // 컴플레인은 아직 손대지 않은 건수를 같이 알려준다
            if (unresolved > 0) ...[
              SizedBox(width: 6),
              Text(
                '미처리 $unresolved',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      SizedBox(height: 16),
      // **전체를 다 세운다** — 전체 보기를 없앴으므로 여기서 다 보여야 한다
      if (items.isEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 22),
          child: Text(
            _complaint ? '아직 컴플레인이 없어요' : '아직 받은 칭찬이 없어요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          ),
        )
      else
        // 조직도 카드와 같은 틀 — 업무의 사람 목록은 PC 에서 다 이 모양이다
        PersonGrid(
          children: [
            for (final feedback in items)
              _FeedbackTile(
                feedback: feedback,
                onTap: () => _showFeedbackDetail(
                  context,
                  feedback,
                  onChanged: () => setState(() {}),
                ),
              ),
          ],
        ),
    ]);
  }
}
