part of 'my_task_section.dart';

/// 개인 업무 **한 달 내역** — 며칠에 무엇을 했고 무엇을 빠뜨렸나
///
/// 예전에는 하루씩만 볼 수 있어서(요일 고르개) "8월에 며칠 누락했지" 를
/// 세려면 요일을 하나씩 눌러야 했다 (2026-08-31 대표 요청).
///
/// **세션 기록·환경정비 내역과 같은 모양이다** — 달을 고르고 날짜별로 묶인
/// 목록을 쭉 내리고, 아래 글래스 검색바로 찾는다.
Future<void> showMyTaskHistory(BuildContext context) =>
    showFullPage<void>(context, (_) => const _MyTaskHistoryScreen());

class _MyTaskHistoryScreen extends StatefulWidget {
  const _MyTaskHistoryScreen();

  @override
  State<_MyTaskHistoryScreen> createState() => _MyTaskHistoryScreenState();
}

/// 무엇만 볼지 — 누락한 날을 세는 것이 이 화면의 주된 쓰임이다
enum _HistoryFilter {
  all('전체'),
  complete('완료'),
  missed('누락');

  const _HistoryFilter(this.label);

  final String label;
}

class _MyTaskHistoryScreenState extends State<_MyTaskHistoryScreen>
    with SkeletonDelay<_MyTaskHistoryScreen> {
  final _search = TextEditingController();

  late DateTime _month = _thisMonth();
  List<MyTaskHistoryDay> _rows = const [];
  _HistoryFilter _filter = _HistoryFilter.all;

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _isThisMonth => _month == _thisMonth();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load(_month);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(_thisMonth())) return;
    setState(() => _month = next);
    _load(next);
  }

  Future<void> _load(DateTime month) async {
    setState(beginLoad);
    try {
      final rows = await MyTaskApi.history(month: periodKey(month));
      // 기다리는 사이 또 눌렀으면 이 응답은 버린다 (빠르게 여러 달 넘길 때
      // 늦게 온 옛 응답이 새 달을 덮어쓰면 안 된다)
      if (!mounted || _month != month) return;
      setState(() {
        _rows = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad); // 실패해도 뼈대에 갇히지 않게 푼다
      AppToast.show(context, messageOf(error));
    }
  }

  /// 공백·대소문자를 지우고 맞춘다 — 환경정비 내역과 같은 규칙이다
  static String _key(String text) => text.replaceAll(' ', '').toLowerCase();

  /// 날짜를 글자로 — 검색에서 `8월 31일` · `8/31` · `31` 이 다 걸린다
  static String _dateKeys(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '${t.year}-$mm-$dd|${t.month}월${t.day}일|${t.month}/${t.day}'
        '|${t.month}.${t.day}|$mm$dd';
  }

  List<MyTaskHistoryDay> get _visible {
    final query = _key(_search.text.trim());
    return [
      for (final row in _rows)
        if (switch (_filter) {
          _HistoryFilter.all => true,
          _HistoryFilter.complete => row.complete,
          _HistoryFilter.missed => !row.complete,
        })
          // 업무 이름과 날짜를 같이 훑는다
          if (query.isEmpty ||
              _dateKeys(row.date).contains(query) ||
              [
                ...row.doneTasks,
                ...row.leftTasks,
              ].any((t) => _key(t).contains(query)))
            row,
    ];
  }

  int _count(_HistoryFilter filter) => switch (filter) {
    _HistoryFilter.all => _rows.length,
    _HistoryFilter.complete => _rows.where((r) => r.complete).length,
    _HistoryFilter.missed => _rows.where((r) => !r.complete).length,
  };

  @override
  Widget build(BuildContext context) {
    final rows = _visible;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // 머리말 건수와 목록이 **한 박자로** 반짝이게 하나로 감싼다
          SkeletonGroup(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 고정 타이틀 영역만큼 비워둔다
                  const SizedBox(height: 56),
                  MonthBar(
                    month: _month,
                    count: rows.length,
                    unit: '일',
                    loading: showSkeleton,
                    onPrev: () => _shiftMonth(-1),
                    // 아직 오지 않은 달은 볼 게 없으니 막는다
                    onNext: _isThisMonth ? null : () => _shiftMonth(1),
                  ),
                  Container(height: 1, color: AppColors.gray100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: SegmentedTabs(
                      labels: [
                        for (final f in _HistoryFilter.values)
                          '${f.label} ${_count(f)}',
                      ],
                      selected: _HistoryFilter.values.indexOf(_filter),
                      onSelect: (i) =>
                          setState(() => _filter = _HistoryFilter.values[i]),
                    ),
                  ),
                  if (showSkeleton)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: SkeletonRows(rows: 5, avatar: 0, trailing: 40),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 44),
                      child: Text(
                        _search.text.trim().isNotEmpty
                            ? '찾는 날이 없어요'
                            : _rows.isEmpty
                            ? '이 달에는 근무한 날이 없어요'
                            : '해당하는 날이 없어요',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        // 달·갈래가 바뀌면 맨 위부터 다시 본다
                        key: ValueKey('$_month-$_filter'),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          // 아래 글래스 검색바에 마지막 줄이 가리지 않게
                          MediaQuery.paddingOf(context).bottom + 96,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _HistoryDayCard(row: rows[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          const IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: _HistoryTitle()),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 아래 떠 있는 글래스 검색바 — 세션 기록·환경정비 내역과 같은 부품이다
          GlassSearchBar(controller: _search, hint: '업무·날짜 검색'),
        ],
      ),
    );
  }
}

class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle();

  @override
  Widget build(BuildContext context) =>
      Text('업무 내역', style: AppTextStyles.title3);
}

/// 하루 한 장 — 날짜 · 완료·누락 · 몇 개 중 몇 개, 그리고 이름들
class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({required this.row});

  final MyTaskHistoryDay row;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final done = row.complete;
    final tone = done ? AppColors.success : AppColors.error;
    // 다 한 날은 한 것을, 못 한 날은 **못 한 것을** 적는다 — 봐야 할 값이 다르다
    final names = done ? row.doneTasks : row.leftTasks;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.date.month}월 ${row.date.day}일 '
                  '${_weekdays[row.date.weekday - 1]}요일',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${row.done}/${row.total}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? '완료' : '누락',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              names.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12, height: 1.5),
            ),
          ] else if (row.total == 0) ...[
            const SizedBox(height: 8),
            Text(
              '할 일을 안 정한 날이에요',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
