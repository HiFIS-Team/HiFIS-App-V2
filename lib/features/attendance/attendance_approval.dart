part of 'attendance_screen.dart';

// ---------------------------------------------------------------------------
// 월차 승인 — 직원이 낸 휴가 신청을 받아 승인·반려한다
//
// 화면을 따로 나누지 않고 '쓴 월차' 카드 안에서 바로 처리한다.
// 대기 중인 신청이 있으면 '월차 신청' 버튼 자리를 반려·승인이 대신 차지한다.
//
// 서버 권한을 그대로 따른다:
//   조회   MASTER · ADMIN   (ADMIN 은 보기만 — 버튼이 없다)
//   처리   MASTER
// ---------------------------------------------------------------------------

/// 결재 대기를 볼 수 있는 사람 — **MASTER · ADMIN**
///
/// **MANAGER 는 뺐다 (2026-08-14).** 점장도 본인이 월차를 내는 쪽이지
/// 받는 쪽이 아니다. 결재가 대표 전용이 되면서 점장에게는 누를 수 없는
/// 목록만 남았는데, 거기에 **남의 휴가 사유**가 그대로 적혀 있었다.
///
/// 이 값이 false 면 대기 목록을 아예 안 받아서(`attendance_models.dart`)
/// 화면이 직원과 똑같아진다 — 결재 줄도 없고 월차 신청 버튼이 그대로다.
bool get _canSeeLeaveInbox => _isBoss;

/// 실제로 승인·반려를 누를 수 있는 사람 — **MASTER 만**
bool get _canDecideLeave => myRole.canApprove;

/// 근태 화면을 **관리 화면으로** 보는 사람 (MASTER · ADMIN)
///
/// 이 사람들은 출퇴근을 안 찍어서 본인 기록이 늘 비어 있다. 그래서
/// 달 요약 자리에 오늘 전 직원 현황, 쓴 월차 자리에 월차 결재,
/// 달력 칸에 그날 전 직원 기록이 들어간다.
/// MANAGER 는 본인도 현장 근무를 해서 예전 화면 그대로다.
bool get _isBoss => myRole == Role.master || myRole == Role.admin;

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
    child: Padding(
      padding: EdgeInsets.all(5),
      child: Icon(icon, size: 12, color: AppColors.textTertiary),
    ),
  );
}
