part of 'schedule_screen.dart';

// ── 하루 일정 ──

/// 날짜 칸을 누르면 뜨는 그날 일정 목록
class _DayDialog extends StatefulWidget {
  _DayDialog({required this.date});

  final DateTime date;

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  Future<void> _add() async {
    final draft = await showEventDialog(context, date: widget.date);
    if (draft == null || !mounted) return;
    try {
      final created = await _createEvent(draft);
      if (!mounted) return;
      setState(() => events.add(created));
      AppToast.show(context, created.pending ? '일정을 신청했어요' : '일정을 추가했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 승인 — 이때부터 전 직원 달력에 뜬다
  Future<void> _approve(Event event) async {
    final id = event.id;
    if (id == null) return;
    try {
      final ok = _fromServer(await EventApi.approve(id));
      if (!mounted) return;
      setState(() {
        final index = events.indexOf(event);
        if (index >= 0) events[index] = ok;
      });
      AppToast.show(context, '승인했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 반려 — **서버가 일정을 지운다.** 되돌릴 게 없어서 목록에서도 뺀다
  Future<void> _reject(Event event, String reason) async {
    final id = event.id;
    try {
      if (id != null) await EventApi.reject(id, reason: reason);
      if (!mounted) return;
      setState(() => events.remove(event));
      AppToast.show(context, '반려했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 줄에서 바로 반려 — 사유를 먼저 묻는다 (폼에서 누르면 폼이 이미 물었다)
  Future<void> _askThenReject(Event event) async {
    final reason = await askRejectReason(context, hint: _rejectHint);
    if (reason == null || !mounted) return;
    await _reject(event, reason);
  }

  Future<void> _edit(Event event) async {
    final edited = await showEventDialog(
      context,
      date: event.date,
      origin: event,
    );
    if (edited == null || !mounted) return;

    final id = event.id;
    try {
      if (edited.deleted) {
        if (id != null) await EventApi.delete(id);
        if (!mounted) return;
        setState(() => events.remove(event));
        AppToast.show(context, '일정을 삭제했어요');
        return;
      }
      if (edited.decision == EventDecision.reject) {
        await _reject(event, edited.rejectReason ?? '');
        return;
      }
      if (edited.decision == EventDecision.approve) {
        await _approve(event);
        return;
      }
      // 서버가 돌려준 값으로 갈아끼운다 — 앱이 계산한 값과 어긋나지 않게
      final saved = id == null ? edited : await _updateEvent(id, edited);
      if (!mounted) return;
      setState(() {
        final index = events.indexOf(event);
        if (index >= 0) events[index] = saved;
      });
      // 아직 안 올린 새 일정은 고칠 것도 없다 (화면 안에서만 바뀐다)
      if (id != null) {
        AppToast.show(context, saved.pending ? '고쳐서 다시 신청했어요' : '일정을 수정했어요');
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final list = eventsOn(date);

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 400,
          padding: EdgeInsets.fromLTRB(24, 22, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${date.month}월 ${date.day}일',
                    style: AppTextStyles.title2,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_weekdays[date.weekday % 7]}요일',
                    style: AppTextStyles.caption,
                  ),
                  Spacer(),
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '이 날은 일정이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  // 일정이 많으면 목록만 스크롤한다
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final event in list)
                          _EventRow(
                            event: event,
                            onTap: () => _edit(event),
                            // 대기 중인 신청은 여기서 바로 결재한다
                            onApprove: event.pending && _canDecide
                                ? () => _approve(event)
                                : null,
                            onReject: event.pending && _canDecide
                                ? () => _askThenReject(event)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 6),
              Pressable(
                onTap: _add,
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      '일정 추가',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 하루 목록의 일정 한 줄
class _EventRow extends StatelessWidget {
  _EventRow({
    required this.event,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  final Event event;
  final VoidCallback onTap;

  /// 대기 중인 신청을 결재할 수 있을 때만 채워진다 (MASTER·ADMIN)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: event.kind.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      [
                        if (event.pending) '승인 대기',
                        event.timeLabel,
                        event.kind.label,
                        if (event.place.isNotEmpty) event.place,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (event.members.isNotEmpty) ...[
                SizedBox(width: 8),
                AvatarStack(names: event.members, size: 22),
              ],
            ],
          ),
          // 옆이 아니라 아래에 둔다 — 장소가 길면 제목·시각이 눌린다
          if (onApprove != null && onReject != null)
            Padding(
              // 왼쪽 16 = 색 띠 4 + 사이 12 → 제목과 줄이 맞는다
              padding: EdgeInsets.only(left: 16, top: 8),
              child: Row(
                children: [
                  // 반려가 왼쪽 — 프로젝트·전자결재·급여와 같은 차례다
                  MiniButton(label: '반려', onTap: onReject!, filled: false),
                  SizedBox(width: 6),
                  MiniButton(label: '승인', onTap: onApprove!, filled: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
