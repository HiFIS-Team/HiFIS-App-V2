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

  /// 목록이 **실제로 담고 있는** 날짜 — [_date] 보다 한 박자 늦게 따라온다
  ///
  /// 받아 오는 동안 목록을 비우면 **내용 → 빈 화면 → 내용** 이 되어 깜빡인다.
  /// 그래서 옛 목록을 그대로 둔 채 새 것을 기다렸다가, 도착하면
  /// [PaneTransition] 으로 갈아 끼운다 (탭을 옮길 때와 같은 모션).
  late DateTime _shownDate = _WorkScreenState._todayDate();

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _isToday => _date == _WorkScreenState._todayDate();

  /// 목록에 담긴 날이 오늘인가 — 빈 문구는 **보이는 목록**을 따라가야 한다
  bool get _shownIsToday => _shownDate == _WorkScreenState._todayDate();

  /// 날짜를 옮기고 그 날 기록을 받아 온다 — **다음 날로는 못 간다**
  Future<void> _move(int step) async {
    final next = DateTime(_date.year, _date.month, _date.day + step);
    if (next.isAfter(_WorkScreenState._todayDate())) return;
    // 머리말은 바로 바꾼다 — 누른 티가 나야 한다. 목록은 도착하면 바뀐다
    setState(() => _date = next);
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
        _shownDate = next;
      });
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 날짜 좌우 화살표 — 근태 달력·랭킹과 **같은 모양**이다.
  /// [onTap] 이 null 이면 흐린 채로 안 눌린다 (자리는 그대로 둔다).
  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final box = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 13,
        color: onTap == null ? AppColors.gray300 : AppColors.textSecondary,
      ),
    );
    return onTap == null
        ? box
        : Pressable(onTap: onTap, scale: 0.9, child: box);
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
                      _arrow(CupertinoIcons.chevron_left, () => _move(-1)),
                      SizedBox(width: 10),
                      Text(date, style: AppTextStyles.caption),
                      SizedBox(width: 10),
                      // 다음 날은 아직 안 왔으니 늘 비어 있다 — 흐려 두고 안 눌리게
                      _arrow(
                        CupertinoIcons.chevron_right,
                        _isToday ? null : () => _move(1),
                      ),
                      Spacer(),
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
                // 날짜가 바뀌면 목록이 **떠 있는 채로** 새 것으로 넘어간다 —
                // 탭을 옮길 때와 같은 모션이다 (비웠다가 채우면 깜빡인다)
                Expanded(
                  child: PaneTransition(
                    step: _shownDate,
                    child: sorted.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                              child: Text(
                                // 문구는 **보이는 목록**을 따라간다 (_date 가 아니다)
                                _shownIsToday
                                    ? (_all
                                          ? '오늘 완료된 항목이 없어요'
                                          : '오늘 완료한 항목이 없어요')
                                    : (_all ? '완료된 항목이 없어요' : '완료한 항목이 없어요'),
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            // 날짜·탭이 바뀌면 맨 위부터 다시 본다
                            key: ValueKey('$_all-$_shownDate'),
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
