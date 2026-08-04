part of 'attendance_screen.dart';

// ---------------------------------------------------------------------------
// 월차 승인 — 직원이 낸 휴가 신청을 받아 승인·반려한다
//
// 화면을 따로 나누지 않고 '남은 월차' 카드 안에서 바로 처리한다.
// 대기 중인 신청이 있으면 '월차 신청' 버튼 자리를 반려·승인이 대신 차지한다.
//
// 서버 권한을 그대로 따른다:
//   조회   MASTER · ADMIN · MANAGER   (MANAGER 는 서버가 자기 지점으로 좁힌다)
//   처리   MASTER · MANAGER           (ADMIN 은 지켜보는 자리라 버튼이 없다)
// ---------------------------------------------------------------------------

/// 결재 대기를 볼 수 있는 사람
bool get _canSeeLeaveInbox =>
    myRole == Role.master || myRole == Role.admin || myRole == Role.manager;

/// 실제로 승인·반려를 누를 수 있는 사람
bool get _canDecideLeave => myRole.canApprove;

/// 결재 대기 한 건 — 누가 · 언제 · 어떤 휴가 · 사유
///
/// [_LeaveBalance] 카드 안에 들어간다. 여러 건이 밀려 있으면
/// 오른쪽 끝의 `1/2` 로 하나씩 넘겨 본다.
class _LeaveDecideRow extends StatelessWidget {
  _LeaveDecideRow({
    required this.leave,
    required this.index,
    required this.total,
    required this.onMove,
  });

  final LeaveRequest leave;

  /// 지금 보고 있는 순번 (0부터)
  final int index;
  final int total;

  /// -1 이면 앞 건, 1 이면 뒷 건
  final ValueChanged<int> onMove;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(name: _name, size: 34),
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
                    '$_period · ${kind.label} · ${_dayCount(leave.days)}일',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            // 한 건뿐이면 셈이 필요 없다
            if (total > 1) ...[
              SizedBox(width: 8),
              _arrow(CupertinoIcons.chevron_left, () => onMove(-1)),
              Text(
                '${index + 1}/$total',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              _arrow(CupertinoIcons.chevron_right, () => onMove(1)),
            ],
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
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Padding(
      padding: EdgeInsets.all(5),
      child: Icon(icon, size: 12, color: AppColors.textTertiary),
    ),
  );
}
