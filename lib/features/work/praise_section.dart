import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/see_all_button.dart';

/// 회원 친절도 탭 콘텐츠 (목업)
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
      labels: ['내게 온 칭찬', '컴플레인', '전체'],
      selected: _tab,
      onSelect: (i) => setState(() => _tab = i),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tab == 2) {
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
    final title = _complaint ? '컴플레인' : '내게 온 칭찬';
    final unresolved = _complaint && _showStatus
        ? items.where((f) => f.status == _Status.pending).length
        : 0;

    return Column(
      children: [
        _tabs(),
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
}

/// 회원이 남긴 피드백 한 건 (칭찬 또는 컴플레인)
class _Feedback {
  _Feedback({
    required this.name,
    required this.colorValue,
    required this.text,
    required this.time,
    this.complaint = false,
    this.status = _Status.pending,
  });

  final String name;
  final int colorValue;
  final String text;
  final DateTime time;
  final bool complaint;

  /// 컴플레인 처리 단계 — 상세 화면에서 바꾼다
  _Status status;

  Color get color => Color(colorValue);
}

/// 컴플레인 상태 UI는 모바일에서만 — PC는 기존 화면 그대로 둔다
bool get _showStatus => !isDesktop;

/// 받은 피드백 목록 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _feedbacks = <_Feedback>[..._seedFeedbacks()];

List<_Feedback> _seedFeedbacks() {
  final now = DateTime.now();
  // daysAgo일 전의 시각 — DateTime이 월 경계를 알아서 넘겨준다
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  return [
    _Feedback(
      name: '조은별',
      colorValue: 0xFF7C5CFC,
      text: '힘들 때 격려해주셔서 감사해요',
      time: at(0, 17, 36),
    ),
    _Feedback(
      name: '임하늘',
      colorValue: 0xFFFF9F0A,
      text: '동기부여를 잘 해주세요',
      time: at(0, 15, 12),
    ),
    _Feedback(
      name: '서민재',
      colorValue: 0xFFE0447C,
      text: '운동 자세를 꼼꼼히 봐주세요',
      time: at(1, 19, 48),
    ),
    _Feedback(
      name: '강태양',
      colorValue: 0xFF7C5CFC,
      text: '항상 웃으면서 응대해주셔서 좋아요',
      time: at(1, 11, 20),
    ),
    _Feedback(
      name: '윤아름',
      colorValue: 0xFF00C471,
      text: '정말 친절하게 알려주세요',
      time: at(2, 18, 5),
    ),
    _Feedback(
      name: '김우빈',
      colorValue: 0xFF00A8B5,
      text: '운동 원리를 쉽게 설명해주셔서 좋았습니다',
      time: at(2, 14, 35),
    ),
    _Feedback(
      name: '박도윤',
      colorValue: 0xFF3182F6,
      text: '스트레칭까지 챙겨주셔서 감동이에요',
      time: at(4, 20, 10),
    ),
    _Feedback(
      name: '이서아',
      colorValue: 0xFFE0447C,
      text: '상담이 부담스럽지 않고 편해요',
      time: at(5, 9, 40),
    ),
    _Feedback(
      name: '최지훈',
      colorValue: 0xFF3182F6,
      text: '수업 시간이 조금씩 밀리는 것 같아요',
      time: at(0, 13, 25),
      complaint: true,
    ),
    _Feedback(
      name: '한소미',
      colorValue: 0xFFFF9F0A,
      text: '기구 사용 후 정리를 부탁드리고 싶어요',
      time: at(1, 16, 40),
      complaint: true,
      status: _Status.working,
    ),
    _Feedback(
      name: '정예린',
      colorValue: 0xFF00C471,
      text: '수업 예약 변경이 어려웠어요',
      time: at(3, 10, 15),
      complaint: true,
      status: _Status.done,
    ),
  ];
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

/// 피드백 크게 보기 카드 — 컴플레인은 처리 단계를 여기서 바꾼다
class _FeedbackDetailCard extends StatefulWidget {
  _FeedbackDetailCard({required this.feedback, this.onChanged});

  final _Feedback feedback;
  final VoidCallback? onChanged;

  @override
  State<_FeedbackDetailCard> createState() => _FeedbackDetailCardState();
}

class _FeedbackDetailCardState extends State<_FeedbackDetailCard> {
  /// 같은 버튼을 다시 누르면 미처리로 되돌린다 (잘못 누른 걸 취소할 방법)
  void _pick(_Status status) {
    setState(
      () => widget.feedback.status = widget.feedback.status == status
          ? _Status.pending
          : status,
    );
    widget.onChanged?.call();
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
                    selected: feedback.status == _Status.done,
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
                  _formatStamp(feedback.time),
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

/// 들어온 설문 응답 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _surveys = <_Survey>[..._seedSurveys()];

List<_Survey> _seedSurveys() {
  final now = DateTime.now();
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  return [
    _Survey(
      name: '조은별',
      phone: '010-2841-7712',
      colorValue: 0xFF7C5CFC,
      motive: '체력이 너무 떨어져서 기초 체력부터 올리고 싶었어요',
      praised: '김은후',
      improve: '',
      time: at(0, 17, 36),
    ),
    _Survey(
      name: '임하늘',
      phone: '010-9032-1184',
      colorValue: 0xFFFF9F0A,
      motive: '건강검진에서 체중 관리가 필요하다고 들었습니다',
      praised: '김은후',
      improve: '탈의실에 드라이기가 하나 더 있으면 좋겠어요',
      time: at(0, 15, 12),
    ),
    _Survey(
      name: '최지훈',
      phone: '010-3377-2098',
      colorValue: 0xFF3182F6,
      motive: '재활 목적으로 시작했어요',
      praised: '',
      improve: '수업 시간이 조금씩 밀리는 것 같아요',
      time: at(0, 13, 25),
    ),
    _Survey(
      name: '서민재',
      phone: '010-4410-6623',
      colorValue: 0xFFE0447C,
      motive: '자세 교정이 필요해서 왔습니다',
      praised: '김은후',
      improve: '',
      time: at(1, 19, 48),
    ),
    _Survey(
      name: '한소미',
      phone: '010-8825-3391',
      colorValue: 0xFFFF9F0A,
      motive: '친구 소개로 등록했어요',
      praised: '민중기',
      improve: '기구 사용 후 정리를 부탁드리고 싶어요',
      time: at(1, 16, 40),
    ),
    _Survey(
      name: '강태양',
      phone: '010-5518-7734',
      colorValue: 0xFF7C5CFC,
      motive: '앉아서 일하다 보니 허리가 아파서요',
      praised: '김은후',
      improve: '',
      time: at(1, 11, 20),
    ),
    _Survey(
      name: '윤아름',
      phone: '010-6642-0087',
      colorValue: 0xFF00C471,
      motive: '결혼 준비로 체형 관리를 시작했습니다',
      praised: '김은후',
      improve: '',
      time: at(2, 18, 5),
    ),
    _Survey(
      name: '김우빈',
      phone: '010-7719-4406',
      colorValue: 0xFF00A8B5,
      motive: '근력을 키우고 싶어서 등록했어요',
      praised: '박준현',
      improve: '',
      time: at(2, 14, 35),
      consent: false,
    ),
    _Survey(
      name: '정예린',
      phone: '010-2263-9915',
      colorValue: 0xFF00C471,
      motive: '스트레스를 풀 운동을 찾고 있었어요',
      praised: '',
      improve: '수업 예약 변경이 어려웠어요',
      time: at(3, 10, 15),
    ),
    _Survey(
      name: '박도윤',
      phone: '010-9908-5541',
      colorValue: 0xFF3182F6,
      motive: '헬스는 처음이라 배우면서 하려고요',
      praised: '유찬빈',
      improve: '',
      time: at(4, 20, 10),
    ),
    _Survey(
      name: '이서아',
      phone: '010-3384-2276',
      colorValue: 0xFFE0447C,
      motive: '출산 후 체력 회복이 목표예요',
      praised: '전상현',
      improve: '',
      time: at(5, 9, 40),
    ),
  ];
}

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
