part of 'lesson_section.dart';

/// 세션 기록 전체 화면 — 달을 넘겨 가며 날짜별로 묶어 보여준다
///
/// 싸인은 달마다 따로 받는다. 한 번에 다 받으면 해가 갈수록
/// 화면 열 때마다 몇 백 건씩 넘어온다.
class _SignHistoryScreen extends StatefulWidget {
  @override
  State<_SignHistoryScreen> createState() => _SignHistoryScreenState();
}

class _SignHistoryScreenState extends State<_SignHistoryScreen>
    with SkeletonDelay<_SignHistoryScreen> {
  final _search = TextEditingController();

  late DateTime _month;
  List<SessionSign> _rows = const [];

  /// 0 기록 · 1 유효회원 · 2 마감회원
  ///
  /// **회원의 상태는 등록권이 정한다.** 20회차를 등록하고 20번 싸인을 받으면
  /// 그 등록권은 소진(`exhausted`)이고 그 회원은 마감이다. 재등록하면
  /// 새 등록권이 생겨 다시 유효가 된다 — **지난 기록은 그대로 남는다.**
  int _tab = 0;

  /// 이 화면이 보여줄 회원 — 트레이너는 본인 담당, 대표·관리자는 지점 전체
  List<Member> get _members {
    final store = _LessonStore.instance;
    if (_viewOnly) return store.members;
    return [
      for (final m in store.members)
        if (m.ownerTrainerId == currentUser?.id) m,
    ];
  }

  /// 갈래에 맞는 회원 — 트레이너 필터와 이름 검색까지 걸어서 준다
  List<Member> get _shownMembers {
    final store = _LessonStore.instance;
    final query = _search.text.trim();
    final wantDone = _tab == 2;
    return [
      for (final m in _members)
        // 회원은 달과 무관한 **지금 상태**라 담당 트레이너로 거른다
        if (_trainerId == null || m.ownerTrainerId == _trainerId)
          if (query.isEmpty || m.name.contains(query))
            if ((store.currentRegistrationOf(m.id)?.exhausted ?? false) ==
                wantDone)
              m,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 고른 트레이너 — null 이면 전체
  ///
  /// **대표·관리자에게만 있다.** 트레이너·점장은 서버가 본인 것만 주므로
  /// 골라도 바뀌는 게 없다 (지점 고르개와 같은 규칙).
  ///
  /// 서버에 다시 묻지 않고 **받아 둔 목록에서 거른다** — 달마다 한 번만
  /// 받으면 되고 트레이너를 바꿀 때 기다릴 일이 없다.
  String? _trainerId;

  /// 고를 수 있는 트레이너 — 이름순
  ///
  /// 명단 전체가 아니라 **이 화면에 이름이 있는 사람만** 세운다. 이 달 싸인을
  /// 한 사람과 회원을 맡고 있는 사람을 **합쳐서** 세운다 — 갈래를 옮길 때마다
  /// 메뉴가 늘었다 줄었다 하면 고른 사람이 목록에서 사라진다.
  List<({String id, String name})> get _trainers {
    final names = <String, String>{};
    void add(String id) =>
        names[id] ??= StaffDirectory.instance.byId(id)?.name ?? '알 수 없음';
    for (final sign in _rows) {
      add(sign.performedByTrainerId);
    }
    for (final member in _members) {
      add(member.ownerTrainerId);
    }
    return [for (final e in names.entries) (id: e.key, name: e.value)]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _search.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose(); // 뼈대 타이머는 SkeletonDelay 가 걷는다
  }

  /// 다음 달로 못 넘어간다 — 아직 오지 않은 달이라 볼 게 없다
  bool get _atLatest {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _fetch() async {
    final asked = _month;
    setState(beginLoad);
    try {
      final rows = await SessionSignApi.list(
        // **본 화면(`_LessonStore.load`)과 같은 규칙이다.** 예전에는 여기만
        // 본인으로 못 박혀 있어서, 대표·관리자가 카드에 `세션 기록 18` 을
        // 보고 전체보기를 열면 0건이었다 (자기 싸인이 없으니까).
        trainerId: _viewOnly ? null : currentUser?.id,
        period: periodKey(_month),
        // 헤더에서 고른 지점도 따라가야 한다 — 이것도 빠져 있었다
        branchId: branchScopeId,
      );
      // 기다리는 사이 또 넘겼으면 이 응답은 버린다 — 늦게 온 옛 달이
      // 새 달을 덮어쓰면 머리말과 목록이 어긋난다
      if (!mounted || _month != asked) return;
      setState(() {
        _rows = _LessonStore.instance.sorted(rows);
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad); // 실패해도 뼈대에 갇히지 않게 푼다
      AppToast.show(context, messageOf(error));
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _fetch();
  }

  /// 유효·마감 회원 목록 — 아바타 · 이름 · 남은 회차
  Widget _memberList() {
    final rows = _shownMembers;
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
        child: Text(
          _search.text.trim().isNotEmpty
              ? '검색 결과가 없어요'
              : _tab == 1
              ? '회차가 남은 회원이 없어요'
              : '마감된 회원이 없어요',
          style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
        ),
      );
    }
    return ListView.separated(
      key: ValueKey('member-$_tab'),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.paddingOf(context).bottom + 96,
      ),
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) => _MemberStateRow(
        member: rows[i],
        registration: _LessonStore.instance.currentRegistrationOf(rows[i].id),
        showTrainer: _viewOnly,
      ),
    );
  }

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) => dayLabel(time);

  @override
  Widget build(BuildContext context) {
    final all = _rows;
    final query = _search.text.trim();
    final sorted = all
        .where(
          (s) => _trainerId == null || s.performedByTrainerId == _trainerId,
        )
        .where((s) => query.isEmpty || s.displayName.contains(query))
        .toList();

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final sign in sorted) {
      final dayLabel = _dayLabel(sign.signedAt);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _SignRow(sign: sign, onTap: () => _showSignDetail(context, sign)),
      );
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
                  _MonthBar(
                    month: _month,
                    // 지금 아래에 서 있는 것을 센다 — 회원 갈래에서 싸인
                    // 건수를 세면 목록과 숫자가 어긋난다
                    count: _tab == 0 ? sorted.length : _shownMembers.length,
                    loading: showSkeleton,
                    onPrev: () => _shiftMonth(-1),
                    // 아직 오지 않은 달은 볼 게 없으니 막는다
                    onNext: _atLatest ? null : () => _shiftMonth(1),
                  ),
                  Container(height: 1, color: AppColors.gray100),
                  // 기록 / 유효회원 / 마감회원 — 같은 달을 세 갈래로 본다.
                  // 회원 갈래는 **지금 상태**라 달과 무관하지만, 들어오는 문이
                  // 여기 하나뿐이라 같이 둔다 (2026-08-14 대표 요청).
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: SegmentedTabs(
                      labels: const ['기록', '유효회원', '마감회원'],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  ),
                  if (_tab != 0)
                    Expanded(child: _memberList())
                  else if (showSkeleton)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: SkeletonRows(rows: 5, trailing: 56),
                    )
                  else if (sorted.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                      child: Text(
                        all.isEmpty ? '이 달에 받은 싸인이 없어요' : '검색 결과가 없어요',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        // 달이 바뀌면 맨 위부터 다시 본다
                        key: ValueKey(_month),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          // 하단 글래스 검색 바에 가리지 않도록 여유를 둔다
                          MediaQuery.paddingOf(context).bottom + 96,
                        ),
                        children: children,
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
                  child: Text('세션 기록', style: AppTextStyles.title3),
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
          // 우측 상단 트레이너 필터 — **대표·관리자에게만.** 뒤로가기와
          // 마주 보는 자리다. 하단 검색바(블러)와는 Stack 의 다른 자식이라
          // 네이티브 버튼이 묻히지 않는다
          if (_viewOnly)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: _TrainerFilterButton(
                    trainers: _trainers,
                    selected: _trainerId,
                    onSelect: (id) => setState(() => _trainerId = id),
                  ),
                ),
              ),
            ),
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
        ],
      ),
    );
  }
}

/// 트레이너 고르개 — 세션 기록 오른쪽 위의 **리퀴드 글래스 필터**
///
/// **대표·관리자에게만 뜬다.** 트레이너·점장은 서버가 본인 기록만 주므로
/// 골라도 바뀌는 게 없다 (지점 고르개와 같은 규칙).
///
/// 메뉴는 지점 고르개(`BranchScopeButton`)·랭킹 직군 필터와 같은 부품이다 —
/// 아이폰은 OS 가 그리는 네이티브 메뉴, 그 외는 [showGlassMenu].
class _TrainerFilterButton extends StatefulWidget {
  _TrainerFilterButton({
    required this.trainers,
    required this.selected,
    required this.onSelect,
  });

  /// 이 달 기록에 이름이 있는 트레이너 (이름순)
  final List<({String id, String name})> trainers;

  /// null 이면 '전체'
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<_TrainerFilterButton> createState() => _TrainerFilterButtonState();
}

class _TrainerFilterButtonState extends State<_TrainerFilterButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  static const _allLabel = '전체';

  /// 걸려 있으면 채운 아이콘 — 버튼이 아이콘 하나라 고른 사람 **이름**은
  /// 메뉴를 열어야 보인다. 최소한 "지금 걸려 있다"는 건 알 수 있게 한다.
  String get _symbol => widget.selected == null
      ? 'line.3.horizontal.decrease'
      : 'line.3.horizontal.decrease.circle.fill';

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final trainers = widget.trainers;
    final picked = await showGlassMenu<int>(
      context: context,
      anchorKey: _key,
      width: 200,
      items: [
        GlassMenuItem(
          // null 은 '안 골랐다'와 구분이 안 돼서 전체에 따로 값을 준다
          value: -1,
          label: _allLabel,
          icon: CupertinoIcons.square_grid_2x2,
          selected: widget.selected == null,
        ),
        for (var i = 0; i < trainers.length; i++)
          GlassMenuItem(
            value: i,
            label: trainers[i].name,
            icon: CupertinoIcons.person,
            selected: widget.selected == trainers[i].id,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked == -1 ? null : trainers[picked].id);
  }

  @override
  Widget build(BuildContext context) {
    final trainers = widget.trainers;
    // 아이폰은 OS 가 그리는 네이티브 메뉴. **macOS 는 안 쓴다** — 같은 패키지가
    // 메뉴를 버튼 왼쪽에 고정해서 창 밖으로 새어 나간다 (지점 고르개와 같은 이유).
    if (isApple && !isDesktop) {
      return CNPopupMenuButton.icon(
        // 테마가 바뀌면 새로 만든다 (패키지의 setBrightness 가 아이콘을 유실).
        // **고른 사람은 키에 안 넣는다** — 넣으면 고를 때마다 뷰를 새로 만든다.
        key: ValueKey('lesson-trainer-${AppColors.isDark}'),
        buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
        size: 40,
        items: [
          // 네이티브 메뉴에는 체크마크를 못 단다 — 고른 줄은 **아이콘 자리**가
          // 체크로 바뀐다
          CNPopupMenuItem(
            label: _allLabel,
            icon: CNSymbol(
              widget.selected == null ? 'checkmark' : 'square.grid.2x2',
            ),
          ),
          for (final trainer in trainers)
            CNPopupMenuItem(
              label: trainer.name,
              icon: CNSymbol(
                widget.selected == trainer.id ? 'checkmark' : 'person',
              ),
            ),
        ],
        onSelected: (index) =>
            widget.onSelect(index == 0 ? null : trainers[index - 1].id),
      );
    }

    return GlassIconButton(
      key: _key,
      // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
      stableId: 'lesson-trainer',
      symbol: _symbol,
      onPressed: _openMenu,
    );
  }
}

/// 회원 한 줄 — 유효·마감 목록에 선다
///
/// 세션 기록 줄([_SignRow])과 **같은 결**이다 (아바타 36 · 이름 · 오른쪽 회차).
/// 다른 것은 왼쪽이 기록이 아니라 사람이고, 오른쪽이 `12/20회차` 로 지금
/// 상태를 말한다는 것뿐이다.
class _MemberStateRow extends StatelessWidget {
  _MemberStateRow({
    required this.member,
    required this.registration,
    required this.showTrainer,
  });

  final Member member;

  /// 지금 쓰는 등록권 — 한 번도 등록 안 한 회원이면 null
  final Registration? registration;

  /// 담당 트레이너를 같이 보여줄지 — 대표·관리자만
  final bool showTrainer;

  @override
  Widget build(BuildContext context) {
    final done = registration?.exhausted ?? false;
    final total = registration?.totalSessions ?? 0;
    final used = registration?.usedSessions ?? 0;
    final trainer =
        StaffDirectory.instance.byId(member.ownerTrainerId)?.name ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Avatar(name: member.name, size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showTrainer && trainer.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    trainer,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            registration == null ? '등록 없음' : '$used/$total회차',
            style: AppTextStyles.body2.copyWith(
              // 마감은 물러나고, 남은 회차가 있는 쪽이 눈에 든다
              color: done ? AppColors.textTertiary : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
