part of 'attendance_screen.dart';

// ---------------------------------------------------------------------------
// 월차 승인 — 직원이 낸 휴가 신청을 받아 승인·반려한다
//
// 서버 권한을 그대로 따른다:
//   조회   MASTER · ADMIN · MANAGER   (MANAGER 는 서버가 자기 지점으로 좁힌다)
//   처리   MASTER · MANAGER           (ADMIN 은 지켜보는 자리라 버튼이 없다)
// ---------------------------------------------------------------------------

/// 승인 탭을 볼 수 있는 사람
bool get _canSeeLeaveInbox =>
    myRole == Role.master || myRole == Role.admin || myRole == Role.manager;

/// 실제로 승인·반려를 누를 수 있는 사람
bool get _canDecideLeave => myRole.canApprove;

/// 월차 승인함 — 대기 · 처리 내역
class _LeaveInbox extends StatefulWidget {
  _LeaveInbox();

  @override
  State<_LeaveInbox> createState() => _LeaveInboxState();
}

class _LeaveInboxState extends State<_LeaveInbox> {
  bool _loading = true;

  /// 결재를 기다리는 신청
  List<LeaveRequest> _waiting = const [];

  /// 승인·반려까지 끝난 것 (취소는 신청자가 물린 거라 뺀다)
  List<LeaveRequest> _done = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 전원 것을 받아 상태로 가른다 — 지점 제한은 서버가 건다
      final all = await AttendanceApi.leaves();
      if (!mounted) return;
      setState(() {
        _waiting = [
          for (final leave in all)
            if (leave.status == LeaveStatus.pending) leave,
        ];
        _done = [
          for (final leave in all)
            if (leave.status == LeaveStatus.approved ||
                leave.status == LeaveStatus.rejected)
              leave,
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _approve(LeaveRequest leave) async {
    await _run(() => AttendanceApi.approveLeave(leave.id), '승인했어요');
  }

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
      await _load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    if (_waiting.isEmpty && _done.isEmpty) {
      return EmptyCard(icon: CupertinoIcons.tray, text: '들어온 월차 신청이 없어요');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_waiting.isNotEmpty) ...[
          _LeaveInboxGroup(
            title: '승인 대기',
            count: _waiting.length,
            children: [
              for (final leave in _waiting)
                _LeaveInboxRow(
                  leave: leave,
                  onApprove: _canDecideLeave ? () => _approve(leave) : null,
                  onReject: _canDecideLeave ? () => _reject(leave) : null,
                ),
            ],
          ),
          SizedBox(height: 12),
        ],
        if (_done.isNotEmpty)
          _LeaveInboxGroup(
            title: '처리 내역',
            count: _done.length,
            children: [for (final leave in _done) _LeaveInboxRow(leave: leave)],
          ),
      ],
    );
  }
}

/// 반려 사유 — 신청자에게 알림으로 그대로 간다

/// 함 하나 — 제목 · 건수 · 줄들
class _LeaveInboxGroup extends StatelessWidget {
  _LeaveInboxGroup({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '$count',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 4),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 신청 한 건 — 누가 · 언제 · 어떤 휴가 · 사유
class _LeaveInboxRow extends StatelessWidget {
  _LeaveInboxRow({required this.leave, this.onApprove, this.onReject});

  final LeaveRequest leave;

  /// null 이면 버튼을 안 그린다 (ADMIN 이거나 이미 처리된 것)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String get _name =>
      StaffDirectory.instance.byId(leave.employeeId)?.name ?? '알 수 없음';

  /// '8월 12일' · 여러 날이면 '8월 12일 ~ 8월 14일'
  String get _period {
    final start = '${leave.startDate.month}월 ${leave.startDate.day}일';
    if (_sameDay(leave.startDate, leave.endDate)) return start;
    return '$start ~ ${leave.endDate.month}월 ${leave.endDate.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final kind = _LeaveKind.of(leave.type, leave.halfPeriod);
    final status = _LeaveStatus.of(leave.status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: _name, size: 36),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$_period · ${kind.label}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_dayCount(leave.days)}일',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  // 월차 목록과 같은 알약 (근태 달력의 _StatusChip 과는 다른 값이다)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      status.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((leave.reason ?? '').isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(leave.reason!, style: AppTextStyles.caption),
            ),
          ],
          if ((leave.rejectReason ?? '').isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '반려 사유 · ${leave.rejectReason}',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (onApprove != null || onReject != null) ...[
            SizedBox(height: 12),
            // 전자결재 화면과 같은 모양 — 반려는 테두리만, 승인은 채운다
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null) ...[
                  _LeaveDecideButton(
                    label: '반려',
                    color: AppColors.error,
                    onTap: onReject!,
                  ),
                  SizedBox(width: 8),
                ],
                if (onApprove != null)
                  _LeaveDecideButton(
                    label: '승인',
                    filled: true,
                    onTap: onApprove!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 승인·반려 버튼 — 전자결재 화면과 같은 모양
class _LeaveDecideButton extends StatelessWidget {
  _LeaveDecideButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: filled ? 22 : 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: filled ? null : Border.all(color: AppColors.gray200),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: filled ? Colors.white : (color ?? AppColors.textSecondary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
