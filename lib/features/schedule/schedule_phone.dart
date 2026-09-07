part of 'schedule_screen.dart';

// ── 폰 화면 ──

/// 폰: **한 달 달력 한 장** (2026-09-07 요청). 날짜를 누르면 그날 일정이 열린다.
///
/// 예전에는 한 주를 세로 일곱 줄로 폈다 — 칸이 폭의 7분의 1(약 50)이라 칩에
/// 제목이 몇 글자밖에 안 들어간다는 이유였다. 그런데 한 주씩 넘겨 보느라
/// **이번 달이 어떻게 돌아가는지를 못 봤다.**
///
/// 칸에는 들어가는 만큼만 칩을 세우고 나머지는 `+N` 으로 접는다 ([_DayCell] 이
/// 제 높이를 보고 정한다). 무엇이 있는지는 **날짜를 눌러서** 본다 —
/// 제목·시각·장소·참석자가 다 있는 목록이 뜬다 ([_DayDialog]). PC 달력도 같은
/// 방식이라 두 화면이 같은 결이다.
///
/// **폰에는 일정 탭이 없다** — 홈 왼쪽 위 바로가기로만 들어온다. 그래서
/// 뒤로가기가 있어야 해서 [PhoneDetailScaffold] 를 쓴다
/// (왼쪽 `<` · 가운데 제목 · 오른쪽 `+` — 알림 화면과 같은 머리 모양).
class _SchedulePhone extends StatelessWidget {
  _SchedulePhone({
    required this.month,
    required this.count,
    required this.loading,
    required this.onMove,
    required this.onToday,
    required this.onAdd,
    required this.onPick,
    required this.onScope,
    required this.onPerson,
    required this.personLabel,
  });

  /// 보고 있는 달 (1일)
  final DateTime month;

  /// 그 달에 걸치는 일정 수 — 머리말 옆에 뜬다
  final int count;
  final bool loading;

  /// -1 이면 지난 달, 1 이면 다음 달
  final ValueChanged<int> onMove;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onPick;

  /// 공통 ↔ 개인 목록바 — PC 와 같은 위젯을 쓴다
  final ValueChanged<int> onScope;

  /// 개인 칸에서 사람 고르기 (MASTER·ADMIN 만 버튼이 뜬다)
  final VoidCallback onPerson;
  final String personLabel;

  /// 폰 칸 높이 — 날짜 동그라미(22)와 칩 두 장(21×2)이 들어가는 값.
  ///
  /// 여섯 줄이면 약 480 이라 스크롤 한 번에 달이 다 보인다. 더 키우면 아래
  /// 몇 줄이 화면 밖으로 나가고, 줄이면 칩이 한 장도 못 들어가 `+N` 만 남는다.
  static const _rowHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    final page = PhoneDetailScaffold(
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
                Skeleton(width: 46, height: 12)
              else
                Text('일정 $count', style: AppTextStyles.caption),
              SizedBox(width: 10),
              Pressable(
                onTap: onToday,
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
          SizedBox(height: 12),
          _ScopeBar(
            onScope: onScope,
            onPerson: onPerson,
            personLabel: personLabel,
          ),
          SizedBox(height: 14),
          _WeekdayHeader(),
          // 스크롤 안이라 높이가 무한이다 — 줄 높이를 정해 줘야 한다
          _MonthGrid(
            month: month,
            onPick: onPick,
            skeleton: loading,
            rowHeight: _rowHeight,
          ),
        ],
      ),
    );

    // 뼈대가 뜰 때만 감싼다 (PC 달력과 같은 사정 — 반짝임 컨트롤러를 늘 굴리지 않는다)
    return loading ? SkeletonGroup(child: page) : page;
  }
}
