part of 'project_screen.dart';

/// 프로젝트 점수 카드 — **완료된 프로젝트에만, MASTER 에게만** 보인다
///
/// 기한 연장 결재가 있던 자리를 그대로 쓴다. 완료된 뒤에는 결재할 연장이 없고,
/// 대신 여기서 점수를 매긴다.
///
/// **참여자 전원에게 같은 점수가 간다.** 여기서 매기는 것은 대표의 평가라
/// 사람마다 나누지 않는다 — 매긴 값이 **최종 점수**다 (더해지지 않는다).
///
/// 완료하면 서버가 **담당자(PM) 10점 · 참여 멤버 5점**을 먼저 붙이고,
/// 그 위에서 대표가 판단해 올리거나 깎는다.
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
              _loading
                  ? '불러오는 중'
                  : '참여자 $people명 · ${given?.points ?? _autoPoints}점',
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w600,
                color: (given?.points ?? 0) < 0
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          given?.comment ?? '완료해서 붙은 기본 점수예요',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        if (given != null) ...[
          SizedBox(height: 4),
          Text(
            '${_relative(given.createdAt)} 매김',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ],
    );

    final button = Pressable(
      onTap: _loading ? _ignore : _give,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          given == null ? '점수 주기' : '다시 주기',
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
const _autoPoints = 10;

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
            '참여자 ${project.members.length}명에게 같이 들어가요. -100 ~ 100',
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
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
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
                  if (value == null || value < -100 || value > 100) {
                    AppToast.show(context, '-100 부터 100 까지 적어주세요');
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
                scale: 0.97,
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
