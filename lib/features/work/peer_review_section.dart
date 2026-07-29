import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/pressable.dart';

/// 동료 평가 탭 콘텐츠 (목업)
///
/// - 평가 작성: 대상(본인/동료)을 고르고 5개 항목에 점수와 사유를 적는다.
///   본인은 항목당 최대 5점, 동료는 항목당 최대 20점.
/// - 평가 현황: 직원별 항목 점수·총합과 항목별 순위를 보여준다.
class PeerReviewSection extends StatefulWidget {
  PeerReviewSection({super.key});

  @override
  State<PeerReviewSection> createState() => _PeerReviewSectionState();
}

class _PeerReviewSectionState extends State<PeerReviewSection> {
  static const _self = '나';
  static const _me = '김은후';

  static const _categories = ['업무 역량', '협업 소통', '성과 기여도', '태도·규정 준수', '리더십'];

  static const _members = ['이앨리스', '오민준', '신유나', '권지호'];

  /// 직원별 항목 점수 (항목당 20점, 총 100점 만점 목업)
  static const _results = [
    _PeerScore('이앨리스', [18, 17, 16, 19, 15]),
    _PeerScore(_me, [17, 18, 15, 18, 14]),
    _PeerScore('오민준', [15, 19, 14, 17, 12]),
    _PeerScore('신유나', [16, 14, 17, 16, 13]),
    _PeerScore('권지호', [13, 15, 12, 18, 11]),
  ];

  /// 평가 대상 — 본인이면 항목당 5점, 동료면 20점
  String _target = _self;

  final Map<String, int> _scores = {};

  late final Map<String, TextEditingController> _reasons = {
    for (final category in _categories) category: TextEditingController(),
  };

  /// 현황 순위 기준 — 0이면 총합, 1부터는 항목 순서
  int _metric = 0;

  int get _maxScore => _target == _self ? 5 : 20;

  @override
  void dispose() {
    for (final controller in _reasons.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setTarget(String name) {
    if (_target == name) return;
    setState(() {
      _target = name;
      _scores.clear();
      for (final controller in _reasons.values) {
        controller.clear();
      }
    });
  }

  void _adjust(String category, int delta) {
    final next = ((_scores[category] ?? 0) + delta).clamp(0, _maxScore);
    setState(() => _scores[category] = next);
  }

  void _submit() {
    final total = _scores.values.fold(0, (sum, v) => sum + v);
    if (total == 0) {
      AppToast.show(context, '점수를 먼저 입력해주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    AppToast.show(
      context,
      _target == _self ? '내 평가를 제출했습니다' : '$_target님 평가를 제출했습니다',
    );
    setState(() {
      _scores.clear();
      for (final controller in _reasons.values) {
        controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildFormCard(), SizedBox(height: 16), _buildRankingCard()],
    );
  }

  Widget _buildFormCard() {
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
                Text(
                  '항목당 최대 $_maxScore점',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // 평가 대상 선택 칩 — 본인(나) 또는 동료
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in [_self, ..._members])
                _TargetChip(
                  label: name,
                  selected: _target == name,
                  onTap: () => _setTarget(name),
                ),
            ],
          ),
          SizedBox(height: 18),
          for (final category in _categories) ...[
            _ScoreRow(
              label: category,
              score: _scores[category] ?? 0,
              maxScore: _maxScore,
              onAdjust: (delta) => _adjust(category, delta),
            ),
            SizedBox(height: 8),
            // 왜 이 점수인지 사유를 적는 칸
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            SizedBox(height: 14),
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
                  _TargetChip(
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

/// 평가 대상·순위 기준 선택 칩
class _TargetChip extends StatelessWidget {
  _TargetChip({
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
