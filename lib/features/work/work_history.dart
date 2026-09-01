part of 'work_screen.dart';

/// 데스크톱에서 점검 항목 아래에 상시 떠 있는 내역 카드.
/// 다섯 줄까지만 펼치고 그보다 많으면 카드 안에서 스크롤한다.
class _HistoryCard extends StatefulWidget {
  _HistoryCard({
    required this.title,
    required this.logs,
    required this.showName,
    required this.emptyText,
    required this.onOpenAll,
    this.rows = 5,
  });

  final String title;
  final List<EnvTaskLog> logs;
  final bool showName;
  final String emptyText;

  /// 카드에는 다섯 줄만 보이므로 나머지는 모달에서 본다
  final VoidCallback onOpenAll;

  /// 미리보기로 보여줄 줄 수
  ///
  /// 기본 5줄은 **내 내역과 나란히 설 때**의 값이다 — 좌우 카드 높이가
  /// 어긋나면 안 된다. 대표·관리자는 내 내역이 없어서 전체 내역이 혼자
  /// 서므로 10줄로 늘린다 (2026-08-14 대표 요청).
  final int rows;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final _scrollController = ScrollController();

  /// 한 줄 높이(위아래 여백 13 + 본문 22.5)에 구분선을 더한 값
  static const _rowHeight = 48.5;

  double get _listHeight => widget.rows * _rowHeight + 4;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(widget.logs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 머리말은 **카드 밖**이다 (2026-09-01 대표 요청) — 공통 업무·오늘
        // 할 일·세션 기록과 같은 모양이다
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                widget.title,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '총 ${sorted.length}회',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SeeAllButton(onTap: widget.onOpenAll),
            ],
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기록 수가 달라도 좌우 카드 높이가 어긋나지 않게 높이를 고정한다
              SizedBox(
                height: _listHeight,
                child: sorted.isEmpty
                    // 빈 상태는 **앱 공통 모양**이다 (홈 프로젝트·공지,
                    // 결재함과 같은 [EmptyCard]). 이미 카드 안이라 테두리는 뺀다
                    ? Center(
                        child: EmptyCard(
                          icon: CupertinoIcons.checkmark_circle,
                          text: widget.emptyText,
                          framed: false,
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            children: [
                              for (var i = 0; i < sorted.length; i++) ...[
                                if (i > 0)
                                  Divider(height: 1, color: AppColors.divider),
                                _LogRow(
                                  log: sorted[i],
                                  showName: widget.showName,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 수행 내역 화면 — 옆에서 슬라이드되어 열린다
///
/// **한 달치를 한 번에 본다** (2026-08-31 대표 요청). 예전에는 하루씩 좌우
/// 화살표로 넘겼는데, 그러면 "현수막을 며칠에 했지" 를 찾으려고 날짜를
/// 하나씩 눌러야 했다. 세션 기록과 같은 모양이다 — 달을 고르고 **날짜별로
/// 묶인 목록을 쭉 내린다.**
///
/// 폰은 들어오는 문이 하나뿐이라 내 내역/전체 내역 탭으로 오간다.
/// 데스크톱은 두 카드가 각각 '전체 보기'를 갖고 있어서, 누른 쪽만
/// 열어 준다 ([tabs]가 false) — 눌렀는데 다른 것까지 나오면 헷갈린다.
class _HistoryScreen extends StatefulWidget {
  _HistoryScreen({
    required this.myLogs,
    required this.allLogs,
    required this.branchId,
    this.items = const [],
    this.initialAll = false,
    this.tabs = true,
  });

  /// 열 때 받은 **오늘** 기록 — 날짜를 옮기기 전까지는 이걸 그대로 쓴다
  final List<EnvTaskLog> myLogs;
  final List<EnvTaskLog> allLogs;

  /// 날짜를 옮길 때 다시 받을 지점 (null 이면 전 지점)
  final String? branchId;

  /// 이 지점의 환경정비 항목 — **항목 필터 메뉴를 이걸로 세운다**
  ///
  /// 비어 있을 수 있다. 업무 화면이 대표·관리자와 '전 지점' 에는 항목을
  /// 안 받는다 (겹쳐 오거나 안 쓰므로). 그때는 그날 기록에서 뽑아 세운다.
  final List<EnvItem> items;

  /// 어느 쪽으로 열지 (데스크톱은 누른 카드에 맞춰 연다)
  final bool initialAll;

  /// 내 내역·전체 내역 전환 탭을 보여줄지
  final bool tabs;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen>
    with SkeletonDelay<_HistoryScreen> {
  /// true면 전체 내역
  late bool _all = widget.initialAll;

  /// 보고 있는 달 — **여기서만 옮긴다**
  ///
  /// 업무 화면(칩)은 늘 오늘이다. `+` 가 서버에 **누른 시각**으로 남아서
  /// 지난 날짜에는 만들 수가 없는데, 거기에 날짜를 두면 칩과 내역이 서로
  /// 다른 날을 가리키게 된다. 그래서 지난 기록은 이 화면에서만 본다.
  late DateTime _month = _thisMonth();

  static DateTime _thisMonth() {
    final today = _WorkScreenState._todayDate();
    return DateTime(today.year, today.month);
  }

  late List<EnvTaskLog> _myLogs = widget.myLogs;
  late List<EnvTaskLog> _allLogs = widget.allLogs;

  /// 검색어 — 항목 이름과 사람 이름을 같이 훑는다
  ///
  /// 하루에 100건 넘게 쌓이는 지점이 있어서 눈으로 훑기 어렵다.
  /// 세션 기록·칭찬 목록과 **같은 글래스 검색바**를 쓴다.
  final _search = TextEditingController();

  /// 오른쪽 위 필터로 고른 사람 — null 이면 전체
  ///
  /// **직원 말고 다에게 있다** (`_canSeeOthers`). 하루에 100건 넘게 쌓이는
  /// 지점이 있어서 "그 사람이 오늘 뭘 했나"를 보려면 눈으로 훑어야 했다
  /// (2026-08-19 대표 요청 — 세션 기록에 있던 것과 같은 부품이다).
  ///
  /// 서버에 다시 묻지 않고 **받아 둔 그날 기록에서 거른다.**
  String? _personId;

  /// 오른쪽 위 필터로 고른 환경정비 항목 — null 이면 전체
  ///
  /// 사람 필터와 **따로 돈다** — 둘 다 걸면 '유찬빈의 현수막' 만 남는다.
  /// 사람 필터와 달리 **내 내역에서도 보인다** (내가 뭘 몇 번 했는지를
  /// 보는 자리라 나 혼자여도 뜻이 있다).
  ///
  /// **id 가 아니라 이름이다.** 항목은 지점마다 따로 있어서 `건조기` 가
  /// 지점 수만큼 다른 id 로 존재한다 — id 로 거르면 전 지점을 볼 때
  /// 한 지점 것만 남는다 (2026-08-31 대표 지적).
  String? _itemName;

  bool get _canSeeOthers => myRole != Role.member;

  /// 고를 수 있는 항목 — **지점 항목을 다 세운다** (사람 필터와 규칙이 다르다)
  ///
  /// 사람은 그날 이름이 있는 사람만 세우는데, 항목은 그러면 안 된다.
  /// 그날 기록이 없는 항목도 골라야 날짜를 넘겨 가며 "현수막을 며칠에
  /// 했지" 를 찾을 수 있다. 그날 것만 세우면 고르는 순간 그 항목이 메뉴에서
  /// 사라져서 필터를 풀 수도 없다.
  ///
  /// 지점 항목을 못 받았으면([_HistoryScreen.items] 가 비었으면) 그 달
  /// 기록에서 이름순으로 뽑는다 — **비는 일은 이제 거의 없다** (업무 화면이
  /// 누구에게나 받는다).
  ///
  /// 고르는 값이 **이름**이라 지점이 여럿이어도 한 줄만 선다.
  List<FilterOption> get _itemOptions {
    if (widget.items.isNotEmpty) {
      // 서버가 하루 일하는 흐름대로 세워 준다 — 앱이 다시 안 세운다
      return [
        for (final item in widget.items) (id: item.name, name: item.name),
      ];
    }
    final names = <String>{};
    for (final log in [..._allLogs, ..._myLogs]) {
      names.add(log.itemName);
    }
    return [for (final name in names) (id: name, name: name)]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 고를 수 있는 사람 — 이름순
  ///
  /// 명단 전체가 아니라 **그날 기록에 이름이 있는 사람만** 세운다
  /// (세션 기록과 같은 규칙). 스무 명 메뉴에서 오늘 일한 셋을 찾게 하면
  /// 고르는 일이 더 번거롭다.
  List<FilterOption> get _people {
    final names = <String, String>{};
    for (final log in _allLogs) {
      names[log.employeeId] ??= _logAuthor(log);
    }
    // 앱 공통 차례 (지점 → 직급 → 이름)
    return [for (final e in names.entries) (id: e.key, name: e.value)]..sort(
      (a, b) =>
          StaffDirectory.instance.compareStaffIds(a.id, b.id, a.name, b.name),
    );
  }

  /// 공백·대소문자를 지우고 맞춘다 ('화장실 청소' 로 쳐도 찾히게)
  ///
  /// 사람 필터는 **전체 내역에서만** 건다 — 내 내역은 어차피 나뿐이다.
  /// 항목 필터는 양쪽 다 건다.
  List<EnvTaskLog> _filter(List<EnvTaskLog> rows) {
    final person = _all ? _personId : null;
    final item = _itemName == null
        ? null
        : _WorkScreenState._envKey(_itemName!);
    final key = _WorkScreenState._envKey(_search.text.trim());
    if (key.isEmpty && person == null && item == null) return rows;
    return [
      for (final log in rows)
        if (person == null || log.employeeId == person)
          if (item == null || _WorkScreenState._envKey(log.itemName) == item)
            if (key.isEmpty ||
                _WorkScreenState._envKey(log.itemName).contains(key) ||
                _WorkScreenState._envKey(_logAuthor(log)).contains(key) ||
                _dateKeys(log.createdAt).contains(key))
              log,
    ];
  }

  /// 날짜를 글자로 — **검색에서 `8월 31일` · `8/31` · `31` 이 다 걸린다**
  ///
  /// 한 달치를 쭉 내리게 되면서 "그날 뭘 했지" 를 찾을 길이 필요해졌다
  /// (2026-08-31 대표 요청). 쓰는 사람마다 적는 모양이 달라서 한 줄에
  /// 다 이어 붙여 두고 `contains` 로 본다.
  static String _dateKeys(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '${t.year}-$mm-$dd|${t.month}월${t.day}일|${t.month}/${t.day}'
        '|${t.month}.${t.day}|$mm$dd';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 부모가 넘겨준 **오늘** 기록을 깔아 두고 그 달치를 받아 온다
  ///
  /// 옛 줄을 안 지운 채로 갈아끼우므로, 빨리 오면 뼈대가 아예 안 뜬다
  /// (`SkeletonDelay`). 화면이 열리자마자 빈 판이 되는 것을 막는다.
  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    skipFirstSkeleton();
    _loadMonth(_month);
  }

  bool get _isThisMonth => _month == _thisMonth();

  /// 달을 옮긴다 — **다음 달로는 못 간다**
  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(_thisMonth())) return;
    setState(() => _month = next);
    _loadMonth(next);
  }

  /// 그 달 기록을 받아 온다
  Future<void> _loadMonth(DateTime month) async {
    setState(beginLoad);
    try {
      final logs = await EnvApi.logs(
        branchId: widget.branchId,
        period: periodKey(month),
      );
      // 기다리는 사이 또 눌렀으면 이 응답은 버린다 (빠르게 여러 달 넘길 때
      // 늦게 온 옛 응답이 새 달을 덮어쓰면 안 된다)
      if (!mounted || _month != month) return;
      setState(() {
        _allLogs = logs;
        _myLogs = [
          for (final log in logs)
            if (log.employeeId == currentUser?.id) log,
        ];
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad); // 실패해도 뼈대에 갇히지 않게 푼다
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filter(_all ? _allLogs : _myLogs);
    final sorted = List.of(logs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 날짜가 바뀌는 지점마다 머리말을 끼워 넣는다 — 세션 기록과 같은 모양이다
    final rows = <Widget>[];
    String? label;
    for (final log in sorted) {
      final day = dayLabel(log.createdAt);
      if (day != label) {
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              day,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = day;
      } else {
        rows.add(Divider(height: 1, color: AppColors.divider));
      }
      // 전체 내역에서는 누가 했는지 이름을 함께 보여준다
      rows.add(_LogRow(log: log, showName: _all));
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // 머리말 건수와 목록이 **한 박자로** 반짝이게 하나로 감싼다 —
          // 따로 감싸면 컨트롤러가 둘이라 박자가 어긋난다
          SkeletonGroup(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 고정 타이틀 영역만큼 비워둔다
                  SizedBox(height: 56),
                  MonthBar(
                    month: _month,
                    count: logs.length,
                    unit: '회',
                    loading: showSkeleton,
                    onPrev: () => _shiftMonth(-1),
                    // 아직 오지 않은 달은 볼 게 없으니 막는다
                    onNext: _isThisMonth ? null : () => _shiftMonth(1),
                  ),
                  SizedBox(height: widget.tabs ? 8 : 14),
                  // 내 내역 / 전체 내역 전환 탭 (업무 탭과 같은 밑줄 스타일)
                  if (widget.tabs)
                    UnderlineTabs(
                      labels: const ['내 내역', '전체 내역'],
                      selected: _all ? 1 : 0,
                      onSelect: (i) => setState(() => _all = i == 1),
                    ),
                  Container(height: 1, color: AppColors.gray100),
                  if (showSkeleton)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: SkeletonRows(rows: 5, avatar: 0, trailing: 40),
                    )
                  else if (sorted.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                      child: Text(
                        _search.text.trim().isNotEmpty
                            ? '찾는 기록이 없어요'
                            : (_all ? '이 달에 완료된 항목이 없어요' : '이 달에 완료한 항목이 없어요'),
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        // 달·탭이 바뀌면 맨 위부터 다시 본다
                        key: ValueKey('$_all-$_month'),
                        // 아래 글래스 검색바에 마지막 줄이 가리지 않게 띄운다
                        padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          MediaQuery.paddingOf(context).bottom + 92,
                        ),
                        children: rows,
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
                    // 한 달치를 보므로 '오늘' 이 아니다
                    widget.tabs
                        ? '수행 내역'
                        : _all
                        ? '전체 내역'
                        : '내 내역',
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
          // 우측 상단 필터 둘 — **항목**은 늘, **사람**은 전체 내역을 볼 때만.
          // 뒤로가기와 마주 보는 자리다. 아래 검색바(블러)와는 Stack 의 다른
          // 자식이라 네이티브 버튼이 묻히지 않는다 (같은 Row 에 두면 탭이
          // 안 먹는다). 둘 다 네이티브 버튼이라 서로는 나란히 둬도 된다.
          //
          // **사람 버튼이 늘 오른쪽 끝**이다 — 항목 필터가 생겼다고 예전부터
          // 쓰던 버튼이 자리를 옮기면 안 된다.
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8, right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PickFilterButton(
                      stableId: 'env-item',
                      options: _itemOptions,
                      selected: _itemName,
                      icon: CupertinoIcons.tag,
                      symbol: 'tag',
                      onSelect: (name) => setState(() => _itemName = name),
                    ),
                    if (_canSeeOthers && _all) ...[
                      // PhoneDetailScaffold 의 actions 와 같은 간격
                      SizedBox(width: 10),
                      PickFilterButton(
                        stableId: 'env-person',
                        options: _people,
                        selected: _personId,
                        onSelect: (id) => setState(() => _personId = id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 아래 떠 있는 글래스 검색바 — 세션 기록·칭찬 목록과 같은 부품이다
          GlassSearchBar(controller: _search, hint: '항목·이름·날짜 검색'),
        ],
      ),
    );
  }
}
