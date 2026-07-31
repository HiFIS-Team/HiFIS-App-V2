import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/see_all_button.dart';

/// 센터 기여도 탭 콘텐츠 (목업)
///
/// 네 가지가 이번 달 기여 점수로 쌓인다.
/// - **창의적 아이디어 · 자발적 목표 업무**: 마스터~매니저가 보고 직접 준다
/// - **근무 외 출근 · 매출 성과**: 기록에서 자동으로 들어온다
///
/// 그래서 화면도 둘을 갈라 보여준다. 자동 항목은 왜 이 점수인지 근거를 적고,
/// 부여 항목은 누가 줬는지를 남긴다.
class ContributionSection extends StatefulWidget {
  ContributionSection({super.key});

  @override
  State<ContributionSection> createState() => _ContributionSectionState();
}

class _ContributionSectionState extends State<ContributionSection> {
  /// 기여 점수 주기 — 권한이 있는 사람만 보인다
  Future<void> _grant() async {
    final granted = await showFullPage<bool>(context, (_) => _GrantScreen());
    if (granted == true && mounted) setState(() {});
  }

  void _openHistory() {
    showFullPage<void>(context, (_) => _ContributionHistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    final mine = _minesThisMonth();
    final recent = List.of(mine)..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        _ScoreCard(items: mine),
        SizedBox(height: 16),
        // 항목 넷 — 무엇으로 점수가 쌓였는지
        _KindGrid(items: mine),
        if (myPermission.canGrant) ...[
          SizedBox(height: 16),
          _GrantBanner(onTap: _grant),
        ],
        SizedBox(height: 16),
        _HistoryCard(
          items: recent.take(5).toList(),
          total: recent.length,
          onOpenAll: _openHistory,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 모델
// ---------------------------------------------------------------------------

/// 기여 항목 네 가지
enum _Kind {
  idea('창의적 아이디어', CupertinoIcons.lightbulb_fill),
  goal('자발적 목표 업무', CupertinoIcons.flag_fill),
  extra('근무 외 출근', CupertinoIcons.clock_fill),
  sales('매출 성과', CupertinoIcons.chart_bar_fill);

  const _Kind(this.label, this.icon);

  final String label;
  final IconData icon;

  /// 마스터~매니저가 보고 직접 주는 항목인지.
  /// 나머지 둘은 근태·매출 기록에서 자동으로 들어온다.
  bool get granted => this == _Kind.idea || this == _Kind.goal;

  Color get color => switch (this) {
    _Kind.idea => AppColors.warning,
    _Kind.goal => AppColors.primary,
    _Kind.extra => AppColors.success,
    _Kind.sales => Color(0xFF7C5CFC),
  };
}

/// 기여 한 건
class _Contribution {
  const _Contribution({
    required this.name,
    required this.kind,
    required this.title,
    required this.points,
    required this.date,
    this.by,
  });

  /// 점수를 받은 사람
  final String name;

  final _Kind kind;

  /// 무엇으로 받았는지 (자동 항목은 집계 근거가 들어간다)
  final String title;
  final int points;
  final DateTime date;

  /// 준 사람 — 부여 항목만 채운다
  final String? by;
}

/// 부여할 때 고를 수 있는 점수
const _pointOptions = [5, 10, 15, 20];

/// 이번 달 기여 기록 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _contributions = <_Contribution>[..._seed()];

List<_Contribution> _seed() {
  final now = DateTime.now();
  DateTime at(int day) => DateTime(now.year, now.month, day);
  return [
    _Contribution(
      name: me,
      kind: _Kind.idea,
      title: '락커 회전율 안내 문구 제안',
      points: 15,
      date: at(4),
      by: '이준승',
    ),
    _Contribution(
      name: me,
      kind: _Kind.goal,
      title: '신규 회원 온보딩 문서 정리',
      points: 20,
      date: at(11),
      by: '민중기',
    ),
    _Contribution(
      name: me,
      kind: _Kind.extra,
      title: '휴무일 대타 근무 2회',
      points: 10,
      date: at(16),
    ),
    _Contribution(
      name: me,
      kind: _Kind.sales,
      title: '월 목표 대비 118% 달성',
      points: 18,
      date: at(22),
    ),
    _Contribution(
      name: me,
      kind: _Kind.extra,
      title: '오픈 준비 조기 출근 3회',
      points: 6,
      date: at(25),
    ),
    _Contribution(
      name: '박준현',
      kind: _Kind.idea,
      title: 'GX 시간표 개편 제안',
      points: 10,
      date: at(9),
      by: '이준승',
    ),
  ];
}

/// 로그인한 사람의 이번 달 기록
List<_Contribution> _minesThisMonth() {
  final now = DateTime.now();
  return _contributions
      .where(
        (c) =>
            c.name == me &&
            c.date.year == now.year &&
            c.date.month == now.month,
      )
      .toList();
}

int _sum(List<_Contribution> items) =>
    items.fold(0, (total, c) => total + c.points);

/// '7월 4일'
String _dayLabel(DateTime date) => '${date.month}월 ${date.day}일';

// ---------------------------------------------------------------------------
// 점수 요약
// ---------------------------------------------------------------------------

/// 이번 달 기여 점수 — 총점과 부여/자동 비중
class _ScoreCard extends StatelessWidget {
  _ScoreCard({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final total = _sum(items);
    final granted = _sum(items.where((c) => c.kind.granted).toList());
    final auto = total - granted;

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
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 기여 점수',
                  style: AppTextStyles.label,
                ),
              ),
              Text(
                '$total',
                style: AppTextStyles.title1.copyWith(
                  fontSize: 28,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.body2.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 14),
          // 받은 점수와 자동으로 쌓인 점수의 비중
          ProgressBar(ratio: total == 0 ? 0 : granted / total),
          SizedBox(height: 12),
          Row(
            children: [
              _legend(AppColors.primary, '부여받은 점수', granted),
              SizedBox(width: 16),
              _legend(AppColors.gray300, '자동 집계', auto),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, int points) => Row(
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
        '$points점',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 항목 네 칸 — 무엇으로 몇 점이 쌓였는지
class _KindGrid extends StatelessWidget {
  _KindGrid({required this.items});

  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    // 데스크톱은 한 줄에 넷, 폰은 2×2
    final columns = isDesktop ? 4 : 2;
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in _Kind.values)
              SizedBox(
                width: width,
                child: _KindCard(
                  kind: kind,
                  items: items.where((c) => c.kind == kind).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KindCard extends StatelessWidget {
  _KindCard({required this.kind, required this.items});

  final _Kind kind;
  final List<_Contribution> items;

  @override
  Widget build(BuildContext context) {
    final points = _sum(items);
    final empty = items.isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kind.icon, size: 15, color: kind.color),
              ),
              Spacer(),
              // 이 항목이 어떻게 들어오는지 — 부여인지 자동인지
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kind.granted ? '부여' : '자동',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            kind.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$points',
                style: AppTextStyles.title2.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textPrimary,
                ),
              ),
              Text(
                '점',
                style: AppTextStyles.caption.copyWith(
                  color: empty ? AppColors.gray300 : AppColors.textSecondary,
                ),
              ),
              Spacer(),
              Text(
                empty ? '없음' : '${items.length}건',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 부여 권한이 있는 사람에게만 보이는 줄
class _GrantBanner extends StatelessWidget {
  _GrantBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.plus_circle_fill,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기여 점수 주기',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '창의적 아이디어 · 자발적 목표 업무를 직접 챙겨 주세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 내역
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  _HistoryCard({
    required this.items,
    required this.total,
    required this.onOpenAll,
  });

  final List<_Contribution> items;
  final int total;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
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
                Text('기여 내역', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$total',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '이번 달 기여 기록이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _ContributionRow(item: items[i]),
            ],
        ],
      ),
    );
  }
}

/// 기여 한 줄 — 항목 아이콘, 내용, 준 사람, 점수
class _ContributionRow extends StatelessWidget {
  _ContributionRow({required this.item});

  final _Contribution item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.kind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.kind.icon, size: 15, color: item.kind.color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  // 부여 항목은 누가 줬는지가 근거다
                  item.by == null
                      ? '${item.kind.label} · ${_dayLabel(item.date)}'
                      : '${item.kind.label} · ${item.by}님 · '
                            '${_dayLabel(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '+${item.points}',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 내역 전체 화면 — 내 것과 지점 전체를 나눠 본다
class _ContributionHistoryScreen extends StatelessWidget {
  _ContributionHistoryScreen();

  @override
  Widget build(BuildContext context) {
    final mine = List.of(_contributions.where((c) => c.name == me))
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 68, 24, 32),
              children: [
                if (mine.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                    child: Text(
                      '기여 기록이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider),
                    _ContributionRow(item: mine[i]),
                  ],
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 내역', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
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

// ---------------------------------------------------------------------------
// 기여 점수 주기 (마스터~매니저)
// ---------------------------------------------------------------------------

/// 창의적 아이디어·자발적 목표 업무를 직접 주는 화면
///
/// 근무 외 출근·매출 성과는 기록에서 자동으로 들어오므로 여기서 못 준다.
class _GrantScreen extends StatefulWidget {
  _GrantScreen();

  @override
  State<_GrantScreen> createState() => _GrantScreenState();
}

class _GrantScreenState extends State<_GrantScreen> {
  _Kind _kind = _Kind.idea;
  String? _target;
  int _points = 10;
  final _title = TextEditingController();

  /// 본인에게는 줄 수 없다
  List<Staff> get _people => staffList.where((s) => s.name != me).toList();

  bool get _ready => _target != null && _title.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_ready) {
      AppToast.show(context, '받을 사람과 내용을 채워주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    _contributions.add(
      _Contribution(
        name: _target!,
        kind: _kind,
        title: _title.text.trim(),
        points: _points,
        date: DateTime.now(),
        by: me,
      ),
    );
    AppToast.show(context, '$_target님에게 $_points점을 줬어요');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                68,
                24,
                // 마지막 줄(점수)이 아래 버튼·모달 끝에 붙지 않게 넉넉히
                MediaQuery.paddingOf(context).bottom + 130,
              ),
              children: [
                _label('항목'),
                SizedBox(height: 8),
                Row(
                  children: [
                    for (final kind in _Kind.values.where((k) => k.granted))
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: kind == _Kind.idea ? 8 : 0,
                          ),
                          child: _kindButton(kind),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                _label('받을 사람'),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final person in _people) _personChip(person)],
                ),
                SizedBox(height: 20),
                _label('내용'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _title,
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _kind == _Kind.idea
                          ? '예) 락커 회전율 안내 문구 제안'
                          : '예) 신규 회원 온보딩 문서 정리',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _label('점수'),
                SizedBox(height: 8),
                Row(
                  children: [
                    for (final point in _pointOptions) ...[
                      if (point != _pointOptions.first) SizedBox(width: 8),
                      Expanded(child: _pointButton(point)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('기여 점수 주기', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomButton(
              label: '주기',
              active: _ready,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.label.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _kindButton(_Kind kind) {
    final on = kind == _kind;
    return Pressable(
      onTap: () => setState(() => _kind = kind),
      scale: 0.97,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind.icon,
              size: 14,
              color: on ? AppColors.primary : AppColors.gray500,
            ),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personChip(Staff person) {
    final on = person.name == _target;
    return Pressable(
      onTap: () => setState(() => _target = person.name),
      scale: 0.96,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 140),
        height: 44,
        padding: EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: on ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: person.name, size: 32),
            SizedBox(width: 8),
            Text(
              person.name,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointButton(int point) {
    final on = point == _points;
    return Pressable(
      onTap: () => setState(() => _points = point),
      scale: 0.95,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$point점',
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
