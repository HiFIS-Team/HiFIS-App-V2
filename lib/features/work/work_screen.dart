import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/pressable.dart';

/// 업무 탭 화면 (목업)
///
/// 5개 평가 항목을 밑줄 탭으로 전환하며 항목별 점수와 상세를 보여준다.
/// 데이터는 하드코딩된 샘플이며, 평가 기능 연동 시 실제 데이터로 교체한다.
class WorkScreen extends StatefulWidget {
  WorkScreen({super.key});

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  int _tab = 0;

  /// 환경정비 항목별 오늘 수행 횟수 (목업 초기값)
  final Map<String, int> _counts = {'세탁': 2, '건조기': 1, '복도청소': 1};

  void _adjust(String task, int delta) {
    setState(() {
      final next = (_counts[task] ?? 0) + delta;
      if (next <= 0) {
        _counts.remove(task);
      } else {
        _counts[task] = next;
      }
    });
  }

  static const _items = [
    _WorkItem(
      label: '환경정비',
      score: 92,
      unit: '점',
      delta: 3,
      comment: '담당 구역 점검을 꾸준히 잘 지키고 있어요',
      rows: [],
      checklist: [
        '세탁',
        '건조기',
        '빨래 정리',
        '구역청소',
        '복도청소',
        '락커정리',
        '남탈부스',
        '남탈청소',
        '여탈부스',
        '여탈청소',
        '화장실청소',
        '기구관리',
        '회원지도',
        'TM 회원관리',
        '게시물',
        '스토리',
        '전단지',
        '현수막',
        '족자',
        '블로그',
        '클레임해결',
        '기타',
      ],
    ),
    _WorkItem(
      label: '동료 평가',
      score: 88,
      unit: '점',
      delta: 2,
      comment: '협업 항목에서 좋은 평가를 받았어요',
      rows: [('받은 평가', '14건'), ('평균 별점', '4.4 / 5'), ('최고 항목', '협업')],
    ),
    _WorkItem(
      label: '회원 친절도',
      score: 96,
      unit: '점',
      delta: 5,
      comment: '회원 리뷰 평점이 센터 상위 10%예요',
      rows: [('회원 리뷰', '32건'), ('평균 별점', '4.8 / 5'), ('재등록률', '81%')],
    ),
    _WorkItem(
      label: '수업 개수',
      score: 46,
      unit: '회',
      delta: 4,
      comment: '이번 달 목표(50회)까지 4회 남았어요',
      rows: [('PT 수업', '38회'), ('GX 수업', '8회'), ('노쇼', '2회')],
    ),
    _WorkItem(
      label: '센터 기여도',
      score: 84,
      unit: '점',
      delta: -2,
      comment: '지난달보다 이벤트 참여가 줄었어요',
      rows: [('대타 지원', '3회'), ('이벤트 참여', '2회'), ('신규 상담', '6건')],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_tab];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 64, 0, 110),
          children: [
            // 항목 탭 — 사내톡 상세 '공유된 콘텐츠' 탭과 같은 밑줄 스타일.
            // 5개가 화면 폭에 딱 맞게 균등 분할된다.
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _WorkTab(
                      label: _items[i].label,
                      selected: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 20),
            // 탭 전환 시 콘텐츠 페이드.
            // 체크리스트 탭(환경정비)은 점수 카드 없이 리스트만 보여준다.
            AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(_tab),
                children: [
                  if (item.checklist != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _ChecklistCard(
                        items: item.checklist!,
                        counts: _counts,
                        onAdjust: _adjust,
                      ),
                    )
                  else ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _ScoreCard(item: item),
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _DetailCard(item: item),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkItem {
  const _WorkItem({
    required this.label,
    required this.score,
    required this.unit,
    required this.delta,
    required this.comment,
    required this.rows,
    this.checklist,
  });

  final String label;
  final int score;
  final String unit;

  /// 전월 대비 변화 (음수면 하락)
  final int delta;
  final String comment;
  final List<(String, String)> rows;

  /// 2열 점검 체크리스트 (있으면 상세 카드 대신 표시)
  final List<String>? checklist;
}

class _WorkTab extends StatelessWidget {
  _WorkTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: AppTextStyles.body2.copyWith(
              fontSize: 14,
              color: selected ? AppColors.textPrimary : AppColors.gray500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 이번 달 점수 요약 카드
class _ScoreCard extends StatelessWidget {
  _ScoreCard({required this.item});

  final _WorkItem item;

  @override
  Widget build(BuildContext context) {
    final up = item.delta >= 0;
    final deltaColor = up ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번 달 ${item.label}', style: AppTextStyles.label),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.score}${item.unit}',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 10),
              // 전월 대비 변화 배지
              Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(
                      up
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 11,
                      color: deltaColor,
                    ),
                    SizedBox(width: 2),
                    Text(
                      '${item.delta.abs()}',
                      style: AppTextStyles.caption.copyWith(
                        color: deltaColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(item.comment, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// 환경정비 점검 카드 — 항목이 2열로 내려가며 배치되고,
/// 각 항목의 좌우 −/+ 버튼으로 오늘 수행 횟수를 조절한다.
class _ChecklistCard extends StatelessWidget {
  _ChecklistCard({
    required this.items,
    required this.counts,
    required this.onAdjust,
  });

  final List<String> items;
  final Map<String, int> counts;

  /// (항목, 증감량) — +1 또는 -1
  final void Function(String task, int delta) onAdjust;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, c) => sum + c);

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
                Expanded(child: Text('오늘 점검 항목', style: AppTextStyles.label)),
                Text(
                  '총 $total회',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CountChip(
                    label: items[i],
                    count: counts[items[i]] ?? 0,
                    onAdjust: (delta) => onAdjust(items[i], delta),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: i + 1 < items.length
                      ? _CountChip(
                          label: items[i + 1],
                          count: counts[items[i + 1]] ?? 0,
                          onAdjust: (delta) => onAdjust(items[i + 1], delta),
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
}

/// 좌 − / 우 + 버튼이 달린 횟수 칩
class _CountChip extends StatelessWidget {
  _CountChip({
    required this.label,
    required this.count,
    required this.onAdjust,
  });

  final String label;
  final int count;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 48,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _AdjustButton(
            // 감소는 빨강, 횟수가 없으면 비활성 회색
            icon: CupertinoIcons.minus,
            color: active ? AppColors.error : AppColors.gray300,
            onTap: () => onAdjust(-1),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (active) ...[
                    SizedBox(width: 5),
                    Text(
                      '$count',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _AdjustButton(
            icon: CupertinoIcons.plus,
            color: AppColors.primary,
            onTap: () => onAdjust(1),
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  _AdjustButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.8,
      child: SizedBox(
        width: 38,
        height: 48,
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

/// 항목별 상세 카드
class _DetailCard extends StatelessWidget {
  _DetailCard({required this.item});

  final _WorkItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          for (var i = 0; i < item.rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.rows[i].$1, style: AppTextStyles.body2),
                  ),
                  Text(
                    item.rows[i].$2,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
