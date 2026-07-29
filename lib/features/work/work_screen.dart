import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
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

  static const _me = '김은후';

  /// 환경정비 오늘 수행 로그 — 횟수는 이 로그에서 집계한다 (목업 초기값 포함)
  late final List<_WorkLog> _logs = _seedLogs();

  /// 다른 직원들의 오늘 수행 기록 (목업, 전체 내역 탭에서만 사용)
  late final List<_WorkLog> _teamLogs = _seedTeamLogs();

  static List<_WorkLog> _seedLogs() {
    final now = DateTime.now();
    DateTime at(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    return [
      _WorkLog(name: _me, task: '세탁', time: at(8, 40)),
      _WorkLog(name: _me, task: '건조기', time: at(9, 15)),
      _WorkLog(name: _me, task: '복도청소', time: at(10, 5)),
      _WorkLog(name: _me, task: '세탁', time: at(11, 30)),
    ];
  }

  static List<_WorkLog> _seedTeamLogs() {
    final now = DateTime.now();
    DateTime at(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    return [
      _WorkLog(name: '이앨리스', task: '구역청소', time: at(8, 20)),
      _WorkLog(name: '오민준', task: '기구관리', time: at(8, 55)),
      _WorkLog(name: '신유나', task: '게시물', time: at(9, 40)),
      _WorkLog(name: '권지호', task: '화장실청소', time: at(10, 25)),
      _WorkLog(name: '이앨리스', task: '세탁', time: at(10, 50)),
      _WorkLog(name: '오민준', task: '클레임해결', time: at(11, 45)),
    ];
  }

  Map<String, int> get _counts {
    final counts = <String, int>{};
    for (final log in _logs) {
      counts[log.task] = (counts[log.task] ?? 0) + 1;
    }
    return counts;
  }

  void _adjust(String task, int delta) {
    setState(() {
      if (delta > 0) {
        _logs.add(_WorkLog(name: _me, task: task, time: DateTime.now()));
      } else {
        // 감소는 해당 항목의 가장 최근 기록을 지운다
        final index = _logs.lastIndexWhere((log) => log.task == task);
        if (index >= 0) _logs.removeAt(index);
      }
    });
    if (delta > 0) AppToast.show(context, '${_withJosa(task)} 완료했습니다');
  }

  void _showHistory() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _HistoryScreen(
          myLogs: List.of(_logs),
          allLogs: [..._logs, ..._teamLogs],
        ),
      ),
    );
  }

  /// 받침 유무에 따라 을/를을 붙인다 (한글이 아니면 을(를))
  String _withJosa(String word) {
    final code = word.codeUnits.last;
    if (code < 0xAC00 || code > 0xD7A3) return '$word을(를)';
    return (code - 0xAC00) % 28 != 0 ? '$word을' : '$word를';
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
        child: Column(
          children: [
            // 상단 글래스 헤더 버튼 영역만큼 비워둔다
            SizedBox(height: 64),
            // 항목 탭 — 사내톡 상세 '공유된 콘텐츠' 탭과 같은 밑줄 스타일.
            // 스크롤과 무관하게 고정되고, 좌우 여백으로 가장자리와 띄운다.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
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
            ),
            Container(height: 1, color: AppColors.gray100),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 110),
                children: [
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
                              onShowHistory: _showHistory,
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
          ],
        ),
      ),
    );
  }
}

/// 환경정비 수행 기록 한 건
class _WorkLog {
  _WorkLog({required this.name, required this.task, required this.time});

  final String name;
  final String task;
  final DateTime time;
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
          // 칸보다 긴 라벨은 살짝 줄여서 옆 칸·가장자리를 침범하지 않게 한다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: selected ? AppColors.textPrimary : AppColors.gray500,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
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
    required this.onShowHistory,
  });

  final List<String> items;
  final Map<String, int> counts;

  /// (항목, 증감량) — +1 또는 -1
  final void Function(String task, int delta) onAdjust;

  /// 오늘 내역 시트 열기
  final VoidCallback onShowHistory;

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
                // 누르면 오늘 수행 내역 시트가 열린다
                Pressable(
                  onTap: onShowHistory,
                  scale: 0.92,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(100),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '총 $total회',
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
        // 활성 칩에만 은은한 파란 테두리
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
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

/// 스테퍼 버튼 — 누르는 동안 원이 줄어들며 버튼 색으로 물든다
class _AdjustButton extends StatefulWidget {
  _AdjustButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AdjustButton> createState() => _AdjustButtonState();
}

class _AdjustButtonState extends State<_AdjustButton> {
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
        width: 42,
        height: 48,
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
                    : AppColors.surface,
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

/// 오늘 수행 내역 화면 — 옆에서 슬라이드되어 열리고,
/// 내 내역/전체 내역 탭을 전환하며 최근 기록이 위로 오도록 보여준다
class _HistoryScreen extends StatefulWidget {
  _HistoryScreen({required this.myLogs, required this.allLogs});

  final List<_WorkLog> myLogs;
  final List<_WorkLog> allLogs;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  /// true면 전체 내역 탭
  bool _all = false;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatTime(DateTime time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}요일';
    final logs = _all ? widget.allLogs : widget.myLogs;
    final sorted = List.of(logs)..sort((a, b) => b.time.compareTo(a.time));

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
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(date, style: AppTextStyles.caption)),
                      Text(
                        '총 ${logs.length}회',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // 내 내역 / 전체 내역 전환 탭 (업무 탭과 같은 밑줄 스타일)
                Row(
                  children: [
                    Expanded(
                      child: _WorkTab(
                        label: '내 내역',
                        selected: !_all,
                        onTap: () => setState(() => _all = false),
                      ),
                    ),
                    Expanded(
                      child: _WorkTab(
                        label: '전체 내역',
                        selected: _all,
                        onTap: () => setState(() => _all = true),
                      ),
                    ),
                  ],
                ),
                Container(height: 1, color: AppColors.gray100),
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      _all ? '오늘 완료된 항목이 없어요' : '오늘 완료한 항목이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      key: ValueKey(_all),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        12,
                        24,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, index) {
                        final log = sorted[index];
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  _formatTime(log.time),
                                  style: AppTextStyles.caption,
                                ),
                              ),
                              SizedBox(width: 8),
                              // 전체 내역에서는 누가 했는지 이름을 함께 보여준다
                              if (_all) ...[
                                Text(
                                  log.name,
                                  style: AppTextStyles.body2.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.task,
                                    style: AppTextStyles.body2.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ] else
                                Expanded(
                                  child: Text(
                                    log.task,
                                    style: AppTextStyles.body2.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 16,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        );
                      },
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
                  child: Text('오늘 내역', style: AppTextStyles.title3),
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
