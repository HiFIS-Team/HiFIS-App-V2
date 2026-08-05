part of 'attendance_screen.dart';

// ── 날짜 상세 ──

/// 달력에서 날짜를 누르면 뜨는 창 — 그날의 출퇴근과 월차
///
/// 대표는 자기 기록이 아니라 **그날 누가 어땠는지**를 본다. 달력 칸은 좁아서
/// `외 N명` 으로 줄이는데, 여기서는 이름을 다 편다.
class _DayDialog extends StatelessWidget {
  _DayDialog({required this.date, required this.day, required this.leave});

  final DateTime date;
  final _Day? day;
  final _Leave? leave;

  @override
  Widget build(BuildContext context) {
    final record = day;

    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${date.month}월 ${date.day}일 (${_weekday(date)})',
                  style: AppTextStyles.title3,
                ),
              ),
              // 대표 창은 전 직원 판이라 본인 알약을 달면 헷갈린다
              if (record != null && !_isBoss)
                _StatusChip(status: record.status),
            ],
          ),
          SizedBox(height: 18),
          if (_isBoss)
            _roster()
          else if (record != null && record.checkIn != null) ...[
            Row(
              children: [
                _cell('출근', _clock(record.checkIn)),
                Container(width: 1, height: 34, color: AppColors.gray100),
                _cell('퇴근', _clock(record.checkOut)),
                Container(width: 1, height: 34, color: AppColors.gray100),
                _cell('근무', _duration(record.worked)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '출근부터 퇴근까지의 시간이에요',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ] else
            _empty(),
          if (!_isBoss && leave != null) ...[
            SizedBox(height: 16),
            Container(height: 1, color: AppColors.divider),
            SizedBox(height: 14),
            Row(
              children: [
                Text('월차', style: AppTextStyles.label),
                SizedBox(width: 8),
                Text(
                  leave!.kind.label,
                  style: AppTextStyles.body2.copyWith(fontSize: 13),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: leave!.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    leave!.status.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: leave!.status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              leave!.reason,
              style: AppTextStyles.body2.copyWith(fontSize: 13, height: 1.5),
            ),
          ],
          SizedBox(height: 18),
          Pressable(
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
                '닫기',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value, style: AppTextStyles.title3.copyWith(fontSize: 16)),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  /// 대표가 보는 그날 판 — 상태 알약 + 그 상태였던 사람 이름 전부
  Widget _roster() {
    final groups = _rosterOf(date);
    final rows = <Widget>[];
    for (final (status, label, color, _) in _workStatusOrder) {
      final names = groups[status];
      if (names == null || names.isEmpty) continue;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  names.join(' · '),
                  style: AppTextStyles.body2.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) return _empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }

  Widget _empty() {
    final text = _isBoss
        ? '아직 기록이 없어요'
        : switch (day?.status) {
            _DayStatus.off => '쉬는 날이에요',
            _DayStatus.absent => '출근 기록이 없어요',
            _DayStatus.leave => '월차를 쓴 날이에요',
            _ => leave != null ? '월차가 잡혀 있어요' : '아직 기록이 없어요',
          };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.body2.copyWith(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 상태 알약 (정상·지각·결근·월차·휴무)
class _StatusChip extends StatelessWidget {
  _StatusChip({required this.status});

  final _DayStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
