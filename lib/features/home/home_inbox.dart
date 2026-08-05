part of 'home_screen.dart';

class _GreetingCard extends StatelessWidget {
  _GreetingCard();

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
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
          Text('좋은 아침이에요 👋', style: AppTextStyles.title1),
          // 이름에만 브랜드 그라데이션 포인트
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppColors.primary, Color(0xFF7C5CFC)],
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
  _InboxCard({this.onOpen});

  final void Function(NotificationTarget)? onOpen;

  @override
  State<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<_InboxCard> {
  List<InboxItem> _items = const [];
  bool _loading = true;

  /// 데스크톱은 나란히 선 프로젝트 카드와 줄 수를 맞춘다
  static const _max = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await HomeApi.inbox();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
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
  bool get _canDecide => myRole == Role.master;

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
      }
    }, '반려했어요');
  }

  /// 처리하고 목록을 다시 받는다 — 한 건만 빼면 다른 기기에서 바뀐 게 안 맞는다
  Future<void> _run(
    InboxItem item,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// '전체'는 종류가 섞여 있어 한 화면으로 못 보낸다 — 제일 많은 쪽으로 보낸다
  VoidCallback? get _openAll {
    if (_items.isEmpty || widget.onOpen == null) return null;
    final counts = <InboxKind, int>{};
    for (final item in _items) {
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final target = switch (top) {
      InboxKind.payslip => NotificationTarget.salary,
      InboxKind.leave => NotificationTarget.attendance,
      InboxKind.approval => NotificationTarget.approval,
      InboxKind.event => NotificationTarget.schedule,
    };
    // 전자결재·일정은 폰에 탭이 아예 없다
    if (!isDesktop &&
        (target == NotificationTarget.approval ||
            target == NotificationTarget.schedule)) {
      return null;
    }
    return () => widget.onOpen!.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _items.take(_max).toList();
    final rows = [
      for (final item in shown)
        _InboxRow(
          item: item,
          onApprove: _canDecide ? () => _approve(item) : null,
          onReject: _canDecide ? () => _reject(item) : null,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '결재 대기',
            count: _items.length,
            onOpenAll: _openAll,
          ),
          SizedBox(height: 14),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  '결재할 게 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            // 줄 간격은 늘 14로 둔다. 남는 높이를 나눠 가지면(spaceBetween)
            // 승인·반려로 줄이 줄었을 때 두 줄이 카드 위아래로 갈라진다.
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 14),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  _InboxRow({required this.item, this.onApprove, this.onReject});

  final InboxItem item;

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
        if (onApprove != null && onReject != null) ...[
          SizedBox(width: 8),
          MiniButton(label: '승인', onTap: onApprove!, filled: true),
          SizedBox(width: 6),
          MiniButton(label: '반려', onTap: onReject!, filled: false),
        ],
      ],
    );
  }
}
