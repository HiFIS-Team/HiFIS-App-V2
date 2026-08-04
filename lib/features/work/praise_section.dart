import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/kindness_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/see_all_button.dart';

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
      final sorted = [..._surveys]..sort((a, b) => b.time.compareTo(a.time));
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

    final items = _feedbacks.where((f) => f.complaint == _complaint).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
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

/// 받은 피드백 요약 — 칭찬이 몇 %인지와 남은 컴플레인
///
/// 목록만 있으면 잘하고 있는지 알 수 없다. 칭찬 비율 하나로 보여준다.
class _FeedbackSummary extends StatelessWidget {
  _FeedbackSummary();

  @override
  Widget build(BuildContext context) {
    final praise = _feedbacks.where((f) => !f.complaint).length;
    final complaint = _feedbacks.where((f) => f.complaint).length;
    final total = praise + complaint;
    final rate = total == 0 ? 0.0 : praise / total;
    final pending = _feedbacks
        .where((f) => f.complaint && f.status == _Status.pending)
        .length;

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
              Expanded(child: Text('칭찬 비율', style: AppTextStyles.label)),
              Text(
                '${(rate * 100).round()}',
                style: AppTextStyles.title2.copyWith(color: AppColors.success),
              ),
              Text(
                '%',
                style: AppTextStyles.body2.copyWith(color: AppColors.success),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: rate, color: AppColors.success),
          SizedBox(height: 12),
          Row(
            children: [
              _dot(AppColors.success, '칭찬', praise),
              SizedBox(width: 14),
              _dot(AppColors.gray300, '컴플레인', complaint),
              Spacer(),
              // 아직 손대지 않은 컴플레인이 있으면 그게 제일 급한 일이다
              if (_showStatus && pending > 0)
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle_fill,
                      size: 13,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '미처리 $pending건',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label, int count) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 6),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      SizedBox(width: 4),
      Text(
        '$count',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 컴플레인 처리 단계 (칭찬에는 쓰지 않는다)
enum _Status {
  pending('미처리'),
  working('해결중'),
  done('해결 완료');

  const _Status(this.label);

  final String label;

  Color get color => switch (this) {
    _Status.pending => AppColors.warning,
    _Status.working => AppColors.primary,
    _Status.done => AppColors.success,
  };

  ComplaintStatus get wire => switch (this) {
    _Status.pending => ComplaintStatus.pending,
    _Status.working => ComplaintStatus.working,
    _Status.done => ComplaintStatus.done,
  };

  static _Status of(ComplaintStatus status) => switch (status) {
    ComplaintStatus.pending => _Status.pending,
    ComplaintStatus.working => _Status.working,
    ComplaintStatus.done => _Status.done,
  };
}

/// 회원이 남긴 피드백 한 건 (칭찬 또는 컴플레인)
///
/// 설문 한 건에서 최대 두 줄이 나온다 — 칭찬 한 줄, 개선 의견 한 줄.
/// 그래서 [surveyId] 가 둘이 같을 수 있다.
class _Feedback {
  _Feedback({
    required this.name,
    required this.colorValue,
    required this.text,
    required this.time,
    this.surveyId,
    this.complaint = false,
    this.status = _Status.pending,
    this.about,
  });

  /// 원본 설문 id — 처리 단계를 서버에 올릴 때 쓴다
  final String? surveyId;

  final String name;
  final int colorValue;
  final String text;
  final DateTime time;
  final bool complaint;

  /// 컴플레인 처리 단계 — 상세 화면에서 바꾼다
  _Status status;

  /// 누구에게 온 것인지 — **전사로 볼 때만** 채운다 (본인 것만 볼 때는 뻔하다)
  final String? about;

  Color get color => Color(colorValue);
}

/// 현장 업무를 안 하는 사람 — 대표·관리자
///
/// 설문은 트레이너를 칭찬하는 것이라 대표·관리자는 받을 일이 없다.
/// 본인 것으로 거르면 늘 비어서, 대신 **전사 칭찬·컴플레인**을 조회로 본다.
bool get _viewOnly => !(currentUser?.role.doesFieldWork ?? true);

/// 컴플레인 처리 단계 UI를 그릴지
///
/// 예전에는 폰에서만 그렸는데, 컴플레인을 챙기는 대표·관리자가 PC 를 쓴다.
/// PC 에서 버튼이 없으면 아무도 해결을 못 찍는다.
bool get _showStatus => true;

/// 서버에서 받은 설문 — 화면 셋이 같이 쓴다
///
/// **한 번만 받아 둘로 나눈다.** '전체' 탭은 설문 원본을 그대로 보고,
/// '내게 온 칭찬'·'컴플레인' 은 그중 내가 칭찬받은 것만 줄로 편다
/// (설문 하나에서 칭찬 한 줄 · 개선 의견 한 줄이 나온다).
final _feedbacks = <_Feedback>[];
final _surveys = <_Survey>[];

Future<void> _loadSurveys() async {
  final rows = await KindnessApi.list();
  final me = currentUser?.id;

  _surveys
    ..clear()
    ..addAll([
      for (final row in rows)
        _Survey(
          name: row.memberName,
          phone: row.memberPhone,
          colorValue: avatarColorFor(row.memberName).toARGB32(),
          motive: row.motivation,
          praised:
              StaffDirectory.instance.byId(row.praisedEmployeeId)?.name ?? '',
          improve: row.improvement ?? '',
          consent: row.consent,
          time: row.submittedAt,
        ),
    ]);

  _feedbacks
    ..clear()
    ..addAll([
      for (final row in rows)
        // 직원·점장은 본인에게 온 것만, 대표·관리자는 전사를 본다
        if (_viewOnly || row.praisedEmployeeId == me) ...[
          if (row.praiseComment.trim().isNotEmpty)
            _Feedback(
              surveyId: row.id,
              name: row.memberName,
              colorValue: avatarColorFor(row.memberName).toARGB32(),
              text: row.praiseComment,
              time: row.submittedAt,
              about: _viewOnly ? _employeeName(row.praisedEmployeeId) : null,
            ),
          if (row.isComplaint)
            _Feedback(
              surveyId: row.id,
              name: row.memberName,
              colorValue: avatarColorFor(row.memberName).toARGB32(),
              text: row.improvement!,
              time: row.submittedAt,
              complaint: true,
              status: _Status.of(row.improvementStatus),
              about: _viewOnly ? _employeeName(row.praisedEmployeeId) : null,
            ),
        ],
    ]);
}

/// 설문이 가리키는 직원 이름 — 명단에 없으면 빈 값
String? _employeeName(String id) {
  final name = StaffDirectory.instance.byId(id)?.name;
  return name == null || name.isEmpty ? null : name;
}

/// '7.29 오후 5:36' 형태
String _formatStamp(DateTime time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}.${time.day} $period $hour:$minute';
}

/// 피드백 줄을 누르면 전체 내용을 크게 보여준다.
/// 컴플레인이면 아래에 처리 단계 버튼이 붙고, 바꾸면 [onChanged]로 목록을 새로 그린다.
void _showFeedbackDetail(
  BuildContext context,
  _Feedback feedback, {
  VoidCallback? onChanged,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '피드백 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _FeedbackDetailCard(feedback: feedback, onChanged: onChanged),
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

/// 바뀐 단계를 서버에 올린다 — 실패하면 되돌린다
///
/// 창이 이미 닫힌 뒤라 여기서 토스트를 띄울 자리가 없다. 실패하면 목록의
/// 알약이 원래 색으로 돌아가는 것이 신호다. 그래서 위젯이 아니라 값만
/// 넘겨받는다 (닫힌 위젯의 `widget` 을 만지면 터진다).
Future<void> _push(
  String id,
  _Feedback feedback,
  _Status next,
  _Status before,
  VoidCallback? onChanged,
) async {
  try {
    await KindnessApi.setStatus(id, next.wire);
  } catch (_) {
    feedback.status = before;
    onChanged?.call();
  }
}

/// 피드백 크게 보기 카드 — 컴플레인은 처리 단계를 여기서 바꾼다
class _FeedbackDetailCard extends StatefulWidget {
  _FeedbackDetailCard({required this.feedback, this.onChanged});

  final _Feedback feedback;
  final VoidCallback? onChanged;

  @override
  State<_FeedbackDetailCard> createState() => _FeedbackDetailCardState();
}

class _FeedbackDetailCardState extends State<_FeedbackDetailCard> {
  /// 처리 단계를 바꾸고 창을 닫는다
  ///
  /// 해결중은 같은 버튼을 다시 누르면 미처리로 되돌린다 (잘못 누른 걸 취소할 방법).
  /// **해결 완료는 못 되돌린다** — 찍는 순간 환경정비 '클레임해결' 점수가 붙어서
  /// 되돌렸다 다시 찍으면 점수가 두 번 쌓인다. 서버도 400 으로 막는다.
  ///
  /// **고르면 바로 닫고 토스트로 알린다.** 창을 열어둔 채 색만 바꾸면
  /// 처리가 됐는지 안 됐는지 알 수가 없다.
  void _pick(_Status status) {
    final feedback = widget.feedback;
    // 완료는 되돌리는 길이 없으므로 같은 버튼을 다시 눌러도 완료다
    final next = status != _Status.done && feedback.status == status
        ? _Status.pending
        : status;
    final before = feedback.status;

    // 누르는 순간 바꾸고 서버에 올린다. 실패하면 되돌린다 —
    // 창을 닫고 나서 결과를 기다리면 목록이 잠깐 거짓말을 한다.
    feedback.status = next;
    widget.onChanged?.call();

    final id = feedback.surveyId;
    if (id != null) _push(id, feedback, next, before, widget.onChanged);

    AppToast.show(
      context,
      next == _Status.pending
          ? '미처리로 되돌렸어요'
          : '${next.label}${_particleRo(next.label)} 바꿨어요',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final withStatus = feedback.complaint && _showStatus;

    return Container(
      width: 300,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: feedback.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              feedback.name.characters.first,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            feedback.name,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
          ),
          if (withStatus) ...[
            SizedBox(height: 8),
            _StatusChip(status: feedback.status),
          ],
          SizedBox(height: 12),
          Text(
            feedback.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(_formatStamp(feedback.time), style: AppTextStyles.caption),
          if (withStatus) ...[
            SizedBox(height: 18),
            if (feedback.status == _Status.done)
              // 이미 끝난 건은 손댈 수 없다 — 버튼 대신 안내만 둔다
              Text(
                '해결 완료된 컴플레인은 되돌릴 수 없어요',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _StatusButton(
                      status: _Status.working,
                      selected: feedback.status == _Status.working,
                      onTap: () => _pick(_Status.working),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StatusButton(
                      status: _Status.done,
                      selected: false,
                      onTap: () => _pick(_Status.done),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// 앞말 받침에 맞는 조사 — `해결중으로` / `해결 완료로`
///
/// 상태 이름이 늘어나도 문장이 어색해지지 않게 계산해서 붙인다.
String _particleRo(String word) {
  final code = word.runes.last;
  // 한글 음절이 아니면(영문·숫자) 그냥 '로'
  if (code < 0xAC00 || code > 0xD7A3) return '로';
  final jongseong = (code - 0xAC00) % 28;
  // 받침이 없거나 ㄹ 받침이면 '로', 그 외에는 '으로'
  return jongseong == 0 || jongseong == 8 ? '로' : '으로';
}

/// 처리 단계 알약 — 목록·상세에 같이 쓴다
class _StatusChip extends StatelessWidget {
  _StatusChip({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: status.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 처리 단계 버튼 — 고르면 그 단계 색으로 꽉 찬다
class _StatusButton extends StatelessWidget {
  _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final _Status status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      pressedColor: selected ? null : AppColors.gray100,
      borderRadius: BorderRadius.circular(14),
      // 애니메이션 없이 즉시 바꾼다 (색이 서서히 빠지면 둘 다 눌린 듯 보인다)
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? status.color : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: Colors.white),
              SizedBox(width: 4),
            ],
            Text(
              status.label,
              style: AppTextStyles.body2.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 피드백 한 줄 — 아바타, 이름, 내용, 시각과 끝의 화살표
/// 폰 목록 카드 — 프로젝트·동료 평가 목록과 같은 결로 피드백 하나에 카드 하나
///
/// 데스크톱은 아직 [_FeedbackRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _FeedbackCard extends StatelessWidget {
  _FeedbackCard({required this.feedback, required this.onTap});

  final _Feedback feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showStatus = feedback.complaint && _showStatus;

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
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: feedback.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    feedback.name.characters.first,
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
                        feedback.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        // 전사로 볼 때는 누구에게 온 것인지가 먼저다
                        feedback.about == null
                            ? _formatStamp(feedback.time)
                            : '${feedback.about} · '
                                  '${_formatStamp(feedback.time)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // 컴플레인만 처리 단계가 있다 — 칭찬은 배지 자리가 빈다
                if (showStatus) ...[
                  SizedBox(width: 8),
                  _StatusChip(status: feedback.status),
                ],
              ],
            ),
            SizedBox(height: 14),
            Text(
              feedback.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  _FeedbackRow({required this.feedback, required this.onTap});

  final _Feedback feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: feedback.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              feedback.name.characters.first,
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
                      feedback.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (feedback.complaint && _showStatus) ...[
                      SizedBox(width: 6),
                      _StatusChip(status: feedback.status),
                    ],
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  feedback.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  feedback.about == null
                      ? _formatStamp(feedback.time)
                      : '${feedback.about} · ${_formatStamp(feedback.time)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 피드백 전체 화면 — 옆에서 슬라이드되어 열리고 날짜별로 묶어 보여준다
class _FeedbackHistoryScreen extends StatefulWidget {
  _FeedbackHistoryScreen({required this.complaint});

  /// true면 컴플레인 기록
  final bool complaint;

  @override
  State<_FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<_FeedbackHistoryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${time.month}.${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final base = _feedbacks.where((f) => f.complaint == widget.complaint);
    final sorted =
        base
            .where(
              (f) =>
                  query.isEmpty ||
                  f.name.contains(query) ||
                  f.text.contains(query),
            )
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    final title = widget.complaint ? '컴플레인' : '내게 온 칭찬';
    final unresolved = widget.complaint && _showStatus
        ? sorted.where((f) => f.status == _Status.pending).length
        : 0;

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final feedback in sorted) {
      final dayLabel = _dayLabel(feedback.time);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _FeedbackRow(
          feedback: feedback,
          onTap: () => _showFeedbackDetail(
            context,
            feedback,
            onChanged: () => setState(() {}),
          ),
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
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.complaint
                              ? (unresolved > 0
                                    ? '받은 컴플레인 기록 · 미처리 $unresolved건'
                                    : '받은 컴플레인 기록')
                              : '받은 칭찬 기록',
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
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      query.isEmpty
                          ? (widget.complaint
                                ? '아직 컴플레인이 없어요'
                                : '아직 받은 칭찬이 없어요')
                          : '검색 결과가 없어요',
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
                child: Center(child: Text(title, style: AppTextStyles.title3)),
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
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '이름·내용 검색'),
        ],
      ),
    );
  }
}

// ── QR 설문 원본 ──

/// QR 설문으로 들어온 응답 한 건
///
/// 회원이 센터의 QR을 찍어 문항을 채워 보내면 그대로 쌓인다.
/// 칭찬·컴플레인 탭은 여기서 갈라 나온 것이고, '전체' 탭은 누구에게 온
/// 응답인지 가리지 않고 원본을 그대로 보여준다.
class _Survey {
  _Survey({
    required this.name,
    required this.phone,
    required this.colorValue,
    required this.motive,
    required this.praised,
    required this.improve,
    required this.time,
    this.consent = true,
  });

  /// 성함
  final String name;

  /// 연락처
  final String phone;
  final int colorValue;

  /// 운동을 시작하게 된 계기
  final String motive;

  /// 칭찬하고 싶은 직원 (안 적었으면 빈 값)
  final String praised;

  /// 개선했으면 하는 부분 (안 적었으면 빈 값)
  final String improve;

  /// 개인정보 수집 및 이용 동의
  final bool consent;

  final DateTime time;

  Color get color => Color(colorValue);
}

// 설문 목록(_surveys)은 위 _loadSurveys() 가 채운다.

/// '전체' 탭 카드 — 최근 설문 5건과 전체 보기 버튼
class _SurveyCard extends StatelessWidget {
  _SurveyCard({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final sorted = [..._surveys]..sort((a, b) => b.time.compareTo(a.time));
    final recent = sorted.take(5).toList();

    return Container(
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
                Text('설문 응답', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sorted.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 2),
            child: Text(
              'QR 설문으로 들어온 응답을 사람 구분 없이 모두 보여줘요',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(height: 6),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '아직 들어온 설문이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _SurveyRow(
                survey: recent[i],
                onTap: () => _showSurveyDetail(context, recent[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 폰 설문 카드 — 피드백 카드와 같은 결
///
/// 데스크톱은 아직 [_SurveyRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _SurveyCardItem extends StatelessWidget {
  _SurveyCardItem({required this.survey, required this.onTap});

  final _Survey survey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: survey.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.name.characters.first,
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
                        survey.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatStamp(survey.time),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // 누구를 칭찬했는지 / 개선 요청만 남겼는지 한눈에
                if (survey.praised.isNotEmpty) ...[
                  SizedBox(width: 8),
                  _SurveyTag(
                    label: '칭찬 ${survey.praised}',
                    color: AppColors.primary,
                  ),
                ],
                if (survey.improve.isNotEmpty) ...[
                  SizedBox(width: 6),
                  _SurveyTag(label: '개선 요청', color: AppColors.warning),
                ],
              ],
            ),
            SizedBox(height: 14),
            Text(
              survey.motive,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설문 한 줄 — 성함 · 칭찬한 직원 · 계기 미리보기
class _SurveyRow extends StatelessWidget {
  _SurveyRow({required this.survey, required this.onTap});

  final _Survey survey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: survey.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              survey.name.characters.first,
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
                      survey.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // 누구를 칭찬했는지 / 개선 요청만 남겼는지 한눈에
                    if (survey.praised.isNotEmpty) ...[
                      SizedBox(width: 6),
                      _SurveyTag(
                        label: '칭찬 ${survey.praised}',
                        color: AppColors.primary,
                      ),
                    ],
                    if (survey.improve.isNotEmpty) ...[
                      SizedBox(width: 6),
                      _SurveyTag(label: '개선 요청', color: AppColors.warning),
                    ],
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  survey.motive,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _formatStamp(survey.time),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 설문 줄에 붙는 작은 꼬리표
class _SurveyTag extends StatelessWidget {
  _SurveyTag({required this.label, required this.color});

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

/// 설문 원본 크게 보기 — 받은 문항을 순서대로 그대로 보여준다
void _showSurveyDetail(BuildContext context, _Survey survey) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '설문 응답 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _SurveyDetailCard(survey: survey),
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

class _SurveyDetailCard extends StatelessWidget {
  _SurveyDetailCard({required this.survey});

  final _Survey survey;

  @override
  Widget build(BuildContext context) {
    // 좁은 화면에서는 화면 폭에 맞춘다
    final width = MediaQuery.sizeOf(context).width - 40;

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
                    color: survey.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.name.characters.first,
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
                        survey.name,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatStamp(survey.time),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            _SurveyField(label: '운동을 시작하게 된 계기', value: survey.motive),
            _SurveyField(label: '칭찬하고 싶은 직원', value: survey.praised),
            _SurveyField(label: '개선했으면 하는 부분', value: survey.improve),
            _SurveyField(
              label: '성함과 연락처',
              value: '${survey.name} · ${survey.phone}',
            ),
            _SurveyField(
              label: '개인정보 수집 및 이용 동의',
              value: survey.consent ? '동의함' : '동의하지 않음',
              valueColor: survey.consent ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

/// 문항 한 개 — 질문과 답변
class _SurveyField extends StatelessWidget {
  _SurveyField({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              // 안 적고 넘어간 문항은 빈 칸으로 두지 않고 그렇다고 알려준다
              value.isEmpty ? '작성하지 않음' : value,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                height: 1.5,
                color:
                    valueColor ??
                    (value.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 설문 전체 화면 — 날짜별로 묶고 아래 검색 바로 걸러 본다
class _SurveyHistoryScreen extends StatefulWidget {
  _SurveyHistoryScreen();

  @override
  State<_SurveyHistoryScreen> createState() => _SurveyHistoryScreenState();
}

class _SurveyHistoryScreenState extends State<_SurveyHistoryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${time.month}.${time.day}';
  }

  bool _matches(_Survey survey, String query) {
    if (query.isEmpty) return true;
    return survey.name.contains(query) ||
        survey.phone.contains(query) ||
        survey.motive.contains(query) ||
        survey.praised.contains(query) ||
        survey.improve.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final sorted = _surveys.where((s) => _matches(s, query)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final survey in sorted) {
      final dayLabel = _dayLabel(survey.time);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _SurveyRow(
          survey: survey,
          onTap: () => _showSurveyDetail(context, survey),
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
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QR 설문으로 들어온 응답 전체',
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
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      query.isEmpty ? '아직 들어온 설문이 없어요' : '검색 결과가 없어요',
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
                  child: Text('설문 응답', style: AppTextStyles.title3),
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
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '이름·내용 검색'),
        ],
      ),
    );
  }
}
