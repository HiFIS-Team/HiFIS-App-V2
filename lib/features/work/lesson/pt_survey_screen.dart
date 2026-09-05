import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/pt_survey_api.dart';
import '../../../core/data/staff.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/when.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';

/// PT 만족도 폼 결과 화면 — **신규 회원 7회차에 열리는 설문을 보는 자리**
///
/// 서버는 진작에 `GET /pt-surveys` 를 열어 뒀는데 이걸 보는 화면이 앱에도
/// 웹에도 없었다 (2026-09-05). 폼은 회차마다 열리고 답도 들어오는데 아무도
/// 못 보고 있었다.
///
/// **볼 수 있는 사람이 서버에서 갈린다.** MASTER·ADMIN 은 전사, 점장은 자기
/// 지점이고, 트레이너(MEMBER)는 403 이다. 그리고 누구든 **자기가 수업한 것은
/// 안 온다** — 회원에게 "트레이너에게는 전달되지 않아요" 라고 적어 둔 자리라
/// 화면에만 적고 서버가 안 막으면 거짓말이 된다.
///
/// **아직 문자가 안 나간다.** 발신번호가 안 정해져서 서버는 줄만 만들어 두고
/// 링크를 들고 있다. 그래서 미응답 줄에는 주소 복사 버튼을 붙인다 — 그때까지는
/// 손으로 넘겨야 한다.
class PtSurveyScreen extends StatefulWidget {
  PtSurveyScreen({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 볼 수 있는 만큼 다
  final String? branchId;

  @override
  State<PtSurveyScreen> createState() => _PtSurveyScreenState();
}

class _PtSurveyScreenState extends State<PtSurveyScreen>
    with SkeletonDelay<PtSurveyScreen> {
  final _search = TextEditingController();

  /// 0 답변 온 것 · 1 아직 안 낸 것
  ///
  /// 갈라 두는 이유가 있다. **미응답은 할 일이고 응답은 읽을 거리다** —
  /// 한 줄에 섞으면 다시 물어봐야 할 사람이 답변 사이에 묻힌다.
  int _tab = 0;

  List<PtSurvey> _rows = const [];

  /// 다시 받는 중 — 버튼을 잠가 두 번 누르는 걸 막는다
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  /// 손으로 다시 받기 — 회원이 방금 낸 답을 보려고 화면을 닫았다 여는 일을 없앤다
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _load();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void didUpdateWidget(PtSurveyScreen old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // **한 번만 받아 앱에서 가른다.** `unanswered` 로 두 번 부르면 탭을
      // 옮길 때마다 기다리게 된다 — 어차피 등록권당 한 줄이라 양이 적다
      final rows = await PtSurveyApi.list(branchId: widget.branchId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 문자가 나가기 전까지 손으로 넘기는 길 — 주소를 복사해 둔다
  Future<void> _copyLink(PtSurvey survey) async {
    if (survey.url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: survey.url));
    if (mounted) AppToast.show(context, '주소를 복사했어요 · 회원에게 보내세요');
  }

  bool _matches(PtSurvey survey, String query) {
    if (query.isEmpty) return true;
    return survey.displayMember.contains(query) ||
        survey.displayTrainer.contains(query) ||
        (survey.request ?? '').contains(query);
  }

  List<PtSurvey> get _shown {
    final query = _search.text.trim();
    final wantAnswered = _tab == 0;
    return [
      for (final survey in _rows)
        if (survey.answered == wantAnswered)
          if (_matches(survey, query)) survey,
    ];
  }

  /// 줄을 세우는 기준값 — 답변은 답한 때, 미응답은 열린 때다
  DateTime _sortKey(PtSurvey survey) => survey.answeredAt ?? survey.createdAt;

  /// 차례를 매긴다 — **두 탭이 반대 방향이다**
  ///
  /// 답변은 새것이 위다 (방금 온 것을 읽는 자리다).
  /// 미응답은 **오래된 것이 위다** — 제일 오래 기다린 사람이 먼저 챙겨야 할
  /// 사람이라, 새것부터 세우면 정작 잊힌 줄이 맨 아래로 가라앉는다.
  int _compare(PtSurvey a, PtSurvey b) => _tab == 0
      ? _sortKey(b).compareTo(_sortKey(a))
      : _sortKey(a).compareTo(_sortKey(b));

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final sorted = _shown..sort(_compare);
    final answered = _tab == 0;

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다 — 세션 기록·설문 응답과 같다
    final children = <Widget>[];
    String? label;
    for (final survey in sorted) {
      final day = dayLabel(_sortKey(survey));
      if (day != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              day,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = day;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _PtSurveyRow(
          survey: survey,
          onTap: () => _showPtSurveyDetail(context, survey),
          onCopy: survey.answered ? null : () => _copyLink(survey),
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
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SegmentedTabs(
                    labels: ['답변', '미응답'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          answered
                              ? '신규 회원 7회차에 받은 만족도'
                              : '아직 답을 안 준 회원 · 주소를 복사해 보내요',
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
                if (showSkeleton)
                  Expanded(child: Center(child: DelayedSpinner.bare()))
                else if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      query.isNotEmpty
                          ? '검색 결과가 없어요'
                          : answered
                          ? '아직 들어온 답변이 없어요'
                          : '기다리는 설문이 없어요',
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
                child: Center(
                  child: Text('PT 만족도', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 · 우측 다시 받기 (글래스 버튼)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                children: [
                  GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                  Spacer(),
                  // **밖에서 들어오는 값**이라 다시 받는 길이 있어야 한다 —
                  // 주소를 보내 놓고 답이 왔나 보는 자리다
                  GlassIconButton(
                    symbol: 'arrow.clockwise',
                    onPressed: _refreshing ? null : _refresh,
                  ),
                ],
              ),
            ),
          ),
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '회원·트레이너·내용 검색'),
        ],
      ),
    );
  }
}

/// 목록 한 줄 — 아바타 · 회원/트레이너 · 만족도·연장 꼬리표
class _PtSurveyRow extends StatelessWidget {
  _PtSurveyRow({required this.survey, required this.onTap, this.onCopy});

  final PtSurvey survey;
  final VoidCallback onTap;

  /// 미응답 줄에만 있다 — 문자가 나가기 전까지 손으로 넘기는 길
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(survey.displayMember);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                survey.displayMember.characters.first,
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
                    survey.displayMember,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${survey.displayTrainer} · ${survey.sessionNo}회차',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            if (survey.answered) ...[
              if (survey.satisfaction case final score?)
                _PtTag(label: '만족 $score', color: AppColors.primary),
              if (survey.renew case final renew?) ...[
                SizedBox(width: 6),
                _PtTag(label: renew.label, color: _renewColor(renew)),
              ],
            ] else
              // 문자가 나가기 전까지 손으로 넘기는 길 — 회원 수업 주소 카드와 같은 모양이다
              Pressable(
                onTap: onCopy ?? () {},
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '주소 복사',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 연장 의향 색 — **연장 안 한다는 답이 눈에 띄어야 한다** (붙잡을 시간이 남았다)
Color _renewColor(RenewIntent renew) => switch (renew) {
  RenewIntent.yes => AppColors.success,
  RenewIntent.maybe => AppColors.warning,
  RenewIntent.no => AppColors.error,
};

class _PtTag extends StatelessWidget {
  _PtTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 답변 크게 보기 — 받은 문항을 순서대로 그대로 보여준다
void _showPtSurveyDetail(BuildContext context, PtSurvey survey) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'PT 만족도 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _PtSurveyDetailCard(survey: survey),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PtSurveyDetailCard extends StatelessWidget {
  _PtSurveyDetailCard({required this.survey});

  final PtSurvey survey;

  @override
  Widget build(BuildContext context) {
    // 좁은 화면에서는 화면 폭에 맞춘다
    final width = MediaQuery.sizeOf(context).width - 40;
    final when = survey.answeredAt ?? survey.createdAt;

    return Container(
      width: width < 320 ? width : 320,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColorFor(survey.displayMember),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.displayMember.characters.first,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 18,
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
                        survey.displayMember,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${survey.displayTrainer} · ${survey.sessionNo}회차 · '
                        '${dayLabel(when)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            if (!survey.answered)
              _PtField(
                label: '상태',
                value: '아직 답을 안 줬어요',
                valueColor: AppColors.textTertiary,
              )
            else ...[
              _PtField(
                label: '만족도',
                value: survey.satisfaction == null
                    ? ''
                    : '${survey.satisfaction} / 5',
              ),
              _PtField(
                label: '앞으로 트레이너에게 바라는 점',
                value: survey.request ?? '',
              ),
              _PtField(
                label: '연장 여부',
                value: survey.renew?.label ?? '',
                valueColor: survey.renew == null
                    ? null
                    : _renewColor(survey.renew!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 문항 한 칸 — 라벨 위, 값 아래. 빈 값은 흐리게 둔다
class _PtField extends StatelessWidget {
  _PtField({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value.isEmpty ? '적지 않았어요' : value,
            style: AppTextStyles.body2.copyWith(
              height: 1.5,
              color:
                  valueColor ??
                  (value.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
