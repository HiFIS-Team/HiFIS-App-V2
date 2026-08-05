import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/kindness_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/progress_bar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_search_bar.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
part 'praise_data.dart';
part 'praise_feedback.dart';
part 'praise_survey.dart';

/// 회원 친절도 탭 콘텐츠
///
/// 회원들이 남긴 칭찬과 컴플레인을 세그먼트로 나눠 본다.
/// 카드에는 최근 5건만 보여주고, 전체 보기에서 날짜별로 모아 본다.
class PraiseSection extends StatefulWidget {
  PraiseSection({super.key});

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

  Future<void> _load() async {
    try {
      await _loadSurveys();
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabs(),
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
          ],
        );
      }

      return Column(
        children: [
          _tabs(),
          SizedBox(height: 16),
          _SurveyCard(onOpenAll: _openSurveys),
        ],
      );
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabs(),
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
        ],
      );
    }

    return Column(
      children: [
        _tabs(),
        SizedBox(height: 16),
        _FeedbackSummary(),
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
                    Text(title, style: AppTextStyles.label),
                    SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '${items.length}',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
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
                    SeeAllButton(onTap: _openHistory),
                  ],
                ),
              ),
              SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
                  child: Text(
                    _complaint ? '아직 컴플레인이 없어요' : '아직 받은 칭찬이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.divider),
                  _FeedbackRow(
                    feedback: recent[i],
                    onTap: () => _showFeedbackDetail(
                      context,
                      recent[i],
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
