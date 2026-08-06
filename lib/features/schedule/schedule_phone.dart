part of 'schedule_screen.dart';

// ── 폰 화면 ──

/// 폰 달력 칸 높이 — 날짜 동그라미 22 + 여백 + 일정 칩 두 줄
///
/// 데스크톱은 칸이 화면 높이를 나눠 갖지만(`Expanded`), 폰은 스크롤 안이라
/// 높이가 무한이라 못 나눈다. 칸이 스스로 높이를 정해야 한다.
/// 칩은 하나가 19라 두 줄까지 들어가고 나머지는 `+N` 으로 접힌다.
const _phoneCellHeight = 78.0;

/// 폰: 달 달력 한 장. 날짜를 누르면 그날 일정이 열린다.
///
/// **폰에는 일정 탭이 없다** — 홈 왼쪽 위 바로가기로만 들어온다. 그래서
/// 뒤로가기가 있어야 해서 [PhoneDetailScaffold] 를 쓴다
/// (왼쪽 `<` · 가운데 제목 · 오른쪽 `+` — 알림 화면과 같은 머리 모양).
class _SchedulePhone extends StatelessWidget {
  _SchedulePhone({
    required this.month,
    required this.loading,
    required this.onMove,
    required this.onToday,
    required this.onAdd,
    required this.onPick,
  });

  final DateTime month;
  final bool loading;
  final ValueChanged<int> onMove;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // 그 달 1일이 낀 주의 일요일부터 채운다 (데스크톱과 같은 셈)
    final first = month.subtract(Duration(days: month.weekday % 7));
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = ((last.difference(first).inDays + 1) / 7).ceil();
    final count = events
        .where((e) => !e.date.isAfter(last) && !e.until.isBefore(month))
        .length;

    return PhoneDetailScaffold(
      title: '일정',
      actions: [GlassIconButton(symbol: 'plus', onPressed: onAdd)],
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMove(-1),
              ),
              SizedBox(width: 6),
              Text(
                '${month.year}년 ${month.month}월',
                style: AppTextStyles.title3,
              ),
              SizedBox(width: 6),
              _RoundButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMove(1),
              ),
              Spacer(),
              // 받아오는 중에는 개수를 감춘다 — 0에서 튀어 오르는 게 보인다
              if (loading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.gray400),
                  ),
                )
              else
                Text('일정 $count', style: AppTextStyles.caption),
              SizedBox(width: 10),
              Pressable(
                onTap: onToday,
                scale: 0.95,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(100),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  '오늘',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: i == 0
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var w = 0; w < weeks; w++)
                  Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          // 칸이 스스로 높이를 못 정해서 여기서 준다 —
                          // 안 주면 칸 안의 Expanded 가 무한 높이에서 터진다
                          child: SizedBox(
                            height: _phoneCellHeight,
                            child: _DayCell(
                              date: first.add(Duration(days: w * 7 + d)),
                              month: month.month,
                              lastWeek: w == weeks - 1,
                              lastColumn: d == 6,
                              onTap: onPick,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
