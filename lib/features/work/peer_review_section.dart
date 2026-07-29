import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';

/// 동료 평가 탭 콘텐츠 (목업)
///
/// - 평가 작성: 사람 카드를 눌러 평가 화면으로 이동한다.
///   본인은 항목당 최대 5점, 동료는 항목당 최대 20점.
/// - 평가 현황: 직원별 항목 점수·총합과 항목별 순위를 보여준다.
class PeerReviewSection extends StatefulWidget {
  PeerReviewSection({super.key});

  @override
  State<PeerReviewSection> createState() => _PeerReviewSectionState();
}

const _categories = ['업무 역량', '협업 소통', '성과 기여도', '태도·규정 준수', '리더십'];

const _me = '김은후';

/// 평가 대상 목록 — 본인 카드가 맨 앞. 아바타 색은 사내톡 멤버 목록과 동일.
const _persons = [
  _Person(_me, '본인 평가', AppColors.primary, isSelf: true),
  _Person('이앨리스', '디자인팀 · 리드', AppColors.success),
  _Person('오민준', '개발팀 · 대리', Color(0xFF00A8B5)),
  _Person('신유나', '디자인팀 · 대리', Color(0xFF7C5CFC)),
  _Person('권지호', '영업팀 · 사원', Color(0xFFE0447C)),
];

class _PeerReviewSectionState extends State<PeerReviewSection> {
  /// 직원별 항목 점수 (항목당 20점, 총 100점 만점 목업)
  static const _results = [
    _PeerScore('이앨리스', [18, 17, 16, 19, 15]),
    _PeerScore(_me, [17, 18, 15, 18, 14]),
    _PeerScore('오민준', [15, 19, 14, 17, 12]),
    _PeerScore('신유나', [16, 14, 17, 16, 13]),
    _PeerScore('권지호', [13, 15, 12, 18, 11]),
  ];

  /// 현황 순위 기준 — 0이면 총합, 1부터는 항목 순서
  int _metric = 0;

  void _openForm(_Person person) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _PeerReviewFormScreen(person: person)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildPeopleCard(), SizedBox(height: 16), _buildRankingCard()],
    );
  }

  Widget _buildPeopleCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('평가 작성', style: AppTextStyles.label)),
                Text('평가할 사람을 선택하세요', style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(height: 14),
          for (var i = 0; i < _persons.length; i += 2) ...[
            if (i > 0) SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PersonTile(
                    person: _persons[i],
                    onTap: () => _openForm(_persons[i]),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: i + 1 < _persons.length
                      ? _PersonTile(
                          person: _persons[i + 1],
                          onTap: () => _openForm(_persons[i + 1]),
                        )
                      : SizedBox(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingCard() {
    final metrics = ['총합', ..._categories];
    final sorted = List.of(_results)
      ..sort((a, b) => b.valueOf(_metric).compareTo(a.valueOf(_metric)));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('평가 현황', style: AppTextStyles.label)),
                Text(
                  _metric == 0 ? '총 100점 만점' : '항목당 20점 만점',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // 순위 기준 선택 — 총합 또는 세부 항목
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0) SizedBox(width: 8),
                  _MetricChip(
                    label: metrics[i],
                    selected: _metric == i,
                    onTap: () => setState(() => _metric = i),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 8),
          for (var rank = 0; rank < sorted.length; rank++) ...[
            if (rank > 0) Divider(height: 1, color: AppColors.divider),
            _RankRow(
              rank: rank + 1,
              entry: sorted[rank],
              value: sorted[rank].valueOf(_metric),
              isMe: sorted[rank].name == _me,
            ),
          ],
        ],
      ),
    );
  }
}

/// 평가 대상 한 명
class _Person {
  const _Person(this.name, this.caption, this.color, {this.isSelf = false});

  final String name;

  /// 카드에 보여줄 소속·직책 (본인은 '본인 평가')
  final String caption;
  final Color color;
  final bool isSelf;

  int get maxScore => isSelf ? 5 : 20;
}

/// 직원 한 명의 항목별 점수
class _PeerScore {
  const _PeerScore(this.name, this.scores);

  final String name;

  /// 항목 순서대로 5개 (항목당 20점)
  final List<int> scores;

  int get total => scores.fold(0, (sum, v) => sum + v);

  /// metric 0은 총합, 1부터는 항목 인덱스
  int valueOf(int metric) => metric == 0 ? total : scores[metric - 1];
}

/// 사람 선택 카드 — 아바타·이름·소속. 본인 카드는 파란 배경으로 구분.
class _PersonTile extends StatelessWidget {
  _PersonTile({required this.person, required this.onTap});

  final _Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: person.isSelf ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: person.isSelf
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: person.color,
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
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    person.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: person.isSelf
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 순위 기준 선택 칩
class _MetricChip extends StatelessWidget {
  _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontSize: 13,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 순위 한 줄 — 등수, 이름, 점수. 내 줄은 파란 배경으로 강조.
class _RankRow extends StatelessWidget {
  _RankRow({
    required this.rank,
    required this.entry,
    required this.value,
    required this.isMe,
  });

  final int rank;
  final _PeerScore entry;
  final int value;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: AppTextStyles.body2.copyWith(
                color: rank == 1 ? AppColors.primary : AppColors.gray400,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  entry.name,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ),
          Text(
            '$value점',
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 평가 작성 화면 — 사람 카드를 누르면 옆에서 슬라이드되어 열린다.
/// 5개 항목에 점수(본인 5점/동료 20점)와 사유를 적고 제출한다.
class _PeerReviewFormScreen extends StatefulWidget {
  _PeerReviewFormScreen({required this.person});

  final _Person person;

  @override
  State<_PeerReviewFormScreen> createState() => _PeerReviewFormScreenState();
}

class _PeerReviewFormScreenState extends State<_PeerReviewFormScreen> {
  final Map<String, int> _scores = {};

  late final Map<String, TextEditingController> _reasons = {
    for (final category in _categories) category: TextEditingController(),
  };

  int get _max => widget.person.maxScore;

  int get _total => _scores.values.fold(0, (sum, v) => sum + v);

  @override
  void dispose() {
    for (final controller in _reasons.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _adjust(String category, int delta) {
    final next = ((_scores[category] ?? 0) + delta).clamp(0, _max);
    setState(() => _scores[category] = next);
  }

  void _submit() {
    if (_total == 0) {
      AppToast.show(context, '점수를 먼저 입력해주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    AppToast.show(
      context,
      widget.person.isSelf
          ? '내 평가를 제출했습니다'
          : '${widget.person.name}님 평가를 제출했습니다',
    );
    Navigator.pop(context);
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
                          person.caption,
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 $_total / ${_max * _categories.length}점',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    children: [
                      for (final category in _categories) ...[
                        _ScoreRow(
                          label: category,
                          score: _scores[category] ?? 0,
                          maxScore: _max,
                          onAdjust: (delta) => _adjust(category, delta),
                        ),
                        SizedBox(height: 8),
                        // 왜 이 점수인지 사유를 적는 칸
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _reasons[category],
                            style: AppTextStyles.body2,
                            cursorColor: AppColors.primary,
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
                      SizedBox(height: 4),
                      Pressable(
                        onTap: _submit,
                        scale: 0.97,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '평가 제출',
                            style: AppTextStyles.body1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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
                    person.isSelf ? '내 평가' : '${person.name} 평가',
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
        ],
      ),
    );
  }
}

/// 항목 라벨 + −/+ 점수 스테퍼 줄
class _ScoreRow extends StatelessWidget {
  _ScoreRow({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.onAdjust,
  });

  final String label;
  final int score;
  final int maxScore;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final active = score > 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _StepButton(
          icon: CupertinoIcons.minus,
          color: active ? AppColors.error : AppColors.gray300,
          onTap: () => onAdjust(-1),
        ),
        SizedBox(
          width: 58,
          child: Center(
            child: Text.rich(
              TextSpan(
                text: '$score',
                style: AppTextStyles.body2.copyWith(
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' / $maxScore',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StepButton(
          icon: CupertinoIcons.plus,
          color: score < maxScore ? AppColors.primary : AppColors.gray300,
          onTap: () => onAdjust(1),
        ),
      ],
    );
  }
}

/// 점수 스테퍼 버튼 — 누르는 동안 원이 줄어들며 버튼 색으로 물든다
class _StepButton extends StatefulWidget {
  _StepButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: 38,
        height: 40,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.82 : 1.0,
            duration: Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 110),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.18)
                    : AppColors.gray50,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 13, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
