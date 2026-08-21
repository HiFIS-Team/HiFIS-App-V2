part of 'home_screen.dart';

class _GreetingCard extends StatelessWidget {
  _GreetingCard();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  /// 지금 시간에 맞는 인사말
  ///
  /// **시간만 본다.** 오늘 근태로 가르면 출퇴근을 안 찍는 대표·관리자가
  /// 늘 '출근 전' 으로 잡혀서 종일 아침 인사가 뜬다.
  ///
  /// 화면을 다시 그릴 때마다 새로 셈한다 — 홈에 머무는 동안 시간이 넘어가면
  /// 다음 그리기에서 저절로 바뀐다.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return '늦은 시간까지 고생이 많아요 🌙';
    if (hour < 11) return '좋은 아침이에요 👋';
    if (hour < 14) return '점심 드셨나요 🍚';
    if (hour < 18) return '오후도 힘내요 ☀️';
    if (hour < 22) return '오늘도 고생하셨어요 🌙';
    return '늦은 시간까지 고생이 많아요 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_todayLabel, style: AppTextStyles.caption),
          SizedBox(height: 4),
          Text(_greeting, style: AppTextStyles.title1),
          // 이름에만 브랜드 그라데이션 포인트
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppColors.primary, AppColors.violet],
            ).createShader(bounds),
            child: Text('$me님', style: AppTextStyles.title1),
          ),
        ],
      ),
    );
  }
}

/// 결재 대기 — 대표·관리자 홈 왼쪽 카드 (근무 카드 자리)
///
/// 급여·월차·전자결재가 **한 목록으로** 선다. 셋을 따로 받아 합치면 홈에서만
/// 요청이 세 개 더 나가서 서버(`/me/inbox`)가 합쳐 준다.
///
/// **ADMIN 은 버튼이 없다.** 지켜보는 자리라 목록은 같이 보되 승인·반려는
/// MASTER 만 누른다 (급여·월차 결재 화면과 같은 기준 — 눌러도 403 날 버튼은 안 낸다).
class _InboxCard extends StatefulWidget {
  _InboxCard({this.onOpen}) : full = false;

  /// 전체보기 — 같은 State 를 **화면 한 장으로** 그린다
  ///
  /// 승인·반려는 종류마다 부르는 곳이 달라서(`_approve`·`_reject`) 복사해
  /// 두면 한쪽만 고쳐질 때 **엉뚱한 결재가 통과한다.** 그래서 카드와 화면이
  /// 같은 State 를 쓰고 [full] 로 그리는 모양만 가른다.
  _InboxCard.full() : onOpen = null, full = true;

  final void Function(NotificationTarget)? onOpen;

  /// true 면 카드가 아니라 밀려 들어오는 화면으로 그린다
  final bool full;

  @override
  State<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<_InboxCard> with SkeletonDelay<_InboxCard> {
  List<InboxItem> _items = const [];

  /// 보고 있는 칸 — **카드는 늘 `대기` 다.** 전체보기에서만 목록바로 바뀐다.
  InboxStatus _status = InboxStatus.pending;

  /// 처리 중인 항목 id — 그 줄의 버튼만 잠근다
  ///
  /// 목록을 다시 받을 때까지 줄이 그대로 남아 있어서, 안 잠그면 같은 결재를
  /// 두 번 보내고 두 번째가 400 으로 떨어진다.
  String? _busyId;

  /// 카드에 세우는 줄 수 — 데스크톱은 나란히 선 프로젝트 카드와 맞추고,
  /// 폰은 네 장을 같게 맞춘다. **전체보기 화면에서는 안 자른다.**
  int get _max => widget.full ? _items.length : (isDesktop ? 4 : phoneCardRows);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final asked = _status;
    try {
      final rows = await HomeApi.inbox(status: asked);
      // 받는 동안 다른 칸을 눌렀으면 버린다 — 안 그러면 늦게 온 응답이
      // 지금 보고 있는 칸을 덮어쓴다
      if (!mounted || asked != _status) return;
      setState(() {
        _items = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted || asked != _status) return;
      setState(endLoad); // 실패해도 뼈대에 갇히지 않게 푼다
      AppToast.show(context, messageOf(error));
    }
  }

  /// 목록바에서 칸을 옮긴다 — 칸마다 서버에 다시 묻는다
  ///
  /// 세 칸을 미리 다 받아 두면 화면을 열 때 요청이 셋으로 는다.
  /// 처리된 것은 열어 보는 일이 드물어서 누를 때만 받는다.
  ///
  /// **줄은 안 지운다.** 지우면 10ms 만에 새 줄이 와도 그 사이가 빈 화면이라
  /// 깜빡인다 — 옛 줄을 그대로 두고 오는 대로 갈아끼운다.
  void _pick(InboxStatus status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      beginLoad();
    });
    _load();
  }

  /// 버튼을 낼지 — **MASTER 만 낸다.**
  ///
  /// 예전에는 일정만 ADMIN 에게도 냈다. 서버가 일정 결재를
  /// `_DECIDERS = (MASTER, ADMIN)` 으로 열어 둬서 눌리기는 했다.
  /// 그런데 같은 카드 안에서 급여·월차 줄에는 버튼이 없고 일정 줄에만 있어
  /// **왜 어떤 건 되고 어떤 건 안 되는지 알 수 없었다.**
  /// 결재는 대표가 판단하는 자리라 ADMIN 은 지켜보기만 한다
  /// (`/me/inbox` docstring 에 서버도 그렇게 적어 뒀다).
  ///
  /// MANAGER 는 애초에 이 카드를 못 본다 — `/me/inbox` 가 ADMIN 게이트라
  /// 403 이고, 홈도 MASTER·ADMIN 에게만 카드를 그린다.
  ///
  /// **처리된 칸에서는 아무도 못 낸다** — 이미 끝난 결재라 누를 것이 없다.
  ///
  /// 칸을 옮기는 동안(`loading`)도 안 낸다. 그때는 **옛 칸의 줄이 아직 떠
  /// 있어서**, 승인 칸에서 대기로 옮기자마자 누르면 이미 승인된 것을 다시
  /// 보내 400 이 난다.
  bool get _canDecide =>
      myRole == Role.master && _status == InboxStatus.pending && !loading;

  /// 종류마다 부르는 곳이 다르다 — id 는 그 테이블의 것이다
  Future<void> _approve(InboxItem item) => _run(item, () async {
    switch (item.kind) {
      case InboxKind.payslip:
        await PayrollApi.approve(item.id);
      case InboxKind.leave:
        await AttendanceApi.approveLeave(item.id);
      case InboxKind.approval:
        await ApprovalApi.approve(item.id);
      case InboxKind.event:
        await EventApi.approve(item.id);
      case InboxKind.myTask:
        await MyTaskApi.approve(item.id);
      case InboxKind.project:
        await ProjectApi.approve(item.id);
    }
  }, '승인했어요');

  Future<void> _reject(InboxItem item) async {
    final reason = await askRejectReason(
      context,
      hint: switch (item.kind) {
        InboxKind.payslip => '예) 추가 근무 시간이 기록과 달라요',
        InboxKind.leave => '예) 그날은 인원이 모자라요',
        InboxKind.approval => '예) 금액 근거를 더 적어주세요',
        InboxKind.event => '예) 그날은 이미 다른 행사가 있어요',
        InboxKind.myTask => '예) 그 업무는 계속 해야 해요',
        InboxKind.project => '예) 그 기한이면 다음 달 일정과 겹쳐요',
      },
    );
    if (reason == null || !mounted) return;
    await _run(item, () async {
      switch (item.kind) {
        case InboxKind.payslip:
          await PayrollApi.reject(item.id, reason);
        case InboxKind.leave:
          await AttendanceApi.rejectLeave(item.id, reason);
        case InboxKind.approval:
          await ApprovalApi.reject(item.id, comment: reason);
        case InboxKind.event:
          await EventApi.reject(item.id, reason: reason);
        case InboxKind.myTask:
          await MyTaskApi.reject(item.id, reason);
        case InboxKind.project:
          await ProjectApi.reject(item.id, reason: reason);
      }
    }, '반려했어요');
  }

  /// 처리하고 목록을 다시 받는다 — 한 건만 빼면 다른 기기에서 바뀐 게 안 맞는다
  Future<void> _run(
    InboxItem item,
    Future<void> Function() action,
    String done,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = item.id);
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// 전체보기 — **결재만 모은 화면**을 연다
  ///
  /// 예전에는 제일 많은 종류의 탭으로 보냈다. 그러면 급여 3건·월차 2건일 때
  /// 급여 탭으로 가는데 **월차 2건은 거기 없어서** 나머지를 찾아 헤맸고,
  /// 폰은 전자결재·일정 탭이 아예 없어 그게 제일 많으면 **버튼이 사라졌다.**
  /// 지금은 네 종류가 한 목록에 그대로 서므로 어디로 보낼지 고를 일이 없다.
  void _openAll() => showFullPage<void>(context, (_) => _InboxCard.full());

  @override
  Widget build(BuildContext context) {
    final shown = _items.take(_max).toList();
    final rows = [
      for (final item in shown)
        _InboxRow(
          item: item,
          busy: _busyId == item.id,
          onApprove: _canDecide ? () => _approve(item) : null,
          onReject: _canDecide ? () => _reject(item) : null,
        ),
    ];

    // 줄이 없을 때(로딩·빈 결재함)는 안내를 **세로 가운데**에 놓는다.
    // 데스크톱은 옆 카드에 높이를 맞추느라 카드가 늘어나는데, 안내가 위에
    // 붙으면 아래가 휑하다. `centered` 가 true 면 남는 높이를 다 쓴다.
    final Widget body;
    final bool centered = showSkeleton || rows.isEmpty;
    if (showSkeleton) {
      body = SkeletonGroup(child: SkeletonRows(rows: 3, trailing: 56));
    } else if (rows.isEmpty) {
      // 결재함이 비었다는 뜻이라 월차·급여 결재함과 같은 쟁반 아이콘을 쓴다
      body = Center(
        child: EmptyCard(
          icon: CupertinoIcons.tray,
          text: '결재할 게 없어요',
          framed: false,
        ),
      );
    } else {
      body = _StackedRows(rows: rows);
    }

    // 전체보기 — 카드가 아니라 밀려 들어오는 화면 한 장으로 그린다.
    // 줄·승인·반려는 위에서 만든 것을 그대로 쓴다 (카드와 같은 State).
    if (widget.full) {
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
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: _InboxTabs(selected: _status, onSelect: _pick),
                  ),
                  if (showSkeleton)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: SkeletonGroup(
                        child: SkeletonRows(
                          rows: 5,
                          // 줄 간격을 실제 목록과 맞춘다 (위아래 14 + 구분선)
                          gap: 29,
                          // 처리된 칸에는 승인·반려 버튼이 없다.
                          // `_canDecide` 는 받는 중에 false 라 여기 못 쓴다
                          trailing:
                              myRole == Role.master &&
                                  _status == InboxStatus.pending
                              ? 56
                              : 0,
                        ),
                      ),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, 44),
                      child: Text(
                        switch (_status) {
                          InboxStatus.pending => '결재할 게 없어요',
                          InboxStatus.approved => '승인한 결재가 없어요',
                          InboxStatus.rejected => '반려한 결재가 없어요',
                        },
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        // 카드는 줄 사이를 14 로 띄우는데(`_StackedRows`) 여기는
                        // 구분선이 있어 위아래로 나눠 준다 — 안 주면 글자가
                        // 선에 붙어 목록이 빽빽해 보인다
                        itemBuilder: (_, index) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: rows[index],
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
                  // 카드는 '결재 대기' 지만 여기는 승인·반려 칸도 있어서 '결재' 다
                  child: Center(child: Text('결재', style: AppTextStyles.title3)),
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

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '결재 대기',
            count: _items.length,
            // **대기가 0이어도 낸다.** 전체보기에 `대기 · 승인 · 반려` 목록바가
            // 붙은 뒤로는 열어 볼 것이 있다 — 오늘 처리를 다 끝낸 사람이
            // 방금 승인한 것을 되짚을 길이 여기뿐이다.
            // (예전에는 전체보기가 대기 목록 하나라 비면 빈 화면이었다)
            onOpenAll: _openAll,
          ),
          SizedBox(height: 14),
          // `Expanded` 는 Column 의 **직계 자식**이어야 해서 여기서 바로 감싼다
          // (위젯으로 빼면 Flex 가 못 알아본다).
          // 폰은 스크롤 안이라 높이가 무한이라 못 쓴다 — 대신 세 줄 높이를 잡아
          // 카드가 줄어들지 않게만 한다.
          if (isDesktop && centered)
            Expanded(child: body)
          else if (isDesktop)
            body
          else
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: phoneCardBody),
              child: body,
            ),
        ],
      ),
    );
  }
}

/// 결재 전체보기의 목록바 — `대기 · 승인 · 반려`
///
/// **전자결재 폰 목록바(`_StateTabs`)와 같은 토큰**을 쓴다. 같은 결재를
/// 다루는 두 화면이라 결이 다르면 바로 눈에 띈다.
/// 공용 [SegmentedTabs] 는 높이가 48 이고 고른 칸 글자가 파랑이라 안 쓴다.
class _InboxTabs extends StatelessWidget {
  _InboxTabs({required this.selected, required this.onSelect});

  final InboxStatus selected;
  final ValueChanged<InboxStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          for (final status in InboxStatus.values)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(status),
                scale: 0.97,
                // 배경은 애니메이션 없이 즉시 바꾼다
                child: Container(
                  decoration: segmentFill(selected: status == selected),
                  child: Center(
                    child: Text(
                      status.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: status == selected
                            ? AppColors.primary
                            : AppColors.gray600,
                        fontWeight: status == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  _InboxRow({
    required this.item,
    this.busy = false,
    this.onApprove,
    this.onReject,
  });

  final InboxItem item;

  /// 이 줄을 처리하는 중 — 버튼이 안 눌린다
  final bool busy;

  /// null 이면 버튼을 안 그린다 (ADMIN)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String get _name =>
      StaffDirectory.instance.byId(item.employeeId)?.name ?? '알 수 없음';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(name: _name, size: 34),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),
              Text(
                item.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        // 반려가 왼쪽 — 프로젝트·전자결재·급여와 같은 차례다
        if (onApprove != null && onReject != null) ...[
          SizedBox(width: 8),
          MiniButton(label: '반려', onTap: onReject!, filled: false, busy: busy),
          SizedBox(width: 6),
          MiniButton(label: '승인', onTap: onApprove!, filled: true, busy: busy),
        ],
      ],
    );
  }
}
