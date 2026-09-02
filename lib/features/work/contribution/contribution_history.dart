part of 'contribution_section.dart';

// ---------------------------------------------------------------------------
// 내역
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  _HistoryCard({
    required this.items,
    required this.total,
    required this.onOpenAll,
    this.onRevert,
  });

  final List<_Contribution> items;
  final int total;
  final VoidCallback onOpenAll;

  /// 깎인 줄을 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다).
  /// **되돌렸으면 true** (확인창에서 취소하면 false).
  final Future<bool> Function(_Contribution item)? onRevert;

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
              _ContributionRow(
                item: items[i],
                onRevert: onRevert == null ? null : () => onRevert!(items[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 폰 목록 카드 — 다른 업무 목록과 같은 결로 기여 하나에 카드 하나
///
/// 데스크톱은 아직 [_ContributionRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _ContributionCard extends StatelessWidget {
  _ContributionCard({required this.item, this.onRevert});

  final _Contribution item;

  /// 깎인 점수를 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      // 부여 항목은 상대가 근거다 — 조사로 준 것·받은 것을 가른다
                      item.personLabel == null
                          ? _dayLabel(item.date)
                          : '${item.personLabel} · ${_dayLabel(item.date)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item.pointsLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.isPenalty && onRevert != null) ...[
                SizedBox(width: 2),
                _RevertButton(onTap: onRevert!),
              ],
            ],
          ),
          SizedBox(height: 14),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기여 한 줄 — 항목 아이콘, 내용, 준 사람, 점수
/// 깎인 줄 오른쪽 되돌리기 아이콘 — **대표에게만, 깎인 줄에만** (2026-08-28)
///
/// 줄 모양은 그대로 두고 아이콘만 뒤에 붙는다. 깎인 줄을 따로 생기게 만들면
/// 목록이 두 종류로 갈려서 훑기가 어려워진다.
class _RevertButton extends StatelessWidget {
  _RevertButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    padding: EdgeInsets.all(6),
    child: Icon(
      CupertinoIcons.arrow_counterclockwise,
      size: 15,
      color: AppColors.textTertiary,
    ),
  );
}

class _ContributionRow extends StatelessWidget {
  _ContributionRow({required this.item, this.onRevert});

  final _Contribution item;

  /// 깎인 점수를 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  final VoidCallback? onRevert;

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
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 15, color: item.color),
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
                  // 부여 항목은 상대가 근거다 — 조사로 준 것·받은 것을 가른다
                  item.personLabel == null
                      ? '${item.label} · ${_dayLabel(item.date)}'
                      : '${item.label} · ${item.personLabel} · '
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
            item.pointsLabel,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w700,
              // 깎인 줄은 빨강 — 카드(`_ContributionCard`)와 같은 규칙이다
              color: item.isPenalty ? AppColors.error : AppColors.primary,
            ),
          ),
          if (item.isPenalty && onRevert != null) ...[
            SizedBox(width: 2),
            _RevertButton(onTap: onRevert!),
          ],
        ],
      ),
    );
  }
}

/// 기여 내역 전체 화면 — 이번 달 내 기록
class _ContributionHistoryScreen extends StatefulWidget {
  _ContributionHistoryScreen({required this.items, this.onRevert});

  final List<_Contribution> items;

  /// 깎인 줄을 되돌린다 — null 이면 아이콘이 안 뜬다 (대표가 아니다)
  /// 되돌렸으면 true — **확인창에서 취소하면 false 다.**
  ///
  /// 값을 안 돌려받던 때는 아이콘을 누르는 순간 줄이 사라졌다. 확인창은
  /// 떠 있는데 화면에서는 이미 되돌아간 것처럼 보였고, 취소를 눌러도 줄이
  /// 안 돌아왔다 (2026-08-31 대표 지적).
  final Future<bool> Function(_Contribution item)? onRevert;

  @override
  State<_ContributionHistoryScreen> createState() =>
      _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState
    extends State<_ContributionHistoryScreen> {
  /// **넘겨받은 목록을 여기서 들고 있는다.** 되돌리면 이 화면에서도 줄이
  /// 바로 빠져야 하는데, 뒤에 있는 탭이 다시 받아 오는 것을 여기서는 못 본다
  /// (전체 화면으로 덮여 있어서 그 화면은 새로 안 그려진다).
  late List<_Contribution> _items = widget.items;

  /// 검색어 — 항목·상대 이름·내용·날짜를 같이 훑는다
  ///
  /// 환경정비 전체 내역·세션 기록·칭찬 목록과 **같은 글래스 검색바**다
  /// (2026-09-02 대표 요청).
  final _search = TextEditingController();

  /// 오른쪽 위 필터로 고른 항목 — null 이면 전체
  String? _kind;

  /// 오른쪽 위 필터로 고른 사람 — null 이면 전체
  String? _person;

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

  /// **되돌아간 뒤에만** 줄을 뺀다 — 확인창에서 취소하면 그대로 남는다
  Future<void> _revert(_Contribution item) async {
    final done = await widget.onRevert?.call(item) ?? false;
    if (!done || !mounted) return;
    setState(() {
      _items = [
        for (final row in _items)
          if (row.eventId == null || row.eventId != item.eventId) row,
      ];
    });
  }

  /// 깎인 줄을 한 칸으로 묶는 이름 — 지각·업무 누락을 따로 안 세운다
  ///
  /// 필터에 사유를 다 펴면 칸이 달마다 늘었다 줄었다 한다. 쓰는 사람이
  /// 찾는 것은 "깎인 줄" 하나라 **한 칸으로 묶는다** (2026-09-02 대표 요청).
  static const _cutLabel = '차감';

  /// 그 줄이 무슨 항목인가 — **받은 것은 기여 항목, 깎인 것은 [_cutLabel]**
  static String _kindLabelOf(_Contribution item) =>
      item.kind?.label ?? _cutLabel;

  /// 항목 필터 — **늘 다섯 칸이다** (기여 넷 + 차감)
  ///
  /// 이번 달에 있는 것만 세우면 **칸이 달마다 달라져서** 자리를 못 외운다.
  /// 골랐는데 비면 '조건에 맞는 기록이 없어요' 로 알린다 — 그게 없는 것보다
  /// 낫다 (2026-09-02 대표 요청).
  static final List<FilterOption> _kindOptions = [
    for (final type in ContribType.values) (id: type.label, name: type.label),
    (id: _cutLabel, name: _cutLabel),
  ];

  /// 사람 필터를 띄우나 — **점장 이상** (2026-09-02 대표 결정)
  ///
  /// 기준은 "남의 이름이 붙은 줄을 보느냐" 다.
  ///
  /// | | 무엇을 보나 | 상대 이름 |
  /// |---|---|---|
  /// | 직원 | 받은 기여 · 본인 자동·차감 | **준 사람**(대표·관리자)뿐 |
  /// | 점장 | 위 + **내가 준 기여** | 받은 사람 — 트레이너·점장이다 |
  /// | 대표·관리자 | 내가 준 것 + **전 직원** 자동·차감 | 전부 |
  ///
  /// **직원에게는 안 띄운다.** 그 화면의 상대는 준 사람(대표·관리자)인데
  /// 아래 목록은 받는 쪽(트레이너·점장)이라 **골라도 늘 0건**이 된다.
  static bool get _canPickPerson => myRole.canGrant;

  /// 사람 필터 — **명단 전체다** (환경정비 전체 내역과 같은 규칙)
  ///
  /// 기록이 있는 사람만 세우면 칸이 달마다 달라진다. 지점은
  /// [rosterBranchId] 가 가른다 — 안 고른 점장에게 다른 지점 사람이 서면
  /// 골라도 늘 0건이다.
  ///
  /// **대표·관리자는 뺀다.** 기여는 자기보다 아래에만 주는 것이라(서버
  /// `GRANTABLE`) 그 둘은 받지 않고, 출퇴근도 안 남겨서 차감도 안 붙는다.
  ///
  /// 이름을 키로 쓴다 — [_Contribution.person] 이 이름뿐이라서다
  /// (backend-gap 10). 동명이인은 한 칸으로 묶인다.
  List<FilterOption> get _people {
    final branch = rosterBranchId;
    final rows = <Employee>[];
    for (final employee in StaffDirectory.instance.employees) {
      if (!employee.role.doesFieldWork) continue;
      if (employee.status != EmployeeStatus.active) continue;
      if (branch != null && employee.branchId != branch) continue;
      rows.add(employee);
    }
    // 앱 공통 차례 (지점 → 직급 → 이름)
    rows.sort(StaffDirectory.instance.compareStaff);
    final names = <String>[];
    for (final employee in rows) {
      if (!names.contains(employee.name)) names.add(employee.name);
    }
    return [for (final name in names) (id: name, name: name)];
  }

  /// 검색·필터를 다 태운 목록
  List<_Contribution> get _shown {
    final key = _search.text.trim();
    // 버튼이 안 뜨는 사람에게는 사람 필터를 안 건다 — 안 그러면 어딘가에서
    // 값이 남았을 때 못 푸는 필터가 걸린 채로 화면이 빈다
    final person = _canPickPerson ? _person : null;
    if (key.isEmpty && _kind == null && person == null) return _items;
    return [
      for (final item in _items)
        if (_kind == null || _kindLabelOf(item) == _kind)
          if (person == null || item.person == person)
            if (key.isEmpty ||
                item.title.contains(key) ||
                _kindLabelOf(item).contains(key) ||
                // 깎인 줄은 항목 이름이 '차감' 이라 사유가 따로 걸려야
                // `지각`·`업무 누락` 으로 찾을 수 있다
                (item.penalty?.label ?? '').contains(key) ||
                (item.person ?? '').contains(key) ||
                _dateKeys(item.date).contains(key))
              item,
    ];
  }

  /// 날짜를 글자로 — **`8월 31일` · `8/31` · `0831` 이 다 걸린다**
  ///
  /// 환경정비 전체 내역과 **같은 규칙**이다. 쓰는 사람마다 적는 모양이 달라서
  /// 한 줄에 다 이어 붙여 두고 `contains` 로 본다.
  static String _dateKeys(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '${t.year}-$mm-$dd|${t.month}월${t.day}일|${t.month}/${t.day}'
        '|${t.month}.${t.day}|$mm$dd';
  }

  @override
  Widget build(BuildContext context) {
    final mine = _shown;
    final people = _people;
    final kinds = _kindOptions;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              // 아래 글래스 검색바에 마지막 줄이 가리지 않게 띄운다
              // (환경정비 전체 내역과 같은 값)
              padding: EdgeInsets.fromLTRB(
                24,
                68,
                24,
                MediaQuery.paddingOf(context).bottom + 92,
              ),
              children: [
                if (mine.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                    child: Text(
                      // 걸러서 빈 것과 원래 없는 것을 가른다 — 안 가르면
                      // 필터를 걸어 둔 걸 잊고 "기록이 사라졌다" 로 본다
                      _items.isEmpty ? '이번 달 기여 기록이 없어요' : '조건에 맞는 기록이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider),
                    _ContributionRow(
                      item: mine[i],
                      onRevert: widget.onRevert == null
                          ? null
                          : () => _revert(mine[i]),
                    ),
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
          // 우측 상단 필터 둘 — 뒤로가기와 마주 보는 자리다.
          //
          // **아래 검색바(블러)와는 Stack 의 다른 자식이어야 한다.** 같은 Row 에
          // 두면 네이티브 버튼이 블러 레이어에 묻혀 탭이 안 먹는다
          // (환경정비 전체 내역과 같은 구조).
          //
          // **둘 다 늘 뜬다.** 있는 것만 세우면 칸이 달마다 달라져서 자리를
          // 못 외운다 (2026-09-02 대표 요청).
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8, right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 항목 필터는 **누구에게나** 뜬다 — 본인 기록도 항목별로
                    // 보는 자리다
                    PickFilterButton(
                      stableId: 'contrib-kind',
                      options: kinds,
                      selected: _kind,
                      icon: CupertinoIcons.tag,
                      symbol: 'tag',
                      onSelect: (name) => setState(() => _kind = name),
                    ),
                    if (_canPickPerson) ...[
                      // PhoneDetailScaffold 의 actions 와 같은 간격
                      SizedBox(width: 10),
                      // **사람 버튼이 늘 오른쪽 끝**이다 (환경정비와 같은 자리)
                      PickFilterButton(
                        stableId: 'contrib-person',
                        options: people,
                        selected: _person,
                        onSelect: (name) => setState(() => _person = name),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 아래 떠 있는 글래스 검색바 — 환경정비 전체 내역과 같은 부품이다
          GlassSearchBar(controller: _search, hint: '항목·이름·날짜 검색'),
        ],
      ),
    );
  }
}
