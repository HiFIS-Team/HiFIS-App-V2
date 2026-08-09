import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/kindness_api.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/display/person_card.dart';
import '../../../core/widgets/display/section_header.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
import '../../../core/widgets/nav/pane_transition.dart';
part 'praise_data.dart';
part 'praise_feedback.dart';
part 'praise_survey.dart';

/// 회원 친절도 탭 콘텐츠
///
/// 회원들이 남긴 칭찬과 컴플레인을 세그먼트로 나눠 본다.
/// 카드에는 최근 5건만 보여주고, 전체 보기에서 날짜별로 모아 본다.
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

class _PraiseSectionState extends State<PraiseSection> {
  /// 0 내게 온 칭찬 · 1 컴플레인 · 2 전체(설문 원본)
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

  Future<void> _load() async {
    try {
      await _loadSurveys(branchId: widget.branchId);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() {});
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

  /// 세그먼트 — '전체'는 누구에게 온 건지 가리지 않고 설문 원본을 그대로 본다
  Widget _tabs() {
    return SegmentedTabs(
      labels: [_viewOnly ? '칭찬' : '내게 온 칭찬', '컴플레인', '전체'],
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
    final title = _complaint ? '컴플레인' : (_viewOnly ? '칭찬' : '내게 온 칭찬');
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
      _FeedbackSummary(),
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
