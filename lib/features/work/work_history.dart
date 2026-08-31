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

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(widget.title, style: AppTextStyles.label),
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
          // 기록 수가 달라도 좌우 카드 높이가 어긋나지 않게 높이를 고정한다
          SizedBox(
            height: _listHeight,
            child: sorted.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(4, 20, 4, 20),
                    child: Text(
                      widget.emptyText,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
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
                            _LogRow(log: sorted[i], showName: widget.showName),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 오늘 수행 내역 화면 — 옆에서 슬라이드되어 열린다
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

  /// 보고 있는 날짜 — **여기서만 옮긴다**
  ///
  /// 업무 화면(칩)은 늘 오늘이다. `+` 가 서버에 **누른 시각**으로 남아서
  /// 지난 날짜에는 만들 수가 없는데, 거기에 날짜를 두면 칩과 내역이 서로
  /// 다른 날을 가리키게 된다. 그래서 지난 기록은 이 화면에서만 본다.
  late DateTime _date = _WorkScreenState._todayDate();

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
  String? _itemId;

  bool get _canSeeOthers => myRole != Role.member;

  /// 고를 수 있는 항목 — **지점 항목을 다 세운다** (사람 필터와 규칙이 다르다)
  ///
  /// 사람은 그날 이름이 있는 사람만 세우는데, 항목은 그러면 안 된다.
  /// 그날 기록이 없는 항목도 골라야 날짜를 넘겨 가며 "현수막을 며칠에
  /// 했지" 를 찾을 수 있다. 그날 것만 세우면 고르는 순간 그 항목이 메뉴에서
  /// 사라져서 필터를 풀 수도 없다.
  ///
  /// 지점 항목을 못 받았으면([_HistoryScreen.items] 가 비었으면) 그날
  /// 기록에서 이름순으로 뽑는다.
  List<FilterOption> get _itemOptions {
    if (widget.items.isNotEmpty) {
      // 서버가 하루 일하는 흐름대로 세워 준다 — 앱이 다시 안 세운다
      return [for (final item in widget.items) (id: item.id, name: item.name)];
    }
    final names = <String, String>{};
    for (final log in [..._allLogs, ..._myLogs]) {
      names[log.envItemId] ??= log.itemName;
    }
    return [for (final e in names.entries) (id: e.key, name: e.value)]
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
    return [for (final e in names.entries) (id: e.key, name: e.value)]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 공백·대소문자를 지우고 맞춘다 ('화장실 청소' 로 쳐도 찾히게)
  ///
  /// 사람 필터는 **전체 내역에서만** 건다 — 내 내역은 어차피 나뿐이다.
  /// 항목 필터는 양쪽 다 건다.
  List<EnvTaskLog> _filter(List<EnvTaskLog> rows) {
    final person = _all ? _personId : null;
    final item = _itemId;
    final key = _WorkScreenState._envKey(_search.text.trim());
    if (key.isEmpty && person == null && item == null) return rows;
    return [
      for (final log in rows)
        if (person == null || log.employeeId == person)
          if (item == null || log.envItemId == item)
            if (key.isEmpty ||
                _WorkScreenState._envKey(log.itemName).contains(key) ||
                _WorkScreenState._envKey(_logAuthor(log)).contains(key))
              log,
    ];
  }

  /// 열 때 부모가 오늘 기록을 이미 넘겨줘서 뼈대 없이 시작한다
  /// (세션 기록은 스스로 받아 와서 뼈대로 시작한다)
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    skipFirstSkeleton();
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _isToday => _date == _WorkScreenState._todayDate();

  /// 날짜를 옮기고 그 날 기록을 받아 온다 — **다음 날로는 못 간다**
  Future<void> _move(int step) async {
    final next = DateTime(_date.year, _date.month, _date.day + step);
    if (next.isAfter(_WorkScreenState._todayDate())) return;
    setState(() {
      _date = next;
      beginLoad();
    });
    try {
      final logs = await EnvApi.logs(
        branchId: widget.branchId,
        date: dateKey(next),
      );
      // 기다리는 사이 또 눌렀으면 이 응답은 버린다 (빠르게 여러 날 넘길 때
      // 늦게 온 옛 응답이 새 날짜를 덮어쓰면 안 된다)
      if (!mounted || _date != next) return;
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

  /// 날짜 좌우 화살표 — **세션 기록의 달 이동바(`_MonthBar`)와 같은 모양**이다
  ///
  /// 테두리 없이 아이콘만 두고 여백으로 누를 자리를 만든다. 회색 상자를
  /// 두르면 줄이 무거워진다 (2026-08-14, 세션 쪽이 낫다고 정했다).
  ///
  /// [onTap] 이 null 이면 흐린 채로 안 눌린다 (자리는 그대로 둔다).
  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.textSecondary : AppColors.gray300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${_date.month}월 ${_date.day}일 ${_weekdays[_date.weekday - 1]}요일';
    final logs = _filter(_all ? _allLogs : _myLogs);
    final sorted = List.of(logs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                  Padding(
                    // 세션 기록의 `_MonthBar` 와 같은 여백이다 — 왼쪽 16 인 것은
                    // 화살표가 제 안에 8 을 갖고 있어서, 눈에 보이는 끝이 24 로
                    // 아래 목록과 맞는다
                    padding: EdgeInsets.fromLTRB(16, 6, 24, 6),
                    child: Row(
                      children: [
                        _arrow(CupertinoIcons.chevron_left, () => _move(-1)),
                        Text(
                          date,
                          style: AppTextStyles.body2.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // 다음 날은 아직 안 왔으니 늘 비어 있다 — 흐려 두고 안 눌리게
                        _arrow(
                          CupertinoIcons.chevron_right,
                          _isToday ? null : () => _move(1),
                        ),
                        Spacer(),
                        // 받아 오는 동안은 건수도 뼈대다 (세션 기록과 같다)
                        if (showSkeleton)
                          Skeleton(width: 46, height: 12)
                        else
                          Text(
                            '총 ${logs.length}회',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
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
                            : _isToday
                            ? (_all ? '오늘 완료된 항목이 없어요' : '오늘 완료한 항목이 없어요')
                            : (_all ? '완료된 항목이 없어요' : '완료한 항목이 없어요'),
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        // 날짜·탭이 바뀌면 맨 위부터 다시 본다
                        key: ValueKey('$_all-$_date'),
                        // 아래 글래스 검색바에 마지막 줄이 가리지 않게 띄운다
                        padding: EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          MediaQuery.paddingOf(context).bottom + 92,
                        ),
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        // 전체 내역에서는 누가 했는지 이름을 함께 보여준다
                        itemBuilder: (_, index) =>
                            _LogRow(log: sorted[index], showName: _all),
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
                    // 날짜를 옮기면 '오늘' 이 틀린 말이 된다
                    widget.tabs
                        ? (_isToday ? '오늘 내역' : '수행 내역')
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
                      selected: _itemId,
                      icon: CupertinoIcons.tag,
                      symbol: 'tag',
                      onSelect: (id) => setState(() => _itemId = id),
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
          GlassSearchBar(controller: _search, hint: '항목·이름 검색'),
        ],
      ),
    );
  }
}
