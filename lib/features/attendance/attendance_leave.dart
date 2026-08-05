part of 'attendance_screen.dart';

// ── 월차 ──

/// 남은 월차 카드 — 큰 숫자와 사용량 막대, 그리고 신청 버튼
///
/// 결재할 신청이 밀려 있으면 신청 버튼 자리를 반려·승인이 대신 차지한다
/// ([_LeaveDecideRow]). 승인 화면을 따로 나누지 않기로 했다.
class _LeaveBalance extends StatefulWidget {
  _LeaveBalance({required this.onRequest, required this.onDecided});

  final VoidCallback onRequest;

  /// 승인·반려가 끝나면 화면을 다시 받는다 (달력의 월차 색까지 바뀐다)
  final Future<void> Function() onDecided;

  @override
  State<_LeaveBalance> createState() => _LeaveBalanceState();
}

class _LeaveBalanceState extends State<_LeaveBalance> {
  /// 결재함이 비었을 때 잡아 두는 높이
  ///
  /// 신청 한 건이 들어갔을 때와 같은 값이다 — 신청 줄(아바타·기간·사유 상자)
  /// 89 + 사이 18 + 버튼 40. 다 처리하고 나면 카드가 줄어들어 옆 카드와 어긋난다.
  static const _emptyInboxHeight = 147.0;

  /// 지금 보고 있는 결재 대기 순번
  int _index = 0;

  void _move(int delta) {
    final total = _leaveInbox.length;
    if (total < 2) return;
    setState(
      () => _index = (_index.clamp(0, total - 1) + delta + total) % total,
    );
  }

  Future<void> _approve(LeaveRequest leave) =>
      _run(() => AttendanceApi.approveLeave(leave.id), '승인했어요');

  Future<void> _reject(LeaveRequest leave) async {
    final reason = await askRejectReason(context, hint: '예) 그날은 인원이 모자라요');
    if (reason == null || !mounted) return;
    await _run(() => AttendanceApi.rejectLeave(leave.id, reason), '반려했어요');
  }

  Future<void> _run(Future<LeaveRequest> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      AppToast.show(context, done);
      await widget.onDecided();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = _usedLeave;
    final remaining = _remainingLeave;
    final rate = (used / _grantedLeave).clamp(0.0, 1.0);
    final pending = _leaves
        .where((l) => l.status == _LeaveStatus.pending)
        .length;
    // 처리하고 나면 건수가 줄어드니 볼 순번을 다시 잡는다
    final inbox = _leaveInbox;
    final index = inbox.isEmpty ? 0 : _index.clamp(0, inbox.length - 1);
    final waiting = inbox.isEmpty ? null : inbox[index];

    // 대표는 출퇴근·월차를 쓸 일이 없어서 이 자리를 통째로 결재함으로 쓴다
    if (_isBoss) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('월차 결재', style: AppTextStyles.label),
            SizedBox(height: 16),
            if (waiting == null)
              // 신청이 있을 때와 같은 높이를 잡아 둔다 — 다 처리하고 나면
              // 카드가 쪼그라들어서 옆 카드와 어긋난다
              SizedBox(
                height: _emptyInboxHeight,
                child: Center(
                  child: EmptyCard(
                    icon: CupertinoIcons.tray,
                    text: '들어온 월차 신청이 없어요',
                    framed: false,
                  ),
                ),
              )
            else ...[
              _LeaveDecideRow(
                leave: waiting,
                index: index,
                total: inbox.length,
                onMove: _move,
              ),
              SizedBox(height: 18),
              DecideButtons(
                fill: true,
                onApprove: () => _approve(waiting),
                onReject: () => _reject(waiting),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('남은 월차', style: AppTextStyles.label)),
              // 결재를 기다리는 신청이 있으면 여기서 바로 알려준다
              if (pending > 0)
                Text(
                  '대기 $pending건',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _dayCount(remaining),
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('일', style: AppTextStyles.title3),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_dayCount(used)} / ${_dayCount(_grantedLeave)}일 사용',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.gray100),
                FractionallySizedBox(
                  widthFactor: rate,
                  child: Container(height: 8, color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (waiting != null) ...[
            SizedBox(height: 18),
            Container(height: 1, color: AppColors.divider),
            SizedBox(height: 16),
            _LeaveDecideRow(
              leave: waiting,
              index: index,
              total: inbox.length,
              onMove: _move,
            ),
          ],
          SizedBox(height: 18),
          // 결재할 것이 있으면 신청 버튼 자리를 반려·승인이 대신 쓴다.
          // ADMIN 은 지켜보기만 해서 버튼이 없다 — 그때는 신청 버튼이 남는다
          if (waiting != null && _canDecideLeave)
            DecideButtons(
              fill: true,
              onApprove: () => _approve(waiting),
              onReject: () => _reject(waiting),
            )
          else
            Pressable(
              onTap: widget.onRequest,
              scale: 0.97,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      '월차 신청',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 신청 내역 — 다가오는 순으로 최근 5건만. 나머지는 전체 보기에서
class _LeaveList extends StatelessWidget {
  _LeaveList({
    required this.leaves,
    required this.onCancel,
    required this.onOpenAll,
  });

  final List<_Leave> leaves;
  final ValueChanged<_Leave> onCancel;
  final VoidCallback onOpenAll;

  /// 카드에 보여줄 개수 — 신청이 쌓여도 화면이 길어지지 않게 끊는다
  static const _preview = 5;

  @override
  Widget build(BuildContext context) {
    final recent = leaves.take(_preview).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('신청 내역', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${leaves.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          SizedBox(height: 6),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 24),
              child: Text(
                '아직 신청한 월차가 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _LeaveRow(leave: recent[i], onCancel: () => onCancel(recent[i])),
            ],
        ],
      ),
    );
  }
}

/// 월차 신청 전체 목록 — 상태로 거르고 달별로 묶어 본다
class _LeaveHistoryScreen extends StatefulWidget {
  _LeaveHistoryScreen();

  @override
  State<_LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<_LeaveHistoryScreen> {
  /// 0 전체 · 1 대기 · 2 승인 · 3 반려
  int _filter = 0;

  bool _matches(_Leave leave) => switch (_filter) {
    1 => leave.status == _LeaveStatus.pending,
    2 => leave.status == _LeaveStatus.approved,
    3 => leave.status == _LeaveStatus.rejected,
    _ => true,
  };

  /// 취소는 서버에 알려야 한다 — 이력이 남으므로 목록에서 지우지 않는다
  Future<void> _cancel(_Leave leave) async {
    final id = leave.id;
    if (id == null) return;
    try {
      final cancelled = await AttendanceApi.cancelLeave(id);
      if (!mounted) return;
      setState(() => leave.status = _LeaveStatus.of(cancelled.status));
      AppToast.show(context, '신청을 취소했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _leaves.where(_matches).toList();

    // 달이 바뀌는 지점마다 머리말을 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final leave in sorted) {
      final monthLabel = '${leave.date.year}년 ${leave.date.month}월';
      if (monthLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 20, 4, 6),
            child: Text(
              monthLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = monthLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(_LeaveRow(leave: leave, onCancel: () => _cancel(leave)));
    }

    return PhoneDetailScaffold(
      title: '월차 신청 내역',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          SegmentedTabs(
            labels: ['전체', '대기', '승인', '반려'],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          SizedBox(height: 16),
          if (children.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  '해당하는 신청이 없어요',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: AppDecorations.card(),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  _LeaveRow({required this.leave, required this.onCancel});

  final _Leave leave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            margin: EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: leave.status.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${leave.date.month}.${leave.date.day} '
                      '(${_weekday(leave.date)})',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      leave.kind.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  leave.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: leave.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  leave.status.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: leave.status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 결재가 끝난 건은 되돌릴 수 없다
              if (leave.status == _LeaveStatus.pending) ...[
                SizedBox(height: 4),
                Pressable(
                  onTap: onCancel,
                  scale: 0.94,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '취소',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── 월차 신청 ──

/// 폰은 오른쪽에서 밀려 들어오는 페이지로, 데스크톱은 팝업으로 연다
Future<_Leave?> _showLeaveComposer(BuildContext context) {
  if (!isDesktop) {
    return Navigator.push<_Leave>(
      context,
      CupertinoPageRoute(builder: (_) => _LeaveComposer(phone: true)),
    );
  }
  return showAppDialog<_Leave>(context, (context) => _LeaveComposer());
}

class _LeaveComposer extends StatefulWidget {
  _LeaveComposer({this.phone = false});

  final bool phone;

  @override
  State<_LeaveComposer> createState() => _LeaveComposerState();
}

class _LeaveComposerState extends State<_LeaveComposer> {
  /// 기본값은 내일 — 오늘 쓰는 월차는 드물다
  late DateTime _date = DateTime.now().add(Duration(days: 1));

  _LeaveKind _kind = _LeaveKind.full;

  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => _reason.text.trim().isNotEmpty;

  /// 같은 날에 이미 올린 신청이 있으면 막는다 (여러 날짜리 신청도 걸러야 한다)
  bool get _duplicated =>
      _leaves.any((l) => l.covers(_date) && l.status.counted);

  Future<void> _pickDate() async {
    final picked = await showAppDialog<DateTime>(
      context,
      (context) => _DatePicker(initial: _date),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    if (!_ready) {
      AppToast.show(context, '사유를 입력해주세요');
      return;
    }
    if (_duplicated) {
      AppToast.show(context, '그 날짜에는 이미 신청한 월차가 있어요');
      return;
    }
    if (_kind.days > _remainingLeave) {
      AppToast.show(context, '남은 월차가 모자라요');
      return;
    }
    // 아직 서버에 안 보낸 초안 — 부르는 쪽이 이걸로 신청 요청을 만든다
    Navigator.pop(
      context,
      _Leave(date: _date, kind: _kind, reason: _reason.text.trim()),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('날짜', style: AppTextStyles.label),
        SizedBox(height: 8),
        Pressable(
          onTap: _pickDate,
          scale: 0.99,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_date.year}년 ${_date.month}월 ${_date.day}일 '
                    '(${_weekday(_date)})',
                    style: AppTextStyles.body2,
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.gray400,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Text('종류', style: AppTextStyles.label),
        SizedBox(height: 8),
        SegmentedTabs(
          labels: [for (final kind in _LeaveKind.values) kind.label],
          selected: _LeaveKind.values.indexOf(_kind),
          onSelect: (i) => setState(() => _kind = _LeaveKind.values[i]),
        ),
        SizedBox(height: 8),
        Text(
          '${_dayCount(_kind.days)}일이 차감돼요 · 남은 월차 '
          '${_dayCount(_remainingLeave)}일',
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
        SizedBox(height: 20),
        Text('사유', style: AppTextStyles.label),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _reason,
            style: AppTextStyles.body2,
            cursorColor: AppColors.primary,
            maxLines: 3,
            minLines: 3,
            decoration: InputDecoration(
              hintText: '예) 가족 행사 참석',
              hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phone) {
      return PhoneDetailScaffold(
        title: '월차 신청',
        bottomBar: GlassBottomButton(
          label: '신청하기',
          active: _ready,
          onPressed: _submit,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            GlassBottomButton.inset(context),
          ),
          children: [
            // 입력칸(gray50)이 회색 배경에 묻히지 않게 흰 카드 위에 올린다
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: AppDecorations.card(),
              child: _form(),
            ),
          ],
        ),
      );
    }

    return Container(
      width: dialogWidth(context, 380),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('월차 신청', style: AppTextStyles.title3),
          SizedBox(height: 18),
          _form(),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: _submit,
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ready ? AppColors.primary : AppColors.gray200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '신청하기',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _ready ? Colors.white : AppColors.gray500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 날짜 고르기 ──

/// 앱 톤에 맞춘 달력 팝업
///
/// 머티리얼 기본 달력은 결이 달라서 근태 달력과 같은 모양으로 직접 그린다.
/// 지난 날짜는 고를 수 없다 (월차는 앞으로 쓸 날만 신청한다).
class _DatePicker extends StatefulWidget {
  _DatePicker({required this.initial});

  final DateTime initial;

  @override
  State<_DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<_DatePicker> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _picked = widget.initial;

  /// 오늘 이전으로는 못 넘어간다
  bool get _canGoBack {
    final now = DateTime.now();
    return _month.isAfter(DateTime(now.year, now.month));
  }

  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = _month.weekday % 7;
    final rows = ((lead + lastDay) / 7).ceil();

    return Container(
      width: dialogWidth(context, 340),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _arrow(CupertinoIcons.chevron_left, _canGoBack, () => _move(-1)),
              Expanded(
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title3,
                ),
              ),
              _arrow(CupertinoIcons.chevron_right, true, () => _move(1)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + col - lead + 1;
                        if (dayNumber < 1 || dayNumber > lastDay) {
                          return SizedBox(height: 40);
                        }
                        final date = DateTime(
                          _month.year,
                          _month.month,
                          dayNumber,
                        );
                        return _PickCell(
                          date: date,
                          selected: _sameDay(date, _picked),
                          // 지난 날짜는 흐리게 두고 눌러도 반응하지 않는다
                          enabled: !date.isBefore(today),
                          onTap: () => setState(() => _picked = date),
                        );
                      },
                    ),
                  ),
              ],
            ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context, _picked),
                  scale: 0.97,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '선택',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) => Pressable(
    onTap: enabled ? onTap : () {},
    scale: enabled ? 0.9 : 1,
    child: Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 14,
        color: enabled ? AppColors.textSecondary : AppColors.gray300,
      ),
    ),
  );
}

class _PickCell extends StatelessWidget {
  _PickCell({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sunday = date.weekday == DateTime.sunday;

    return Pressable(
      onTap: enabled ? onTap : () {},
      scale: enabled ? 0.92 : 1,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : !enabled
                    ? AppColors.gray300
                    : sunday
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
