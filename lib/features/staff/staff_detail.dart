part of 'staff_screen.dart';

// ---------------------------------------------------------------------------
// 상세
// ---------------------------------------------------------------------------

/// 직원 한 명 상세 — 연락처와 이번 달 근태 요약
///
/// 근태 요약은 열 때 따로 받는다. 명단과 같이 받으면 인원수만큼 요청이 나간다.
class _MemberDetail extends StatefulWidget {
  _MemberDetail({required this.member});

  final _Member member;

  @override
  State<_MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<_MemberDetail>
    with SkeletonDelay<_MemberDetail> {
  _MonthSummary? _month;

  /// 인사 정보를 바꿨으면 갈아끼운 사람 — 닫을 때 명단으로 돌려준다
  _Member? _edited;

  _Member get member => _edited ?? widget.member;

  /// 남의 근태를 볼 수 있는지 — **본인이거나 MASTER · ADMIN**
  ///
  /// 서버가 `/attendance/calendar`·`/leaves/balance` 를 그 둘에게만 연다
  /// (그 밖에는 403). 지각 횟수는 원래 남이 볼 것도 아니라 앱도 같은 기준으로
  /// 카드를 감춘다.
  ///
  /// **MANAGER 는 뺐다 (2026-08-14).** 결재가 대표 전용이 되면서 점장이
  /// 남의 근태를 볼 자리가 없어졌다 — 월차 결재함·급여 결재 탭과 같은 정리다.
  bool get _canSeeMonth =>
      member.isMe || myRole == Role.master || myRole == Role.admin;

  @override
  void initState() {
    super.initState();
    if (member.active && _canSeeMonth) {
      _loadMonth();
    } else {
      skipFirstSkeleton(); // 카드를 아예 안 그리는 사람이라 받을 것이 없다
    }
  }

  Future<void> _loadMonth() async {
    setState(beginLoad);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    try {
      final days = AttendanceApi.calendar(
        month: month,
        employeeId: member.isMe ? null : member.id,
      );
      final balance = AttendanceApi.balance(
        employeeId: member.isMe ? null : member.id,
      );
      final summary = _MonthSummary.of(await days, await balance);
      if (mounted) setState(() => _month = summary);
    } catch (_) {
      // 권한이 없거나 서버가 못 주면 카드를 안 그린다
    }
    if (mounted) setState(endLoad);
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.show(context, '$label을 복사했어요');
  }

  /// 지점·직군·권한 바꾸기 (MASTER·ADMIN 만)
  Future<void> _manage() async {
    final saved = await showFullPage<Employee>(
      context,
      (_) => _ManageSheet(member: member),
    );
    if (saved == null || !mounted) return;
    _replaceMember(saved);
    setState(() => _edited = _Member(saved));
    AppToast.show(context, '${saved.name}님의 인사 정보를 바꿨어요');
  }

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: member.name,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          _ProfileCard(member: member),
          SizedBox(height: 12),
          Row(
            children: [
              // 아직 합류 전이거나 이미 나간 사람에게는 사내톡을 걸지 않는다
              if (member.active) ...[
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.chat_bubble_fill,
                    label: '사내톡',
                    primary: true,
                    onTap: () => _openChat(context, member),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.phone_fill,
                  label: '번호 복사',
                  onTap: () => _copy(context, '전화번호', member.phone),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.mail_solid,
                  label: '메일 복사',
                  onTap: () => _copy(context, '이메일', member.email),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: '기본 정보',
            // 지점·직군·권한은 남이 정해 주는 값이라 여기서 바꾼다
            // (본인이 바꾸는 이름·전화번호는 프로필 화면이다)
            action: _canManage(member) ? ('인사 정보 변경', _manage) : null,
            rows: [
              ('사번', member.code),
              ('지점', member.branchLabel),
              ('직군', member.role),
              ('권한', member.permission.label),
              ('상태', member.employment.label),
              if (member.joined case final at?) ('가입일', _date(at)),
              if (member.resigned case final at?) ('퇴사일', _date(at)),
              // 아직 한 번도 안 들어온 사람은 그 사실이 보여야 한다 —
              // 계정만 만들어 두고 앱을 안 깐 사람을 여기서 가린다
              if (member.active)
                (
                  '첫 접속일',
                  switch (member.firstLogin) {
                    final at? => _date(at),
                    _ => '없음',
                  },
                ),
              // 서버가 전화번호를 안 채워 주는 사람이 많다 (backend-gap.md 2·46번)
              ('전화번호', member.phone.isEmpty ? '없음' : member.phone),
              ('이메일', member.email),
            ],
          ),
          // 비활성·퇴사자는 이번 달 기록이 없다.
          // 남의 근태는 점장 이상만 본다 ([_canSeeMonth])
          if (member.active && _canSeeMonth) ...[
            SizedBox(height: 12),
            if (_month case final summary?)
              _MonthCard(summary: summary)
            else if (showSkeleton)
              _MonthPlaceholder(),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  _ProfileCard({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          _StatusAvatar(member: member, size: 62),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 옆에 '나' 배지가 붙어서, 안 감싸면 긴 이름이 줄을 넘친다
                    // (다른 목록도 전부 이렇게 쓴다)
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title2,
                      ),
                    ),
                    if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  member.role,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10),
                _StatusLine(member: member),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 가장 자주 쓰는 동작 하나만 파란 면으로
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? Colors.white : AppColors.textPrimary;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? AppColors.primary : AppColors.gray200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  _InfoCard({required this.title, required this.rows, this.action});

  final String title;
  final List<(String, String)> rows;

  /// 머리말 오른쪽에 붙는 글자 버튼 — (이름, 누르면 할 일)
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.label),
              if (action case (final label, final onTap)) ...[
                Spacer(),
                Pressable(
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 6),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(label, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 근태를 받아오는 동안 자리만 잡아 둔다 — 카드가 뒤늦게 끼어들면 화면이 튄다
class _MonthPlaceholder extends StatelessWidget {
  _MonthPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Container(
        height: 106,
        padding: EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Skeleton(width: 34, height: 20),
                    SizedBox(height: 8),
                    Skeleton(width: 44, height: 11),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 이번 달 근태 요약 값 — `/attendance/calendar` 와 `/leaves/balance` 로 만든다
///
/// 판정(정상·지각·결근…)은 **서버가 한 것을 그대로 센다.** 급여·평가가 같은
/// 기준을 쓰므로 앱이 다시 계산하지 않는다.
class _MonthSummary {
  _MonthSummary({
    required this.workedDays,
    required this.workedHours,
    required this.lateCount,
    required this.leaveUsed,
  });

  factory _MonthSummary.of(List<AttendanceDay> days, LeaveBalance balance) {
    var worked = 0;
    var minutes = 0;
    var late = 0;
    for (final day in days) {
      // 출근한 날만 센다 — 휴무·휴가·결근은 근무일이 아니다
      if (day.checkIn != null) worked++;
      minutes += day.workMinutes ?? 0;
      if (day.status == AttendanceStatus.late ||
          day.status == AttendanceStatus.lateAndEarly) {
        late++;
      }
    }
    return _MonthSummary(
      workedDays: worked,
      workedHours: minutes ~/ 60,
      lateCount: late,
      leaveUsed: balance.used,
    );
  }

  final int workedDays;
  final int workedHours;
  final int lateCount;
  final double leaveUsed;
}

/// 이번 달 근태 요약 — 근태·월차 화면의 요약 카드와 같은 눈금
class _MonthCard extends StatelessWidget {
  _MonthCard({required this.summary});

  final _MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 근무',
                  style: AppTextStyles.label,
                ),
              ),
              Text('오늘까지', style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '${summary.workedDays}일', AppColors.textPrimary),
              _divider(),
              _stat('총 근무', '${summary.workedHours}시간', AppColors.primary),
              _divider(),
              _stat(
                '지각',
                '${summary.lateCount}회',
                summary.lateCount > 0
                    ? AppColors.warning
                    : AppColors.textPrimary,
              ),
              _divider(),
              _stat(
                '월차',
                '${_count(summary.leaveUsed)}일',
                AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

/// '2023년 3월 2일'
String _date(DateTime value) => fullDateLabel(value);

/// 소수점이 있을 때만 .5를 보여준다
String _count(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toString();
