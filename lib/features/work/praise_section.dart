import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';

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
  /// true면 컴플레인 탭
  bool _complaint = false;

  void _openHistory() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _FeedbackHistoryScreen(complaint: _complaint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _feedbacks.where((f) => f.complaint == _complaint).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    // 카드에는 최근 5건만 — 나머지는 전체 보기 화면에서
    final recent = items.take(5).toList();
    final title = _complaint ? '컴플레인' : '내게 온 칭찬';

    return Column(
      children: [
        ModeSwitch(
          left: '내게 온 칭찬',
          right: '컴플레인',
          value: _complaint,
          onChanged: (v) => setState(() => _complaint = v),
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
                    Text(title, style: AppTextStyles.label),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${items.length}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: _openHistory,
                      scale: 0.92,
                      pressedColor: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '전체 보기',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 11,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
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
                    onTap: () => _showFeedbackDetail(context, recent[i]),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 회원이 남긴 피드백 한 건 (칭찬 또는 컴플레인)
class _Feedback {
  const _Feedback({
    required this.name,
    required this.colorValue,
    required this.text,
    required this.time,
    this.complaint = false,
  });

  final String name;
  final int colorValue;
  final String text;
  final DateTime time;
  final bool complaint;

  Color get color => Color(colorValue);
}

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
    ),
    _Feedback(
      name: '정예린',
      colorValue: 0xFF00C471,
      text: '수업 예약 변경이 어려웠어요',
      time: at(3, 10, 15),
      complaint: true,
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

/// 피드백 줄을 누르면 전체 내용을 크게 보여준다
void _showFeedbackDetail(BuildContext context, _Feedback feedback) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '피드백 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
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
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                feedback.text,
                textAlign: TextAlign.center,
                style: AppTextStyles.body2.copyWith(height: 1.5),
              ),
              SizedBox(height: 12),
              Text(_formatStamp(feedback.time), style: AppTextStyles.caption),
            ],
          ),
        ),
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
                Text(
                  feedback.name,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
          onTap: () => _showFeedbackDetail(context, feedback),
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
                          widget.complaint ? '받은 컴플레인 기록' : '받은 칭찬 기록',
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
