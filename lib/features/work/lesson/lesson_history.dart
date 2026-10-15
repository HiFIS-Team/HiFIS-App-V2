part of 'lesson_section.dart';

/// 세션 기록 전체 화면 — **하루씩** 넘겨 본다 (2026-10-15 점장 요청)
///
/// 예전에는 한 달을 통째로 나열해서 오늘 한 수업을 보려면 한참 내려가야 했다.
/// 가운데 날짜를 누르면 달력에서 골라 바로 간다.
///
/// 받는 것은 여전히 **달 단위다** — 날을 넘길 때마다 서버를 부르지 않고,
/// 받아 둔 그달 기록에서 그날 것만 거른다. 달이 바뀔 때만 다시 받는다.
class _SignHistoryScreen extends StatefulWidget {
  _SignHistoryScreen({this.trainerId});

  /// 처음부터 걸러 둘 트레이너 — 대표가 명단에서 사람을 눌러 들어올 때
  final String? trainerId;

  @override
  State<_SignHistoryScreen> createState() => _SignHistoryScreenState();
}

class _SignHistoryScreenState extends State<_SignHistoryScreen>
    with SkeletonDelay<_SignHistoryScreen> {
  final _search = TextEditingController();

  /// 보고 있는 날 (자정)
  late DateTime _day;
  List<SessionSign> _rows = const [];

  /// 받아 둔 기록의 달 — [_day] 가 이 달을 벗어나면 다시 받는다
  DateTime get _month => DateTime(_day.year, _day.month);

  /// 0 최근 기록 · 1 유효회원 · 2 마감회원
  ///
  /// **셋 다 그달 싸인 기록을 보여준다** (2026-09-27 대표 요청). 예전에는 회원
  /// 갈래가 이름·회차만 세웠는데, 기록처럼 서명 줄로 보여야 한다고 해서 같은
  /// 줄을 **회원의 지금 상태로 거른다.**
  ///
  /// **회원의 상태는 등록권이 정한다.** 20회차를 등록하고 20번 싸인을 받으면
  /// 그 등록권은 소진(`exhausted`)이고 그 회원은 마감이다. 재등록하면
  /// 새 등록권이 생겨 다시 유효가 된다 — **지난 기록은 그대로 남는다.**
  int _tab = 0;

  /// 이 화면이 보여줄 회원 — 트레이너는 본인 담당, 그 위는 지점 전체
  List<Member> get _members {
    final store = _LessonStore.instance;
    if (_canSeeOthers) return store.members;
    return [
      for (final m in store.members)
        if (m.ownerTrainerId == currentUser?.id) m,
    ];
  }

  /// 마감 갈래인가 — 등록권이 있는데 남은 게 없다 (등록 없는 회원은 유효 쪽)
  static bool _finished(MemberPass pass) => pass.exists && !pass.active;

  /// 고른 트레이너 — null 이면 전체
  ///
  /// **대표·관리자·점장에게만 있다.** 트레이너는 서버가 본인 것만 주므로
  /// 골라도 바뀌는 게 없다 (지점 고르개와 같은 규칙).
  ///
  /// 서버에 다시 묻지 않고 **받아 둔 목록에서 거른다** — 달마다 한 번만
  /// 받으면 되고 트레이너를 바꿀 때 기다릴 일이 없다.
  late String? _trainerId = widget.trainerId;

  /// 고를 수 있는 트레이너 — **명단을 다 세운다**
  ///
  /// 환경정비 사람 필터와 같은 규칙이다 (2026-09-01 대표 지적). 화면에 이름이
  /// 있는 사람만 세우면 **고른 사람이 달을 넘기는 순간 메뉴에서 사라져서
  /// 필터를 풀 수도 없다.** "이 트레이너가 지난달에 몇 개 했나"는 0건인 달을
  /// 지나가야 닿는 자리다.
  ///
  /// 세우는 사람
  /// - 보고 있는 지점의 **재직 중인 현장 인원** (MANAGER·MEMBER)
  /// - 거기 없어도 **이 달 싸인을 했거나 회원을 맡고 있는 사람** — 나갔거나
  ///   지점을 옮겨도 그때 남긴 기록은 걸러 볼 수 있어야 한다
  ///
  /// MASTER·ADMIN 은 뺀다. 서버가 `POST /session-signs` 를 안 받아서
  /// (backend-gap 24번) 골라 봐야 늘 0건이다.
  List<({String id, String name})> get _trainers {
    final names = <String, String>{};
    for (final employee in StaffDirectory.instance.employees) {
      if (!employee.role.doesFieldWork) continue;
      if (employee.status != EmployeeStatus.active) continue;
      // 대표·관리자가 전 지점을 볼 때만 null 이라 안 가린다 ([rosterBranchId])
      final branch = rosterBranchId;
      if (branch != null && employee.branchId != branch) continue;
      names[employee.id] = employee.name;
    }
    void add(String id) =>
        names[id] ??= StaffDirectory.instance.byId(id)?.name ?? '알 수 없음';
    for (final sign in _rows) {
      add(sign.performedByTrainerId);
    }
    for (final member in _members) {
      add(member.ownerTrainerId);
    }
    // 앱 공통 차례 (지점 → 직급 → 이름)
    return [for (final e in names.entries) (id: e.key, name: e.value)]..sort(
      (a, b) =>
          StaffDirectory.instance.compareStaffIds(a.id, b.id, a.name, b.name),
    );
  }

  @override
  void initState() {
    super.initState();
    _day = _today;
    _search.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose(); // 뼈대 타이머는 SkeletonDelay 가 걷는다
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 다음 날로 못 넘어간다 — 아직 오지 않은 날이라 볼 게 없다
  bool get _atLatest => !_day.isBefore(_today);

  Future<void> _fetch() async {
    final asked = _month;
    setState(beginLoad);
    try {
      final rows = await SessionSignApi.list(
        // **이 화면만 지점 전체를 받는다.** 본 화면(`_LessonStore.load`)은
        // 점장에게도 본인 것만 준다 — 거기는 '내 세션'을 세는 자리다.
        // 여기는 기록을 훑는 자리라 오른쪽 위 필터로 사람을 골라 본다.
        trainerId: _canSeeOthers ? null : currentUser?.id,
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

  /// 날을 옮긴다 — 달이 바뀔 때만 다시 받는다
  void _goTo(DateTime day) {
    final monthBefore = _month;
    setState(() => _day = DateTime(day.year, day.month, day.day));
    if (_month != monthBefore) _fetch();
  }

  Future<void> _pickDay() async {
    final picked = await pickDate(
      context,
      initial: _day,
      first: DateTime(_today.year - 3),
      last: _today,
      title: '날짜',
    );
    if (picked != null && mounted) _goTo(picked);
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// `2026년 10월 11일 (토)`
  String get _dayTitle =>
      '${_day.year}년 ${_day.month}월 ${_day.day}일 (${_weekdays[_day.weekday - 1]})';

  @override
  Widget build(BuildContext context) {
    final all = _rows;
    final query = _search.text.trim();
    final sorted = all
        .where(
          (s) =>
              s.signedAt.year == _day.year &&
              s.signedAt.month == _day.month &&
              s.signedAt.day == _day.day,
        )
        .where(
          (s) => _trainerId == null || s.performedByTrainerId == _trainerId,
        )
        .where((s) => query.isEmpty || s.displayName.contains(query))
        // 회원 갈래 — 그 회원의 **지금 상태**로 거른다
        .where(
          (s) =>
              _tab == 0 ||
              _finished(_LessonStore.instance.passOf(s.memberId)) ==
                  (_tab == 2),
        )
        .toList();

    // 하루치라 날짜 머리말은 없다 — 위 날짜 줄이 그 일을 한다
    final children = <Widget>[];
    for (final sign in sorted) {
      if (children.isNotEmpty) {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _SignRow(
          sign: sign,
          // 점장도 지점 전체를 보므로 누구 것인지가 있어야 한다
          showTrainer: _canSeeOthers,
          onTap: () => _showSignDetail(context, sign),
        ),
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
                  MonthBar(
                    month: _month,
                    // 지금 아래에 서 있는 것을 센다 — 회원 갈래에서 싸인
                    // 건수를 세면 목록과 숫자가 어긋난다
                    count: sorted.length,
                    loading: showSkeleton,
                    label: _dayTitle,
                    onTapLabel: _pickDay,
                    onPrev: () =>
                        _goTo(DateTime(_day.year, _day.month, _day.day - 1)),
                    // 아직 오지 않은 날은 볼 게 없으니 막는다
                    onNext: _atLatest
                        ? null
                        : () => _goTo(
                            DateTime(_day.year, _day.month, _day.day + 1),
                          ),
                  ),
                  Container(height: 1, color: AppColors.gray100),
                  // 기록 / 유효회원 / 마감회원 — 같은 달을 세 갈래로 본다.
                  // 회원 갈래는 **지금 상태**라 달과 무관하지만, 들어오는 문이
                  // 여기 하나뿐이라 같이 둔다 (2026-08-14 대표 요청).
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: SegmentedTabs(
                      labels: const ['최근 기록', '유효회원', '마감회원'],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  ),
                  if (showSkeleton)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: SkeletonRows(rows: 5, trailing: 56),
                    )
                  else if (sorted.isEmpty)
                    // 업무 화면의 '아직 받은 싸인이 없어요' 와 같은 카드
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: EmptyCard(
                        icon: Icons.draw_rounded,
                        text: query.isNotEmpty
                            ? '검색 결과가 없어요'
                            : _tab == 1
                            ? '이 날 유효 회원의 싸인이 없어요'
                            : _tab == 2
                            ? '이 날 마감 회원의 싸인이 없어요'
                            : '이 날 받은 싸인이 없어요',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        // 날이 바뀌면 맨 위부터 다시 본다
                        key: ValueKey('$_day-$_tab'),
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
          // 우측 상단 트레이너 필터 — **대표·관리자·점장에게만.** 뒤로가기와
          // 마주 보는 자리다. 하단 검색바(블러)와는 Stack 의 다른 자식이라
          // 네이티브 버튼이 묻히지 않는다
          //
          // **직원 카드를 눌러 들어왔으면 안 띄운다** (2026-10-15 요청) — 이미
          // 그 사람으로 걸러 들어온 화면이라 다른 사람으로 바꿀 일이 없다.
          // 사람을 바꿔 보려면 전체보기로 들어온다
          if (_canSeeOthers && widget.trainerId == null)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: PickFilterButton(
                    stableId: 'lesson-trainer',
                    options: _trainers,
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
