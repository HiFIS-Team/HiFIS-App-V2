import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/lesson_api.dart';
import '../../core/api/work/workout_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/util/when.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/section_header.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/display/field_rows.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import 'workout_log.dart';

/// 회원 한 명 — 인적 사항 · 운동을 하는 이유 · PT 일지 · 개인 운동
///
/// 목록에서 들어오는 자리다. 목록이 이미 회원 값을 들고 있어서 첫 프레임부터
/// 이름·전화가 채워지고, **일지만** 여기서 받는다.
///
/// **탭을 안 쓴다.** 트레이너가 수업 직전에 여는 화면이라 "왜 운동하나 → 지난
/// 회차에 뭐를 했나" 를 한 번에 훑어야 한다. 탭으로 나누면 한 번 훑어 내리면
/// 될 것을 세 번 눌러야 아는 것으로 바꿄다.
class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.member});

  final Member member;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SkeletonDelay<MemberDetailScreen> {
  List<WorkoutLog> _pt = const [];
  List<WorkoutLog> _personal = const [];

  /// 운동을 하는 이유 — 화면이 살아 있는 동안 입력을 들고 있는다
  late final List<TextEditingController> _goals = _seedGoals();

  /// 서버에 들어 있는 값 — 이것과 다르면 저장 버튼이 나온다
  late List<String> _savedGoals = List.of(widget.member.goals);

  bool _savingGoals = false;

  List<TextEditingController> _seedGoals() {
    final rows = widget.member.goals;
    // 처음엔 `1.` 한 줄만 둔다 — 빈 화면보다 적을 자리가 보이는 편이 낫다
    if (rows.isEmpty) return [_newGoal()];
    return [for (final row in rows) _newGoal(row)];
  }

  TextEditingController _newGoal([String text = '']) =>
      TextEditingController(text: text)..addListener(_onGoalEdit);

  /// 한 글자만 바뀌어도 저장 버튼이 나타나야 한다
  void _onGoalEdit() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final goal in _goals) {
      goal.dispose();
    }
    super.dispose();
  }

  /// 일지를 쓸 수 있는 사람 — **담당 트레이너 본인뿐이다**
  ///
  /// 다른 트레이너의 회원은 **보기만 한다.** 서버도 같은 줄로 막는다
  /// (`NOT_MY_MEMBER`) — 여기서 감추는 건 헛걸음을 줄이려는 것뿐이다.
  ///
  /// **대표·관리자도 못 쓴다** (2026-09-02 대표 결정). 그 둘은 수업을 안 하니
  /// 남길 것이 없고, 일지는 수업한 사람이 적은 기록이라 남이 손대면 누가 쓴
  /// 것인지가 흐려진다. **서버는 아직 그 둘을 통과시킨다**(`_ensure_can_write`)
  /// — 앱이 더 좁게 잡은 것이라 인사 정보 변경(backend-gap 63)과 같은 자리다.
  ///
  /// 점장은 담당인 회원에 한해 쓴다 — 본인이 수업한 것이라서다.
  bool get _canWrite => currentUser?.id == widget.member.ownerTrainerId;

  Future<void> _load() async {
    try {
      // 등록권도 같이 받는다 — **다음 회차 번호가 여기서 나온다**.
      // 일지가 한 장도 없는 옛 회원은 이미 받은 싸인 수가 곧 진도다
      final request = MemberApi.registrations(widget.member.id);
      final logs = await WorkoutApi.list(widget.member.id);
      final registrations = await request;
      if (!mounted) return;
      setState(() {
        _split(logs);
        _signed = registrations.fold(0, (sum, r) => sum + r.usedSessions);
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 이 회원이 지금까지 받은 싸인 수 — 등록권 전부를 더한 값
  ///
  /// **재등록해도 안 줄어든다.** 싸인은 등록권마다 1 부터 다시 세지만
  /// 일지는 회원 평생 번호라 이어진다 (서버 `_next_session_no` 와 같은 셈법).
  int _signed = 0;

  /// PT 는 **회차 순**으로 세운다 — 날짜 순으로 두면 1·2·3 이 뒤섞인다
  /// (몰아서 적으면 3회차를 1회차보다 먼저 쓰는 일이 생긴다)
  void _split(List<WorkoutLog> logs) {
    _pt = [
      for (final log in logs)
        if (log.kind == WorkoutKind.pt) log,
    ]..sort((a, b) => (a.sessionNo ?? 0).compareTo(b.sessionNo ?? 0));
    _personal = [
      for (final log in logs)
        if (log.kind == WorkoutKind.personal) log,
    ]..sort((a, b) => b.performedOn.compareTo(a.performedOn));
  }

  Future<void> _reload() async {
    try {
      final logs = await WorkoutApi.list(widget.member.id);
      if (mounted) setState(() => _split(logs));
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  // ── 운동을 하는 이유 ──────────────────────────────────────────

  List<String> get _goalTexts => [
    for (final goal in _goals)
      if (goal.text.trim().isNotEmpty) goal.text.trim(),
  ];

  bool get _goalsDirty {
    final now = _goalTexts;
    if (now.length != _savedGoals.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _savedGoals[i]) return true;
    }
    return false;
  }

  void _addGoal() => setState(() => _goals.add(_newGoal()));

  void _removeGoal(int index) => setState(() {
    // 마지막 한 줄은 비워만 둔다 — 다 지우면 다시 적을 칸이 없다
    if (_goals.length == 1) {
      _goals[0].clear();
    } else {
      _goals.removeAt(index).dispose();
    }
  });

  Future<void> _saveGoals() async {
    if (_savingGoals) return;
    setState(() => _savingGoals = true);
    try {
      final saved = await MemberApi.updateGoals(widget.member.id, _goalTexts);
      if (!mounted) return;
      setState(() {
        _savedGoals = List.of(saved.goals);
        _savingGoals = false;
      });
      AppToast.show(context, '저장했어요');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingGoals = false);
      AppToast.show(context, messageOf(error));
    }
  }

  // ── 일지 ─────────────────────────────────────────────────────

  /// 데스크톱에서 상세 자리에 대신 띄운 일지 — 없으면 회원 상세다.
  /// 목록·상세로 이미 두 칸이라 일지까지 옆에 붙이면 칸이 다 좁아진다.
  _LogView? _view;

  Future<void> _closeView(bool changed) async {
    setState(() => _view = null);
    if (changed) await _reload();
  }

  Future<void> _open(WorkoutLog log) async {
    if (isDesktop) {
      setState(
        () => _view = _LogView(kind: log.kind, editable: _canWrite, log: log),
      );
      return;
    }
    final changed = await showWorkoutLog(
      context,
      member: widget.member,
      kind: log.kind,
      editable: _canWrite,
      log: log,
    );
    if (changed == true) await _reload();
  }

  Future<void> _addPt() async {
    // **받은 싸인과 쓴 일지 중 큰 쪽 다음**이다 — 서버가 매기는 번호와 같다.
    // 일지 번호만 보면 일지가 생기기 전부터 있던 회원이 1 회차부터 다시
    // 세어져서, 써도 싸인이 안 열린다 (2026-08-31 고침)
    final last = _pt.lastOrNull?.sessionNo ?? 0;
    final next = (_signed > last ? _signed : last) + 1;
    if (isDesktop) {
      setState(
        () => _view = _LogView(
          kind: WorkoutKind.pt,
          editable: true,
          nextSessionNo: next,
        ),
      );
      return;
    }
    final changed = await showWorkoutLog(
      context,
      member: widget.member,
      kind: WorkoutKind.pt,
      editable: true,
      nextSessionNo: next,
    );
    if (changed == true) await _reload();
  }

  Future<void> _addPersonal() async {
    if (isDesktop) {
      setState(
        () =>
            _view = const _LogView(kind: WorkoutKind.personal, editable: true),
      );
      return;
    }
    final changed = await showWorkoutLog(
      context,
      member: widget.member,
      kind: WorkoutKind.personal,
      editable: true,
    );
    if (changed == true) await _reload();
  }

  // ── 회원에게 보내는 주소 ───────────────────────

  /// 어디까지 나갔나 — 일지 장수가 아니라 마지막 회차 번호다.
  /// 5·6·7회차만 남아 있어도 `3회차` 로 보이면 진도를 잘못 읽는다.
  int get _lastSession => _pt.lastOrNull?.sessionNo ?? _pt.length;

  /// 회원이 로그인 없이 자기 수업을 보는 주소
  String? get _trainingLink {
    final token = widget.member.trainingToken;
    return token == null ? null : 'https://hifis.app/training/$token';
  }

  Future<void> _copyLink() async {
    final link = _trainingLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) AppToast.show(context, '주소를 복사했어요 · 회원에게 보내세요');
  }

  // ── 화면 ─────────────────────────────────

  List<Widget> _sections() => [
    _ProfileCard(member: widget.member),
    if (_trainingLink case final link?) ...[
      const SizedBox(height: 12),
      _LinkCard(link: link, onCopy: _copyLink),
    ],
    const SizedBox(height: 24),
    ..._goalSection(),
    const SizedBox(height: 24),
    ..._logSection(
      title: '운동일지 (PT)',
      logs: _pt,
      info: _pt.isEmpty ? '회차별로 기록' : '$_lastSession회차',
      empty: _canWrite ? '수업이 끝나면 회차별로 남겨요' : '아직 남긴 PT 일지가 없어요',
      icon: Icons.assignment_rounded,
      addLabel: '회차 추가',
      onAdd: _addPt,
      canAdd: _canWrite,
    ),
    const SizedBox(height: 24),
    ..._logSection(
      title: '개인 운동',
      logs: _personal,
      info: _personal.isEmpty ? 'PT 회차와 무관' : '${_personal.length}장',
      empty: _canWrite ? '혼자 한 운동도 여기에 적어 둬요' : '아직 남긴 개인 운동이 없어요',
      icon: Icons.fitness_center_rounded,
      addLabel: '개인 운동 추가',
      onAdd: _addPersonal,
      canAdd: _canWrite,
    ),
  ];

  /// 운동을 하는 이유 — 번호를 매겨 적는다
  ///
  /// 회원이 말한 것을 그대로 옮겨 두는 자리라 **틀을 안 씌운다.** 목표 체중이든
  /// "결혼식" 이든 한 줄씩 적히면 된다.
  List<Widget> _goalSection() => [
    SectionHeader(
      title: '운동을 하는 이유',
      info: _canWrite && _goalsDirty
          ? Pressable(
              onTap: _saveGoals,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _savingGoals ? '저장 중…' : '저장',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : null,
    ),
    const SizedBox(height: 12),
    if (!_canWrite && _savedGoals.isEmpty)
      EmptyCard(icon: Icons.flag_rounded, text: '아직 적어 둔 이유가 없어요')
    else
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canWrite)
              for (var i = 0; i < _goals.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _GoalRow(
                  index: i,
                  controller: _goals[i],
                  onRemove: () => _removeGoal(i),
                ),
              ]
            else
              for (var i = 0; i < _savedGoals.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _GoalText(index: i, text: _savedGoals[i]),
              ],
            if (_canWrite) ...[
              const SizedBox(height: 12),
              Pressable(
                onTap: _addGoal,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '이유 추가',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
  ];

  List<Widget> _logSection({
    required String title,
    required List<WorkoutLog> logs,
    required String info,
    required String empty,
    required IconData icon,
    required String addLabel,
    required VoidCallback onAdd,
    required bool canAdd,
  }) => [
    SectionHeader(
      title: title,
      info: Text(
        info,
        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
      ),
    ),
    const SizedBox(height: 12),
    if (showSkeleton)
      SkeletonGroup(
        child: SkeletonCard(children: [Skeleton(width: 160, height: 14)]),
      )
    else ...[
      if (logs.isEmpty)
        EmptyCard(icon: icon, text: empty)
      else
        for (var i = 0; i < logs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LogRow(log: logs[i], onTap: () => _open(logs[i])),
        ],
      if (canAdd) ...[
        const SizedBox(height: 10),
        _AddButton(label: addLabel, onTap: onAdd),
      ],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: '${widget.member.name} 회원님',
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            bottomBarInset(context),
          ),
          children: _sections(),
        ),
      );
    }
    if (_view case final view?) {
      return WorkoutLogScreen(
        key: ValueKey(view.log?.id ?? 'new-${view.kind.name}'),
        member: widget.member,
        kind: view.kind,
        editable: view.editable,
        log: view.log,
        nextSessionNo: view.nextSessionNo,
        onExit: _closeView,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 18),
            child: Text(
              '${widget.member.name} 회원님',
              style: AppTextStyles.title3,
            ),
          ),
          ..._sections(),
        ],
      ),
    );
  }
}

/// 상세 자리에 띄울 일지 한 장 — `log` 가 없으면 새로 쓰는 것이다
class _LogView {
  const _LogView({
    required this.kind,
    required this.editable,
    this.log,
    this.nextSessionNo,
  });

  final WorkoutKind kind;
  final bool editable;
  final WorkoutLog? log;
  final int? nextSessionNo;
}

/// 이유 한 줄 — 앞에 번호, 뒤에 지우기
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.index,
    required this.controller,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _GoalNumber(index: index),
      Expanded(
        child: Container(
          height: 42,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppDecorations.field(),
          child: TextField(
            controller: controller,
            style: AppTextStyles.body1,
            cursorColor: AppColors.primary,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: index == 0 ? '예) 체중 8kg 감량' : '이유를 적어 주세요',
              hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
              counterText: '',
            ),
          ),
        ),
      ),
      SizedBox(
        width: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: Icon(
            Icons.remove_circle_outline_rounded,
            size: 18,
            color: AppColors.gray400,
          ),
        ),
      ),
    ],
  );
}

/// 볼 수만 있는 사람에게 보이는 줄
class _GoalText extends StatelessWidget {
  const _GoalText({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _GoalNumber(index: index),
      Expanded(
        child: Text(text, style: AppTextStyles.body1.copyWith(height: 1.5)),
      ),
    ],
  );
}

class _GoalNumber extends StatelessWidget {
  const _GoalNumber({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    child: Text(
      '${index + 1}.',
      style: AppTextStyles.body2.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 일지 한 줄 — `1회차(가슴, 삼두)` 와 날짜
class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.onTap});

  final WorkoutLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final marks = <String>[
      fullDateLabel(log.performedOn),
      if (log.exerciseCount > 0) '운동 ${log.exerciseCount}',
      if (log.photoCount > 0) '자료 ${log.photoCount}',
    ];
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        decoration: AppDecorations.card(radius: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.heading,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    marks.join(' · '),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

/// 목록 밑에 붙는 추가 버튼
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 인적 사항 — 이름·전화 아래에 담당·지점·방문 경로를 칸으로 세운다
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final trainer =
        StaffDirectory.instance.byId(member.ownerTrainerId)?.name ?? '없음';
    final branch = StaffDirectory.instance.branchName(member.branchId);

    return Container(
      // 아래는 6 이다 — 마지막 줄에 세로 14 가 붙어 위와 같은 20 이 된다
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(name: member.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.title3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.phone,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 머리(이름·연락처)와 줄들 사이를 선으로 가른다 — 회원 정보 화면과
          // **같은 부품**이라 이름표 폭·줄 높이가 갈릴 수 없다
          Container(height: 1, color: AppColors.gray50),
          FieldRows(
            fields: [
              (label: '담당', value: trainer, onCopy: null),
              if (branch.isNotEmpty) (label: '지점', value: branch, onCopy: null),
              (
                label: '등록일',
                value: fullDateLabel(member.registeredAt),
                onCopy: null,
              ),
              (
                label: '방문 경로',
                value: member.visitPath?.label ?? '기록 없음',
                onCopy: null,
              ),
              if (member.memo case final memo? when memo.trim().isNotEmpty)
                (label: '메모', value: memo, onCopy: null),
            ],
          ),
        ],
      ),
    );
  }
}

/// 회원에게 보내는 수업 주소 — 눌러서 복사
///
/// 주소를 화면에 다 보여 준다. 트레이너가 회원에게 카카오톡으로 보내는
/// 물건이라 "뭘 보내는지" 가 보여야 안심하고 누른다.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, required this.onCopy});

  final String link;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onCopy,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: AppDecorations.card(radius: 16),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '회원 수업 주소',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '복사',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
