part of 'my_task_section.dart';

/// 개인 업무 **한 달 내역** — 며칠에 무엇을 했고 무엇을 빠뜨렸나
///
/// 예전에는 하루씩만 볼 수 있어서(요일 고르개) "8월에 며칠 누락했지" 를
/// 세려면 요일을 하나씩 눌러야 했다 (2026-08-31 대표 요청).
///
/// **세션 기록·환경정비 내역과 같은 모양이다** — 달을 고르고 날짜별로 묶인
/// 목록을 쭉 내리고, 아래 글래스 검색바로 찾는다.
///
/// [employeeId] 를 주면 **그 사람 것**이다 — 대표·관리자·점장이 조직 판에서
/// 사람을 골라 들어온다. 안 주면 본인 것이다.
Future<void> showMyTaskHistory(
  BuildContext context, {
  String? employeeId,
  String? name,
}) => showFullPage<void>(
  context,
  (_) => _MyTaskHistoryScreen(employeeId: employeeId, name: name),
);

class _MyTaskHistoryScreen extends StatefulWidget {
  const _MyTaskHistoryScreen({this.employeeId, this.name});

  /// null 이면 본인 것 — 서버가 조용히 본인으로 고정한다
  final String? employeeId;

  /// 제목에 쓸 이름 — null 이면 `업무 내역`
  final String? name;

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
      final rows = await MyTaskApi.history(
        month: periodKey(month),
        employeeId: widget.employeeId,
      );
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
                        itemBuilder: (context, i) => _HistoryDayCard(
                          row: rows[i],
                          onTap: () => showAppDialog<void>(
                            context,
                            (_) => _HistoryDayCard.detail(rows[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                    // 남의 것을 볼 때는 누구 것인지가 제목에 있어야 한다
                    widget.name == null ? '업무 내역' : '${widget.name} 업무 내역',
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

/// 하루 한 장 — 날짜 · 완료·누락 · 몇 개 중 몇 개, 그리고 이름들
///
/// **누르면 그날 기록이 열린다** (2026-09-16 요청). 카드에는 이름을 셋까지만
/// 적는데, 그 뒤가 무엇인지 볼 길이 없으면 `등` 이 막다른 길이 된다.
class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({required this.row, required this.onTap});

  final MyTaskHistoryDay row;
  final VoidCallback onTap;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// `9월 3일 목요일`
  static String dateLabel(DateTime date) =>
      '${date.month}월 ${date.day}일 ${_weekdays[date.weekday - 1]}요일';

  /// 카드 한 줄에 적는 이름 — **셋까지다**
  ///
  /// 예전에는 다 이어 붙이고 두 줄에서 `…` 로 잘랐다. 그러면 몇 개가 더
  /// 있는지를 알 수 없고, 줄 길이에 따라 어떤 날은 넷이 보이고 어떤 날은
  /// 둘이 보여서 **날끼리 견줄 수가 없다.**
  static String preview(List<String> names) {
    if (names.length <= _previewMax) return names.join(' · ');
    final head = names.take(_previewMax).join(' · ');
    return '$head 등 ${names.length}개';
  }

  static const _previewMax = 3;

  /// 그날 기록 — 카드를 누르면 뜨는 판. 한 것과 못 한 것을 **다** 적는다
  static Widget detail(MyTaskHistoryDay row) => _HistoryDayDetail(row: row);

  @override
  Widget build(BuildContext context) {
    final done = row.complete;
    final tone = done ? AppColors.success : AppColors.error;
    // 다 한 날은 한 것을, 못 한 날은 **못 한 것을** 적는다 — 봐야 할 값이 다르다
    final names = done ? row.doneTasks : row.leftTasks;

    return Pressable(
      onTap: onTap,
      // 카드 자체가 배경을 들고 있어서 누름 효과만 얹는다
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateLabel(row.date),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
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
                preview(names),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  height: 1.5,
                ),
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
      ),
    );
  }
}

/// 하루 기록 — 한 것과 못 한 것을 **다** 적는다 (2026-09-16 요청)
///
/// 카드는 셋까지만 적어서 `등 5개` 로 끝나는데, 그 뒤가 무엇인지 볼 자리가
/// 여기다. 근태 '오늘 근무' 칸을 눌렀을 때 뜨는 판과 같은 틀이다.
class _HistoryDayDetail extends StatelessWidget {
  const _HistoryDayDetail({required this.row});

  final MyTaskHistoryDay row;

  @override
  Widget build(BuildContext context) {
    final tone = row.complete ? AppColors.success : AppColors.error;
    return Container(
      width: dialogWidth(context, 320),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _HistoryDayCard.dateLabel(row.date),
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${row.done}/${row.total}',
                style: AppTextStyles.caption.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          // **못 한 것을 먼저 세운다** — 보러 들어온 이유가 그쪽이다
          if (row.leftTasks.isNotEmpty)
            _group('못 한 일', row.leftTasks, AppColors.error),
          if (row.doneTasks.isNotEmpty)
            _group('한 일', row.doneTasks, AppColors.success),
          if (row.total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '할 일을 안 정한 날이에요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _group(String label, List<String> names, Color tone) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${names.length}개',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (final name in names)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 7, right: 9),
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.body2.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
