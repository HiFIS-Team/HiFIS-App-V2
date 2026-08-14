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
  });

  final String title;
  final List<EnvTaskLog> logs;
  final bool showName;
  final String emptyText;

  /// 카드에는 다섯 줄만 보이므로 나머지는 모달에서 본다
  final VoidCallback onOpenAll;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final _scrollController = ScrollController();

  /// 한 줄 높이(위아래 여백 13 + 본문 22.5)에 구분선을 더한 다섯 줄 높이.
  /// 기록이 적어도 이 높이를 유지해 좌우 카드가 같은 크기로 보인다.
  static const _listHeight = 5 * 48.5 + 4;

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
    this.initialAll = false,
    this.tabs = true,
  });

  /// 열 때 받은 **오늘** 기록 — 날짜를 옮기기 전까지는 이걸 그대로 쓴다
  final List<EnvTaskLog> myLogs;
  final List<EnvTaskLog> allLogs;

  /// 날짜를 옮길 때 다시 받을 지점 (null 이면 전 지점)
  final String? branchId;

  /// 어느 쪽으로 열지 (데스크톱은 누른 카드에 맞춰 연다)
  final bool initialAll;

  /// 내 내역·전체 내역 전환 탭을 보여줄지
  final bool tabs;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
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

  /// 뼈대를 **실제로 그릴지** — 세션 기록과 같은 규칙 (2026-08-14)
  ///
  /// 받는 동안은 목록도 건수도 뼈대로 둔다. 다만 서버가 가까우면 값이 10ms
  /// 안에 와서, 그때마다 뼈대를 깔았다 지우면 한두 프레임만 떴다 사라져
  /// **오히려 깜빡인다** — [DelayedSpinner] 가 이미 같은 사정으로 220ms 를
  /// 두고 있어서 **그 값을 그대로 쓴다.**
  ///
  /// 이 화면은 열 때 부모가 오늘 기록을 이미 넘겨줘서 false 로 시작한다
  /// (세션 기록은 스스로 받아 와서 true 로 시작한다).
  bool _showSkeleton = false;

  Timer? _skeletonTimer;

  /// 받기 시작 — 220ms 를 넘기면 그때 뼈대로 바꾼다
  void _beginLoad() {
    _skeletonTimer?.cancel();
    _skeletonTimer = Timer(DelayedSpinner.delay, () {
      if (mounted) setState(() => _showSkeleton = true);
    });
  }

  /// 다 받았다(또는 실패) — 뼈대를 걷고 예약도 취소한다
  void _endLoad() {
    _skeletonTimer?.cancel();
    _showSkeleton = false;
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _isToday => _date == _WorkScreenState._todayDate();

  /// 날짜를 옮기고 그 날 기록을 받아 온다 — **다음 날로는 못 간다**
  Future<void> _move(int step) async {
    final next = DateTime(_date.year, _date.month, _date.day + step);
    if (next.isAfter(_WorkScreenState._todayDate())) return;
    setState(() {
      _date = next;
      _beginLoad();
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
        _endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(_endLoad); // 실패해도 뼈대에 갇히지 않게 푼다
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
      scale: enabled ? 0.9 : 1,
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
    final logs = _all ? _allLogs : _myLogs;
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
                        if (_showSkeleton)
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
                    Row(
                      children: [
                        Expanded(
                          child: _WorkTab(
                            label: '내 내역',
                            selected: !_all,
                            expand: true,
                            onTap: () => setState(() => _all = false),
                          ),
                        ),
                        Expanded(
                          child: _WorkTab(
                            label: '전체 내역',
                            selected: _all,
                            expand: true,
                            onTap: () => setState(() => _all = true),
                          ),
                        ),
                      ],
                    ),
                  Container(height: 1, color: AppColors.gray100),
                  if (_showSkeleton)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: SkeletonRows(rows: 5, avatar: 0, trailing: 40),
                    )
                  else if (sorted.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                      child: Text(
                        _isToday
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
                        padding: EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          MediaQuery.paddingOf(context).bottom + 24,
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
        ],
      ),
    );
  }
}
