part of 'project_screen.dart';

/// 프로젝트 점수 카드 — **완료된 프로젝트에만, MASTER 에게만** 보인다
///
/// 기한 연장 결재가 있던 자리를 그대로 쓴다. 완료된 뒤에는 결재할 연장이 없고,
/// 대신 여기서 점수를 매긴다.
///
/// **적는 값은 참여자 기준이고 PM 은 5점을 더 받는다** (2026-09-16).
/// 완료 기본 점수가 PM 10 · 참여자 5 로 5 차이라, 그 차이를 그대로 잇는다.
/// 매긴 값이 **최종 점수**다 (더해지지 않는다).
///
/// **깎지는 못한다.** 예전에는 -100 까지 줄 수 있었는데, 점수만 깎고
/// 프로젝트는 완료로 둔 채 넘어가면 **못 한 일이 끝난 일로 남는다.**
/// 깎는 것은 리셋(`_askReset`)으로 옮겼다 — 거기는 기한과 체크를 처음으로
/// 되돌리고 다시 시키는 자리다.
class _AwardCard extends StatefulWidget {
  _AwardCard({required this.project});

  final _Project project;

  @override
  State<_AwardCard> createState() => _AwardCardState();
}

class _AwardCardState extends State<_AwardCard> {
  List<ProjectAward> _awards = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.project.id;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await ProjectApi.awards(id);
      if (!mounted) return;
      setState(() {
        _awards = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 대표가 매긴 점수 (전원 같은 값이라 한 건만 봐도 된다).
  /// null 이면 아직 완료 자동 점수(PM 10 · 참여 5)만 붙어 있다
  ProjectAward? get _given => _awards.where((a) => a.byPerson).firstOrNull;

  Future<void> _give() async {
    final id = widget.project.id;
    if (id == null) return;
    final result = await _askAward(context, widget.project, _given);
    if (result == null || !mounted) return;
    try {
      final saved = await ProjectApi.award(
        id,
        points: result.$1,
        comment: result.$2,
      );
      if (!mounted) return;
      setState(() => _awards = saved);
      AppToast.show(context, '참여자 ${saved.length}명에게 점수를 매겼어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final given = _given;
    final people = widget.project.members.length;
    // **목록이 이미 들고 있는 값으로 자리를 잡는다** (2026-09-16 대표 보고).
    //
    // 이 카드는 제 몫으로 한 번 더 받아오는데(`ProjectApi.awards`), 그동안
    // 카드 모양이 달라서 **들어갈 때 글자가 움직였다 제자리로 왔다** —
    // `불러오는 중` 이 실제 점수로 바뀌며 폭이 변하고, 매긴 날짜 줄이
    // 뒤늦게 생기며 카드가 한 줄 자랐다.
    //
    // `awardedPoints` 는 **대표가 매긴 점수**라 여기 `_given` 과 같은 값이다
    // (자동 점수는 안 담긴다 — `_Project.awardedPoints`). 점수·날짜 줄 유무·
    // 버튼 글자를 받기 전에 다 알 수 있어서, 바뀌는 것은 사유 한 줄뿐이다.
    final known = widget.project.awardedPoints;
    final scored = _loading ? known != null : given != null;
    final points = given?.points ?? known ?? _autoPoints;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좁은 화면에서는 제목과 점수가 아래로 접힌다
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              '프로젝트 점수',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '참여자 $people명 · $points점',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w600,
                color: points < 0 && scored
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        // 사유는 받기 전에는 알 수 없는 유일한 값이다. 매긴 것이 있는데
        // `완료해서 붙은 기본 점수예요` 를 띄우면 **틀린 말이 잠깐 걸린다**
        if (_loading && scored)
          SizedBox(
            height: 22,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 150, height: 14),
            ),
          )
        else
          Text(
            given?.comment ?? '완료해서 붙은 기본 점수예요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        // 매긴 날짜 — **줄 자체는 받기 전에도 세운다.** 뒤늦게 생기면
        // 카드가 한 줄 자라면서 아래가 통째로 밀린다
        if (scored) ...[
          SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: given == null
                  ? Skeleton(width: 64, height: 11)
                  : Text(
                      '${_relative(given.createdAt)} 매김',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
            ),
          ),
        ],
      ],
    );

    final button = Pressable(
      onTap: _loading ? _ignore : _give,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          scored ? '다시 주기' : '점수 주기',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final icon = Icon(
      Icons.workspace_premium_rounded,
      size: 18,
      color: AppColors.success,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      // 폰은 버튼을 옆에 두면 내용이 눌려서 아래로 내린다 (연장 카드와 같다)
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                SizedBox(width: 10),
                Expanded(child: info),
                SizedBox(width: 12),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    SizedBox(width: 10),
                    Expanded(child: info),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(width: double.infinity, child: button),
              ],
            ),
    );
  }

  static void _ignore() {}
}

/// 점수 입력창의 출발값 — 담당자(PM) 몫과 같은 값이다 (서버 `PROJECT_POINTS`).
///
/// 참여 멤버는 완료 때 5점(`PROJECT_MEMBER_POINTS`)이 붙지만, 여기서 매기는
/// 것은 **전원 같은 값**이라 둘 중 하나를 골라야 한다. 대표가 손대는 자리는
/// 보통 "더 줄까"라서 높은 쪽을 놓는다.
/// 완료하면 저절로 붙는 점수 — **참여자 기준이다** (PM 은 5점 더)
const _autoPoints = 5;

/// PM 이 참여자보다 더 받는 몫 — 서버 `PM_POINT_GAP` 과 같은 값이다
const _pmGap = 5;

/// 점수와 사유를 받는다 — 취소하면 null
Future<(int, String)?> _askAward(
  BuildContext context,
  _Project project,
  ProjectAward? current,
) {
  final points = TextEditingController(
    text: '${current?.points ?? _autoPoints}',
  );
  final reason = TextEditingController(text: current?.comment ?? '');
  // 검증에 걸린 칸으로 커서를 옮긴다 (다른 폼들과 같은 방식)
  final pointsFocus = FocusNode();
  final reasonFocus = FocusNode();

  return showAppDialog<(int, String)>(
    context,
    (context) => Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프로젝트 점수', style: AppTextStyles.title3),
          SizedBox(height: 4),
          Text(
            '참여자 ${project.members.length}명에게 같이 들어가요 · '
            'PM 은 +$_pmGap점 (0 ~ 100)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 14),
          _AwardField(
            controller: points,
            focusNode: pointsFocus,
            hint: '점수',
            number: true,
          ),
          SizedBox(height: 8),
          _AwardField(
            controller: reason,
            focusNode: reasonFocus,
            hint: '사유 (필수)',
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Spacer(),
              Pressable(
                onTap: () => Navigator.pop(context),
                // 다른 팝업의 취소와 같은 여백 (전자결재·프로젝트·일정)
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Text(
                  '취소',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 6),
              Pressable(
                onTap: () {
                  final value = int.tryParse(points.text.trim());
                  if (value == null || value < 0 || value > 100) {
                    AppToast.show(context, '0 부터 100 까지 적어주세요');
                    pointsFocus.requestFocus();
                    return;
                  }
                  final text = reason.text.trim();
                  if (text.isEmpty) {
                    AppToast.show(context, '점수 사유를 적어주세요');
                    reasonFocus.requestFocus();
                    return;
                  }
                  Navigator.pop(context, (value, text));
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '주기',
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 점수 팝업 입력칸
class _AwardField extends StatelessWidget {
  _AwardField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.number = false,
  });

  final TextEditingController controller;
  final String hint;

  /// 검증에 걸렸을 때 이 칸으로 커서를 옮기려고 받는다
  final FocusNode? focusNode;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: number
            ? TextInputType.numberWithOptions(signed: true)
            : null,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))]
            : null,
        style: AppTextStyles.body2,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
        ),
      ),
    );
  }
}

/// 완료를 **처음으로 되돌리기 전에** 한 번 묻는다 — MASTER 만 (2026-09-16)
///
/// 되돌릴 수 없는 일이 한 번에 넷이라 반드시 묻는다. 무엇이 사라지는지를
/// 적어 주고, **감점은 그 자리에서 같이 받는다** — 창을 두 번 띄우면
/// 되돌리기만 하고 점수를 안 깎는 일이 생긴다.
///
/// 돌려주는 값은 `(감점, 사유)` 다. 감점은 **참여자 기준**이고 PM 은
/// [_pmGap] 만큼 더 문다. 비워 두면 0 — 실수로 완료한 것을 치우는 경우다.
Future<(int, String?)?> _askReset(BuildContext context, _Project project) {
  final points = TextEditingController();
  final reason = TextEditingController();
  final pointsFocus = FocusNode();

  return showAppDialog<(int, String?)>(
    context,
    (context) => Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('처음으로 되돌릴까요?', style: AppTextStyles.title3),
          SizedBox(height: 8),
          // **무엇이 사라지는지 적어 준다** — 되돌릴 수 없는 일이다
          Text(
            '· 할 일 체크가 전부 풀려요\n'
            '· 기한이 오늘부터 다시 세어져요\n'
            '· 완료로 받은 점수를 도로 걷어요',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '더 깎을 점수 (안 적으면 안 깎아요)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          _AwardField(
            controller: points,
            focusNode: pointsFocus,
            hint: '0',
            number: true,
          ),
          SizedBox(height: 6),
          Text(
            '참여자 ${project.members.length}명에게 같이 들어가요 · '
            'PM 은 -$_pmGap점 (0 ~ 100)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 10),
          _AwardField(controller: reason, hint: '사유 (선택)'),
          SizedBox(height: 16),
          Row(
            children: [
              Spacer(),
              Pressable(
                onTap: () => Navigator.pop(context),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Text(
                  '취소',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 6),
              Pressable(
                onTap: () {
                  final text = points.text.trim();
                  // **비우면 0이다** — 실수로 완료한 것을 치우는 경우가 있다
                  final value = text.isEmpty ? 0 : int.tryParse(text);
                  if (value == null || value < 0 || value > 100) {
                    AppToast.show(context, '0 부터 100 까지 적어주세요');
                    pointsFocus.requestFocus();
                    return;
                  }
                  final note = reason.text.trim();
                  Navigator.pop(context, (value, note.isEmpty ? null : note));
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '되돌리기',
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 창을 띄우고 실제로 되돌린다 — 폰 헤더와 PC 머리말이 같이 쓴다
Future<void> _resetProject(
  BuildContext context,
  _Project project,
  VoidCallback onChanged,
) async {
  final id = project.id;
  if (id == null) return;
  final result = await _askReset(context, project);
  if (result == null || !context.mounted) return;
  try {
    await ProjectApi.reset(id, penalty: result.$1, reason: result.$2);
    onChanged();
    if (context.mounted) {
      AppToast.show(
        context,
        result.$1 == 0 ? '처음으로 되돌렸어요' : '되돌리고 ${result.$1}점 깎았어요',
      );
    }
  } catch (error) {
    if (context.mounted) AppToast.show(context, messageOf(error));
  }
}
