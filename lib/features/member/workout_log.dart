import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/lesson_api.dart';
import '../../core/api/work/workout_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/pen_mode.dart';
import '../../core/util/platform.dart';
import '../../core/util/when.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/date_picker.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import 'workout_media.dart';

/// 일지 한 장을 열거나 새로 쓴다 — 무언가 바뀌었으면 `true` 를 돌려준다
///
/// PT 든 개인 운동이든 **적는 것이 같아서** 화면 하나로 둔다 (웨이트 표·유산소
/// 표·자료). 다른 건 위에 붙는 회차 번호와 맨 아래 트레이너 총평뿐이다.
Future<bool?> showWorkoutLog(
  BuildContext context, {
  required Member member,
  required WorkoutKind kind,
  required bool editable,
  WorkoutLog? log,
  int? nextSessionNo,
}) => showFullPage<bool>(
  context,
  (_) => WorkoutLogScreen(
    member: member,
    kind: kind,
    editable: editable,
    log: log,
    nextSessionNo: nextSessionNo,
  ),
);

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({
    super.key,
    required this.member,
    required this.kind,
    required this.editable,
    this.log,
    this.nextSessionNo,
    this.onExit,
  });

  final Member member;
  final WorkoutKind kind;

  /// 담당 트레이너·점장·관리자만 참이다 (서버도 같은 줄로 막는다)
  final bool editable;

  /// 고칠 일지 — 없으면 새로 쓰는 것이다
  final WorkoutLog? log;

  /// 새 PT 일지가 몇 회차가 될지 — **보여 주기만** 한다.
  /// 실제 번호는 저장할 때 서버가 매긴다(두 대에서 동시에 눌러도 안 겹치게).
  final int? nextSessionNo;

  /// 팝업이 아니라 화면 한 칸에 박아 쓸 때 — 닫기·저장·삭제가 이걸 대신 부른다
  final void Function(bool changed)? onExit;

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  late final _title = TextEditingController(text: widget.log?.title ?? '');

  /// 새 일지를 열자마자 커서를 올리고, 제목에서 `다음` 을 받는다
  final FocusNode _titleFocus = FocusNode();
  late DateTime _at = widget.log?.performedOn ?? DateTime.now();
  late final _trainer = TextEditingController(
    text: widget.log?.trainerFeedback ?? '',
  );

  /// 웨이트 표 — 처음 열면 빈 줄 하나로 시작한다 (누르지 않아도 바로 적는다)
  late final List<_WeightEditor> _weights = _seed(
    widget.log?.weights,
    (row) => _WeightEditor(row),
    () => _WeightEditor(null),
  );

  late final List<_CardioEditor> _cardio = _seed(
    widget.log?.cardio,
    (row) => _CardioEditor(row),
    () => _CardioEditor(null),
  );

  late final List<MediaGroupEditor> _groups = [
    for (final group in widget.log?.media ?? const <MediaGroup>[])
      MediaGroupEditor(group),
  ];

  bool _busy = false;

  List<T> _seed<S, T>(List<S>? rows, T Function(S) of, T Function() blank) => [
    if (rows != null && rows.isNotEmpty)
      for (final row in rows) of(row)
    else
      blank(),
  ];

  @override
  void initState() {
    super.initState();
    // 제목을 고치면 위 큰 글씨(`1회차(가슴, 삼두)`)가 같이 바뀐다
    _title.addListener(_onEdit);
    _pen = PenMode.on.value;
    PenMode.on.addListener(_onPen);
    // 새로 쓰는 자리면 바로 적을 수 있게 커서를 올려 둔다 — 열자마자 제목 칸을
    // 한 번 눌러야 하는 것이 매번 걸린다. **펜 모드에서는 안 올린다** (자판이
    // 올라오면 필기할 자리가 반으로 준다)
    if (widget.log == null && widget.editable && !_pen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  void _onPen() {
    if (mounted) setState(() => _pen = PenMode.on.value);
  }

  @override
  void dispose() {
    PenMode.on.removeListener(_onPen);
    _title.dispose();
    _titleFocus.dispose();
    _trainer.dispose();
    for (final row in _weights) {
      row.dispose();
    }
    for (final row in _cardio) {
      row.dispose();
    }
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  void _exit(bool changed) {
    final exit = widget.onExit;
    if (exit == null) {
      Navigator.pop(context, changed);
    } else {
      exit(changed);
    }
  }

  bool get _isPt => widget.kind == WorkoutKind.pt;

  int? get _sessionNo =>
      _isPt ? (widget.log?.sessionNo ?? widget.nextSessionNo) : null;

  /// 화면 맨 위 큰 글씨 — `1회차(가슴, 삼두)` / `개인 운동 일지(하체)`
  String get _heading {
    final title = _title.text.trim();
    final part = title.isEmpty ? '' : '($title)';
    if (!_isPt) return '개인 운동 일지$part';
    return _sessionNo == null ? '새 회차$part' : '$_sessionNo회차$part';
  }

  /// 저장할 수 있나 — 수업내용은 반드시 있어야 한다
  ///
  /// 목록에 뜨는 글자가 이것뿐이라 비워 두면 `1회차` 만 줄줄이 남는다.
  bool get _complete => _title.text.trim().isNotEmpty;

  /// 수업 날짜 고르기 — **머티리얼 달력을 안 쓴다** (앞뒤 화면과 생김새가 다르다)
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await pickAppDate(
      context,
      initial: _at,
      // 밀린 일지를 몰아 쓰는 일이 흔하다 — 지난 날짜를 막지 않는다
      min: DateTime(now.year - 3),
      max: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) setState(() => _at = picked);
  }

  /// 웨이트 한 줄 더 — **앞 줄 부위와 세트를 물려준다**
  ///
  /// 한 수업에서 같은 부위를 여러 개 하는 것이 보통이고(가슴 날이면 다 가슴),
  /// 세트도 3세트로 쭉 가는 일이 많다. 줄마다 다시 고르게 하면 그만큼 팝업을
  /// 여닫고 스테퍼를 눌러야 한다 — **다르면 그때 고치는 쪽이 빠르다.**
  ///
  /// [focus] 를 켜면 새 줄의 운동명으로 커서가 간다 — 자판이 내려갔다 올라오지
  /// 않게 **다음 프레임**에 옮긴다 (그 전에는 아직 칸이 안 그려져 있다).
  void _addWeight({bool focus = false}) {
    final last = _weights.isEmpty ? null : _weights.last;
    final row = _WeightEditor(null);
    if (last != null) {
      row.part.text = last.part.text;
      row.sets.text = last.sets.text;
    }
    setState(() => _weights.add(row));
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) row.nameFocus.requestFocus();
      });
    }
  }

  void _addCardio({bool focus = false}) {
    final row = _CardioEditor(null);
    setState(() => _cardio.add(row));
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) row.nameFocus.requestFocus();
      });
    }
  }

  /// 무게 칸에서 `다음` 을 눌렀다 — 아래 줄로 내려가고, 마지막이면 한 줄 만든다
  ///
  /// **빈 줄이 남아 있으면 안 만든다.** 엔터를 두 번 치면 빈 줄이 쌓인다.
  void _nextWeight(int index) {
    if (index < _weights.length - 1) {
      _weights[index + 1].nameFocus.requestFocus();
      return;
    }
    if (_weights.last.isBlank) return;
    _addWeight(focus: true);
  }

  void _nextCardio(int index) {
    if (index < _cardio.length - 1) {
      _cardio[index + 1].nameFocus.requestFocus();
      return;
    }
    if (_cardio.last.isBlank) return;
    _addCardio(focus: true);
  }

  /// 마지막 한 줄은 지우는 대신 비운다 — 표가 통째로 사라지면 다시 만들 곳이 없다
  void _removeWeight(int index) => setState(() {
    if (_weights.length == 1) {
      _weights[0].clear();
    } else {
      _weights.removeAt(index).dispose();
    }
  });

  void _removeCardio(int index) => setState(() {
    if (_cardio.length == 1) {
      _cardio[0].clear();
    } else {
      _cardio.removeAt(index).dispose();
    }
  });

  /// 파일을 골라 새 묶음으로 붙인다 — 고른 즉시 올라간다
  Future<void> _addMedia() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final items = await pickWorkoutMedia(context);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _groups.add(MediaGroupEditor(MediaGroup(items: items)));
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  void _removeGroup(int index) =>
      setState(() => _groups.removeAt(index)..dispose());

  void _removeItem(int group, int item) =>
      setState(() => _groups[group].items.removeAt(item));

  Future<void> _save() async {
    if (_busy) return;
    if (!_complete) {
      AppToast.show(context, '수업내용을 적어 주세요');
      return;
    }
    setState(() => _busy = true);
    final title = _title.text.trim();
    // **적은 줄만 보낸다.** 부위·세트는 새 줄에 물려받으므로, 그것만 차 있는
    // 마지막 줄은 손도 안 대본 빈 줄이다 (`isBlank`)
    final weights = [
      for (final row in _weights)
        if (!row.isBlank) row.toRow(),
    ];
    final cardio = [
      for (final row in _cardio)
        if (!row.isBlank) row.toRow(),
    ];
    final media = [
      for (final group in _groups)
        if (!group.isEmpty) group.toGroup(),
    ];
    // PT 도 피드백을 쓴다 (2026-09-05) — 예전에는 개인 운동만 보냈다
    final feedback = _trainer.text.trim();

    try {
      final old = widget.log;
      if (old == null) {
        await WorkoutApi.create(
          memberId: widget.member.id,
          kind: widget.kind,
          title: title,
          performedOn: _at,
          weights: weights,
          cardio: cardio,
          media: media,
          trainerFeedback: feedback,
        );
      } else {
        await WorkoutApi.update(
          old.id,
          title: title,
          performedOn: _at,
          weights: weights,
          cardio: cardio,
          media: media,
          trainerFeedback: feedback,
        );
      }
      if (!mounted) return;
      _exit(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete() async {
    final old = widget.log;
    if (old == null || _busy) return;
    final yes = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: '이 일지를 지울까요?',
      message: '적어 둔 운동과 올린 자료가 함께 사라져요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      await WorkoutApi.remove(old.id);
      if (!mounted) return;
      _exit(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  List<Widget> _body() {
    final editable = widget.editable;
    return [
      Text(_heading, style: AppTextStyles.title3),
      const SizedBox(height: 16),
      _label('수업내용'),
      const SizedBox(height: 8),
      _Box(
        child: TextField(
          controller: _title,
          focusNode: _titleFocus,
          enabled: editable,
          style: AppTextStyles.body1,
          cursorColor: AppColors.primary,
          maxLength: 100,
          // 제목을 적고 `다음` 을 누르면 첫 운동으로 내려간다 — 날짜는 오늘이
          // 그대로 맞는 날이 대부분이라 가운데서 멈추게 하지 않는다
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_weights.isNotEmpty) _weights.first.nameFocus.requestFocus();
          },
          decoration: InputDecoration(
            hintText: '예) 가슴, 삼두',
            hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
            border: InputBorder.none,
            isCollapsed: true,
            counterText: '',
          ),
        ),
      ),
      const SizedBox(height: 16),
      _label('수업 날짜'),
      const SizedBox(height: 8),
      Pressable(
        onTap: editable ? _pickDate : () {},
        child: _Box(
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Text(fullDateLabel(_at), style: AppTextStyles.body1),
              const Spacer(),
              if (editable)
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.gray400,
                ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 22),
      _label('웨이트 운동'),
      if (editable) _hint('부위를 누르고 · 운동명과 무게·횟수·세트를 적어요'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: AppDecorations.field(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _weights.length; i++) ...[
              // 펜 모드는 더 벌린다 — 손바닥이 옆 줄을 안 건드리게
              if (i > 0) SizedBox(height: _rowGap(context) + 2),
              _WeightRowFields(
                // 줄을 지우면 뒤 줄이 앞으로 당겨진다 — 자리로 짝지으면 남의
                // 칸을 듣고 있게 되므로 **줄 자체**를 열쇠로 쓴다
                key: ObjectKey(_weights[i]),
                row: _weights[i],
                number: i + 1,
                editable: editable,
                // 보기를 첫 줄에만 둔다 — 줄마다 '가슴'이 뜨면 적어 넣은 것처럼 보인다
                showHint: i == 0,
                onNext: () => _nextWeight(i),
                onRemove: () => _removeWeight(i),
              ),
            ],
          ],
        ),
      ),
      if (editable) ...[
        const SizedBox(height: 8),
        _AddRow(label: '운동 추가', onTap: _addWeight),
      ],

      const SizedBox(height: 22),
      _label('유산소 운동'),
      if (editable) _hint('운동명과 한 시간을 적어요'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: AppDecorations.field(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _cardio.length; i++) ...[
              if (i > 0) SizedBox(height: _rowGap(context)),
              _CardioRowFields(
                key: ObjectKey(_cardio[i]),
                row: _cardio[i],
                editable: editable,
                showHint: i == 0,
                onNext: () => _nextCardio(i),
                onRemove: () => _removeCardio(i),
              ),
            ],
          ],
        ),
      ),
      if (editable) ...[
        const SizedBox(height: 8),
        _AddRow(label: '유산소 추가', onTap: _addCardio),
      ],

      // 피드백이 사진보다 앞이다 (2026-09-05 요청 — 노션 서식과 같은 차례).
      // **PT 도 쓴다.** 예전에는 개인 운동에만 뒀는데, 그러면 사진을 안 올린
      // 회차는 피드백을 남길 자리가 아예 없었다 (묶음 피드백뿐이었다).
      const SizedBox(height: 22),
      _label('피드백'),
      if (editable) _hint('한 줄에 하나씩 적으면 회원 화면에 항목으로 보여요'),
      const SizedBox(height: 8),
      _Box(
        multiline: true,
        child: TextField(
          controller: _trainer,
          enabled: editable,
          style: AppTextStyles.body1,
          cursorColor: AppColors.primary,
          maxLines: 8,
          minLines: 3,
          maxLength: 2000,
          decoration: InputDecoration(
            hintText: editable ? '오늘 수업에서 느낀 점 · 다음에 볼 것' : '아직 피드백이 없어요',
            hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
            border: InputBorder.none,
            isCollapsed: true,
            counterText: '',
          ),
        ),
      ),

      const SizedBox(height: 22),
      _label(_isPt ? '사진 or 영상' : '참고 자료'),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          _isPt
              ? '한 번에 올린 것끼리 묶여요 · 묶음마다 따로 적을 수도 있어요'
              : '자세를 찍어 두면 트레이너가 보고 피드백을 남겨요',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        ),
      ),
      MediaGroupList(
        groups: _groups,
        editable: editable,
        hint: '이 자료에 대한 피드백',
        emptyText: editable ? '아직 올린 자료가 없어요' : '올린 자료가 없어요',
        onRemoveGroup: _removeGroup,
        onRemoveItem: _removeItem,
      ),
      if (editable) ...[
        const SizedBox(height: 8),
        _AddRow(
          label: _busy ? '올리는 중…' : '사진 · 영상 추가',
          icon: Icons.add_photo_alternate_outlined,
          onTap: _addMedia,
        ),
      ],
    ];
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: AppTextStyles.label),
  );

  /// 표 위에 붙는 한 줄 안내 — 칸 안의 보기글을 대신한다
  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 4),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // 저장·삭제만 `true` 를 돌려준다. 그냥 뒤로 가면 `null` 이라 목록은 그대로 둔다.
    //
    // **표 칸들이 [_Pen] 을 읽어 크기를 정한다** — 화면을 통째로 감싸야
    // `_Input`·`_SetsStepper` 같은 아래쪽 위젯까지 닿는다.
    return _Pen(
      // 읽기만 하는 화면은 칸을 안 키운다 — 쓸 일이 없다
      on: _pen && widget.editable,
      child: isDesktop ? _desktop() : _phone(),
    );
  }

  /// PC 폼의 저장 버튼 — 데스크톱에는 글래스 트레이가 없다
  Widget _saveButton() => AppButton(
    label: widget.log == null ? '저장' : '수정',
    filled: true,
    busy: _busy,
    onTap: _complete ? _save : () {},
    color: _complete ? null : AppColors.gray100,
    textColor: _complete ? null : AppColors.gray400,
  );

  /// 지금 펜 모드인가 — [PenMode] 를 듣고 다시 그린다
  bool _pen = false;

  Widget _phone() => PhoneDetailScaffold(
    title: widget.member.name,
    background: AppColors.surface,
    actions: [
      // 펜 모드 — **적을 수 있을 때만** 뜬다. 읽기만 하는 화면에서는 칸을
      // 키울 이유가 없다. 지금 무슨 모드인지를 아이콘이 말해 준다
      if (widget.editable)
        GlassIconButton(
          symbol: _pen ? 'keyboard' : 'pencil.tip',
          stableId: 'workout-pen-mode',
          onPressed: () => PenMode.toggle(),
        ),
      if (widget.editable && widget.log != null)
        GlassIconButton(
          symbol: 'trash',
          stableId: 'workout-log-delete',
          symbolColor: AppColors.error,
          onPressed: _delete,
        ),
    ],
    // **다른 폼과 같은 글래스 버튼이다** (2026-08-31 대표 지적). 예전에는
    // 평평한 `AppButton` 을 바닥에 붙여서, 애플에서 다른 화면의 뜬 유리
    // 버튼과 결이 달랐다. 저장 중에는 글자로 알린다 — 글래스 버튼에는
    // 스피너 자리가 없어서 싸인 화면도 같은 방법을 쓴다
    bottomBar: widget.editable
        ? GlassBottomButton(
            label: _busy
                ? '저장 중…'
                : widget.log == null
                ? '저장'
                : '수정',
            active: _complete && !_busy,
            onPressed: (_complete && !_busy) ? _save : () {},
          )
        : null,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        PhoneDetailScaffold.topPadding,
        20,
        widget.editable
            ? GlassBottomButton.inset(context)
            : bottomBarInset(context),
      ),
      children: _body(),
    ),
  );

  Widget _desktop() => Scaffold(
    backgroundColor: AppColors.surface,
    body: Column(
      children: [
        // 뒤로 가는 자리는 **안 흐른다** — 다 적고 맨 위까지 올려야 나갈 수
        // 있으면 안 된다. 글 위에 띄우면 적는 걸 가리니 칸을 따로 뒀다.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 28, 14),
          child: Row(
            children: [
              _BackButton(onTap: () => _exit(false)),
              const SizedBox(width: 12),
              Text(
                '${widget.member.name} 회원님',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            children: _body(),
          ),
        ),
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: widget.log == null
                ? _saveButton()
                : Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: '삭제',
                          textColor: AppColors.error,
                          onTap: _delete,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _saveButton()),
                    ],
                  ),
          ),
      ],
    ),
  );
}

// ── 표 ──────────────────────────────────────────────────────────

/// 상세 자리에서 회원 화면으로 되돌아가는 화살표 — 팝업이 아니라 한 칸 뒤다
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Pressable(
      onTap: widget.onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 흰 면 위의 흰 원이라 테두리와 그림자로 떠 보이게 한다
          color: _hover ? AppColors.gray50 : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gray100),
          boxShadow: AppShadows.card,
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 19,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );
}

/// 칸 너비 — 한 줄에 다 넣으면 무게 칸이 `60kg 1…` 로 잘린다.
/// 웨이트는 **두 줄**로 나눠 적는다 (부위·운동명 / 무게·세트).
const _partWidth = 62.0;
const _setsWidth = 96.0;
const _timeWidth = 96.0;
const _trailWidth = 30.0;
const _gap = 6.0;

/// 고를 수 있는 운동 부위 — 트레이너가 실제로 쓰는 말만 둔다
const _parts = ['가슴', '등', '어깨', '하체', '팔', '복근', '전신'];

/// 펜 모드인가 — 표 칸을 키워 **펜으로 쓸 자리**를 만든다 (2026-09-02 대표 요청)
///
/// 트레이너가 수업하면서 적는데, 폰은 자판이고 **패드는 펜이 편하다.**
///
/// **손글씨를 글자로 바꾸는 것은 우리가 안 한다** — OS 가 해 준다
/// (아이패드는 Scribble, 안드로이드 14 이상은 Scribe). 플러터가 `TextField`
/// 에 그대로 붙여 두었고 기본이 켜짐이라, 여기서 하는 일은 **칸을 크게 펴는
/// 것뿐**이다. 자판도 우리가 막을 필요가 없다 — 펜으로 쓰기 시작하면 OS 가
/// 자판 대신 필기를 띄우고, 손으로 누를 때만 자판이 뜬다.
class _Pen extends InheritedWidget {
  const _Pen({required this.on, required super.child});

  final bool on;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Pen>()?.on ?? false;

  @override
  bool updateShouldNotify(_Pen old) => old.on != on;
}

/// 표 한 칸의 높이 — 펜 모드면 넉넉하게
///
/// 40 은 손가락으로 누르기에 맞춘 값이라 펜으로 **쓰기**에는 자리가 없다.
/// 글씨가 칸을 넘으면 OS 가 인식을 못 한다.
double _rowHeight(BuildContext context) => _Pen.of(context) ? 58 : 40;

/// 표 칸 글자 — 펜 모드면 한 단계 크게 (쓴 것이 작으면 다시 확인하게 된다)
TextStyle _cellStyle(BuildContext context) =>
    _Pen.of(context) ? AppTextStyles.body1 : AppTextStyles.body2;

/// 줄 사이 — 펜 모드면 손바닥이 옆 줄을 안 건드리게 벌린다
double _rowGap(BuildContext context) => _Pen.of(context) ? 12 : 8;

/// `60kg 12회` 를 무게와 횟수로 가른다 — **못 가르면 null**
///
/// 예전에는 한 칸에 자유롭게 적었다. `20kg x 12`·`맨몸`처럼 우리 서식이 아닌
/// 줄이 이미 저장돼 있으므로, 못 알아보면 그 줄만 예전처럼 한 칸으로 보여
/// 준다. 있는 글을 우리 마음대로 바꿔 쓰지 않는다.
({String weight, String reps})? splitLoad(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return (weight: '', reps: '');
  final both = RegExp(r'^(\d+(?:\.\d+)?)kg\s*(\d+)회$').firstMatch(text);
  if (both != null) {
    return (weight: both.group(1)!, reps: both.group(2)!);
  }
  final only = RegExp(r'^(\d+(?:\.\d+)?)kg$').firstMatch(text);
  if (only != null) return (weight: only.group(1)!, reps: '');
  final reps = RegExp(r'^(\d+)회$').firstMatch(text);
  if (reps != null) return (weight: '', reps: reps.group(1)!);
  return null;
}

/// 두 칸을 다시 한 줄로 — 한쪽이 비면 그쪽 단위도 안 붙인다
String joinLoad(String weight, String reps) {
  final w = weight.trim();
  final r = reps.trim();
  if (w.isEmpty && r.isEmpty) return '';
  if (w.isEmpty) return '$r회';
  if (r.isEmpty) return '${w}kg';
  return '${w}kg $r회';
}

/// `20분` 에서 숫자만 — 못 가르면 null (예전 자유 입력 줄)
String? splitMinutes(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'^(\d+)분$').firstMatch(text);
  return match?.group(1);
}

class _WeightEditor {
  _WeightEditor(WeightRow? row)
    : part = TextEditingController(text: row?.part ?? ''),
      name = TextEditingController(text: row?.name ?? ''),
      sets = TextEditingController(text: row?.sets ?? '') {
    final split = splitLoad(row?.load ?? '');
    if (split == null) {
      free = TextEditingController(text: row?.load ?? '');
    } else {
      weight = TextEditingController(text: split.weight);
      reps = TextEditingController(text: split.reps);
    }
  }

  final TextEditingController part;
  final TextEditingController name;
  final TextEditingController sets;

  /// 무게(kg)·횟수 — **예전 서식으로 저장된 줄에서는 둘 다 없다**
  TextEditingController? weight;
  TextEditingController? reps;

  /// 예전 자유 입력 칸 — 위 둘이 없을 때만 있다
  TextEditingController? free;

  /// 자판의 `다음` 으로 옮겨 다니려고 칸마다 초점을 든다
  ///
  /// 세트는 스테퍼라 자판이 안 뜬다 — 초점도 안 둔다.
  final FocusNode nameFocus = FocusNode();
  final FocusNode loadFocus = FocusNode();
  final FocusNode repsFocus = FocusNode();

  String get load =>
      free != null ? free!.text.trim() : joinLoad(weight!.text, reps!.text);

  /// 트레이너가 **아무것도 안 적은** 줄인가
  ///
  /// 부위와 세트는 앞 줄에서 물려받은 **기본값**이라 적은 것으로 안 친다 —
  /// 안 그러면 손도 안 대본 마지막 줄이 `가슴 / 3세트` 만 담긴 채 저장된다.
  bool get isBlank => name.text.trim().isEmpty && load.isEmpty;

  WeightRow toRow() => WeightRow(
    part: part.text.trim(),
    name: name.text.trim(),
    load: load,
    sets: sets.text.trim(),
  );

  void clear() {
    part.clear();
    name.clear();
    sets.clear();
    weight?.clear();
    reps?.clear();
    free?.clear();
  }

  void dispose() {
    part.dispose();
    name.dispose();
    sets.dispose();
    weight?.dispose();
    reps?.dispose();
    free?.dispose();
    nameFocus.dispose();
    loadFocus.dispose();
    repsFocus.dispose();
  }
}

class _CardioEditor {
  _CardioEditor(CardioRow? row)
    : name = TextEditingController(text: row?.name ?? '') {
    final minutes = splitMinutes(row?.duration ?? '');
    if (minutes == null) {
      free = TextEditingController(text: row?.duration ?? '');
    } else {
      time = TextEditingController(text: minutes);
    }
  }

  final TextEditingController name;

  /// 몇 분 — 숫자만 담는다 (`분` 은 칸에 붙박이로 적혀 있다)
  TextEditingController? time;

  /// 예전 자유 입력 칸 — `20분` 서식이 아닌 줄만 여기로 온다
  TextEditingController? free;

  final FocusNode nameFocus = FocusNode();
  final FocusNode durationFocus = FocusNode();

  String get duration {
    if (free != null) return free!.text.trim();
    final text = time!.text.trim();
    return text.isEmpty ? '' : '$text분';
  }

  bool get isBlank => name.text.trim().isEmpty && duration.isEmpty;

  CardioRow toRow() =>
      CardioRow(name: name.text.trim(), duration: duration);

  void clear() {
    name.clear();
    time?.clear();
    free?.clear();
  }

  void dispose() {
    name.dispose();
    time?.dispose();
    free?.dispose();
    nameFocus.dispose();
    durationFocus.dispose();
  }
}

/// 웨이트 한 줄 — 부위·운동명 / 무게·세트, **두 줄로 나눠 적는다**
///
/// 네 칸을 한 줄에 밀어 넣으면 폰에서 무게 칸이 40픽셀도 안 남아 `60kg…` 로
/// 잘린다. 줄을 나누면 칸마다 손가락이 들어가고, 무엇을 적는 자리인지도
/// 보기글로 알 수 있다.
///
/// 아랫줄은 **숫자만 치는 칸 셋**이다 (2026-09-06 요청). 예전에는 `60kg 12회`
/// 를 통째로 쳤는데, 단위까지 손으로 적느라 줄마다 글자 예닐곱 자를 더 쳤고
/// 자판도 한글에서 숫자로 오갔다. 이제 `kg`·`회`·`세트` 는 칸에 붙박이로
/// 적혀 있고 숫자판만 뜬다.
class _WeightRowFields extends StatelessWidget {
  const _WeightRowFields({
    super.key,
    required this.row,
    required this.number,
    required this.editable,
    required this.showHint,
    required this.onRemove,
    this.onNext,
  });

  final _WeightEditor row;

  /// 몇 번째 운동인가 — 1부터 센다
  final int number;

  final bool editable;

  /// 보기글(`벤치프레스`)을 띄울 줄인가 — 첫 줄에만 둔다
  final bool showHint;

  final VoidCallback onRemove;

  /// 마지막 숫자 칸에서 `다음` 을 눌렀을 때 — 아래 줄로 내려간다
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (editable) ...[
        _IndexBadge(number: number),
        const SizedBox(width: _gap),
      ],
      Expanded(
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: _partWidth,
                  child: _PartField(controller: row.part, editable: editable),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: _Input(
                    controller: row.name,
                    focusNode: row.nameFocus,
                    onSubmitted: editable
                        ? () => row.loadFocus.requestFocus()
                        : null,
                    hint: showHint ? '벤치프레스' : '운동명',
                    editable: editable,
                    align: TextAlign.left,
                  ),
                ),
                if (editable) _RemoveButton(onTap: onRemove),
              ],
            ),
            const SizedBox(height: 6),
            Row(children: [..._numbers(), if (editable) _trailingGap()]),
          ],
        ),
      ),
    ],
  );

  /// 오른쪽 지우기 버튼만큼 비워 둔다 — 윗줄과 칸 끝이 어긋나면 표로 안 보인다
  Widget _trailingGap() => const SizedBox(width: _trailWidth);

  /// 무게 · 횟수 · 세트 — 예전 서식 줄은 한 칸 그대로다
  List<Widget> _numbers() {
    if (row.free case final free?) {
      return [
        Expanded(
          child: _Input(
            controller: free,
            focusNode: row.loadFocus,
            onSubmitted: editable ? onNext : null,
            hint: '무게 · 횟수',
            editable: editable,
            align: TextAlign.left,
          ),
        ),
        const SizedBox(width: _gap),
        _setsCell(),
      ];
    }
    return [
      Expanded(
        child: _NumField(
          controller: row.weight!,
          focusNode: row.loadFocus,
          unit: 'kg',
          editable: editable,
          decimal: true,
          onSubmitted: editable ? () => row.repsFocus.requestFocus() : null,
        ),
      ),
      const SizedBox(width: _gap),
      Expanded(
        child: _NumField(
          controller: row.reps!,
          focusNode: row.repsFocus,
          unit: '회',
          editable: editable,
          onSubmitted: editable ? onNext : null,
        ),
      ),
      const SizedBox(width: _gap),
      _setsCell(),
    ];
  }

  Widget _setsCell() => SizedBox(
    width: _setsWidth,
    child: editable
        ? _SetsStepper(controller: row.sets)
        : _Input(
            controller: row.sets,
            hint: '세트',
            suffix: '세트',
            editable: false,
          ),
  );
}

/// 몇 번째 운동인지 — 줄이 늘어지면 어디까지 적었는지 놓친다
class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: _rowHeight(context),
    alignment: Alignment.center,
    child: Text(
      '$number',
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.gray400,
      ),
    ),
  );
}

/// 세트 수 — **자판을 안 올리고 누르는 게 빠르다**
///
/// 3~5 사이를 오가는 값이라 숫자판을 띄웠다 내리는 게 더 번거롭다. 그래도
/// 20세트 같은 값을 위해 가운데 칸은 그대로 적을 수 있게 둔다.
class _SetsStepper extends StatelessWidget {
  const _SetsStepper({required this.controller});

  final TextEditingController controller;

  void _step(int delta) {
    final next = ((int.tryParse(controller.text) ?? 0) + delta).clamp(0, 99);
    controller.text = next == 0 ? '' : '$next';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: _setsWidth,
    height: _rowHeight(context),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _StepButton(icon: Icons.remove_rounded, onTap: () => _step(-1)),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
            cursorColor: AppColors.primary,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              hintText: '세트',
              hintStyle: AppTextStyles.caption.copyWith(
                color: AppColors.gray400,
              ),
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, onTap: () => _step(1)),
      ],
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: SizedBox(
      width: 30,
      height: _rowHeight(context),
      child: Icon(icon, size: 16, color: AppColors.primary),
    ),
  );
}

/// 유산소 한 줄 — 운동명 / 몇 분
///
/// 시간도 `분` 을 손으로 안 적는다 — 숫자만 치고 단위는 칸에 붙어 있다.
class _CardioRowFields extends StatelessWidget {
  const _CardioRowFields({
    super.key,
    required this.row,
    required this.editable,
    required this.showHint,
    required this.onRemove,
    this.onNext,
  });

  final _CardioEditor row;
  final bool editable;
  final bool showHint;
  final VoidCallback onRemove;

  /// 시간 칸에서 `다음` 을 눌렀을 때 — 아래 줄로 내려간다
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Input(
          controller: row.name,
          focusNode: row.nameFocus,
          onSubmitted: editable ? () => row.durationFocus.requestFocus() : null,
          hint: showHint ? '트레드밀' : '운동명',
          editable: editable,
          align: TextAlign.left,
        ),
      ),
      const SizedBox(width: _gap),
      SizedBox(width: _timeWidth, child: _time()),
      if (editable) _RemoveButton(onTap: onRemove),
    ],
  );

  /// 몇 분 — 예전 서식(`가볍게 20분`)으로 저장된 줄은 한 칸 그대로다
  Widget _time() {
    if (row.free case final free?) {
      return _Input(
        controller: free,
        focusNode: row.durationFocus,
        onSubmitted: editable ? onNext : null,
        hint: '시간',
        editable: editable,
      );
    }
    return _NumField(
      controller: row.time!,
      focusNode: row.durationFocus,
      unit: '분',
      editable: editable,
      onSubmitted: editable ? onNext : null,
    );
  }
}

/// 숫자만 치는 칸 — **단위는 칸에 붙박이로 적혀 있다**
///
/// `60kg 12회` 를 통째로 치던 것을 갈랐다 (2026-09-06). 단위를 손으로 안 적으니
/// 자판이 숫자판으로 고정되고, 한글↔숫자를 오갈 일이 없다. 값이 비어 있어도
/// 단위는 옅게 남겨 둔다 — 여기가 무슨 자리인지가 그것으로 드러난다.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.unit,
    required this.editable,
    this.focusNode,
    this.onSubmitted,
    this.decimal = false,
  });

  final TextEditingController controller;

  /// 칸 오른쪽에 붙박이로 적히는 말 — `kg` · `회` · `분`
  final String unit;

  final bool editable;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  /// 소수점을 받는가 — 무게는 `2.5kg` 를 쓴다
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    return Container(
      height: _rowHeight(context),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: editable
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: decimal,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                      ),
                      LengthLimitingTextInputFormatter(decimal ? 6 : 4),
                    ],
                    textInputAction: onSubmitted == null
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: onSubmitted == null
                        ? null
                        : (_) => onSubmitted!(),
                    style: _cellStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: _cellStyle(
                        context,
                      ).copyWith(color: AppColors.gray300),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  )
                : Text(
                    text.isEmpty ? '-' : text,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _cellStyle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: text.isEmpty
                          ? AppColors.gray400
                          : AppColors.textPrimary,
                    ),
                  ),
          ),
          const SizedBox(width: 3),
          Text(
            unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 운동 부위 칸 — **눌러서 고른다**
///
/// 부위는 쓰는 말이 정해져 있는데(가슴·등·어깨…) 자판을 올려 두 글자를 치게
/// 하면, 같은 부위가 `등` `등근육` `back` 으로 갈라진다. 목록에서 고르되 없는
/// 말은 직접 적을 수 있게 둔다.
class _PartField extends StatelessWidget {
  const _PartField({required this.controller, required this.editable});

  final TextEditingController controller;
  final bool editable;

  Future<void> _choose(BuildContext context) async {
    final picked = await showAppDialog<String>(
      context,
      (_) => _PartPicker(current: controller.text.trim()),
    );
    if (picked != null) controller.text = picked;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final text = value.text.trim();
      final empty = text.isEmpty;
      return Pressable(
        onTap: editable ? () => _choose(context) : () {},
        child: Container(
          height: _rowHeight(context),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            empty ? (editable ? '부위' : '-') : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w600,
              color: empty ? AppColors.gray400 : AppColors.primary,
            ),
          ),
        ),
      );
    },
  );
}

class _PartPicker extends StatefulWidget {
  const _PartPicker({required this.current});

  final String current;

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  late final _custom = TextEditingController(
    // 목록에 없는 말로 적어 뒀으면 그 말을 직접 입력 칸에 되돌려 준다
    text: _parts.contains(widget.current) ? '' : widget.current,
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: dialogWidth(context, 340),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: AppDecorations.card(radius: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('운동 부위', style: AppTextStyles.title3),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final part in _parts)
              _PartChip(
                label: part,
                selected: part == widget.current,
                onTap: () => Navigator.pop(context, part),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: AppDecorations.fieldPadding,
          decoration: AppDecorations.field(),
          child: TextField(
            controller: _custom,
            style: AppTextStyles.body1,
            cursorColor: AppColors.primary,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            onSubmitted: (text) => _submit(text),
            decoration: InputDecoration(
              hintText: '직접 입력 (예: 승모근)',
              hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '비우기',
                onTap: () => Navigator.pop(context, ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: '확인',
                filled: true,
                onTap: () => _submit(_custom.text),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _submit(String text) => Navigator.pop(context, text.trim());
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.body2.copyWith(
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.surface : AppColors.primary,
        ),
      ),
    ),
  );
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _trailWidth,
    child: IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(
        Icons.remove_circle_outline_rounded,
        size: 18,
        color: AppColors.gray400,
      ),
    ),
  );
}

/// 표 안의 흰 칸 — 회색 판 위에 놓여서 칸이 눈에 보인다
///
/// 볼 수만 있는 사람에게는 같은 자리에 **글자만** 놓는다. `TextField` 를 잠가
/// 두면 눌러 보고 나서야 못 쓴다는 걸 안다.
class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.editable,
    this.suffix,
    this.align = TextAlign.center,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool editable;

  /// 적은 값 뒤에 붙는 말(`4세트`) — 칸 이름을 지우고도 뜻이 남게 한다
  final String? suffix;

  final TextAlign align;

  /// 자판의 `다음` 으로 이 칸을 짚어 올 수 있게 한다
  final FocusNode? focusNode;

  /// `다음` 을 눌렀을 때 — 주면 자판에 `완료` 대신 `다음` 이 선다
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    return Container(
      height: _rowHeight(context),
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: editable
          ? TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: align,
              // 적다 말고 다음 칸으로 — 자판을 내렸다 올리지 않는다
              textInputAction: onSubmitted == null
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
              style: _cellStyle(context).copyWith(fontWeight: FontWeight.w600),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: _cellStyle(
                  context,
                ).copyWith(color: AppColors.gray400),
                // 비어 있을 땐 안 붙인다 — `세트` 만 덩그러니 남는다
                suffixText: text.isEmpty ? null : suffix,
                suffixStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            )
          : Text(
              text.isEmpty ? '-' : '$text${suffix ?? ''}',
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cellStyle(context).copyWith(
                fontWeight: FontWeight.w600,
                color: text.isEmpty ? AppColors.gray400 : AppColors.textPrimary,
              ),
            ),
    );
  }
}

/// 표 밑에 붙는 줄 추가 버튼 — **행은 얼마든지 늘릴 수 있다**
class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: _rowHeight(context) + 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.add_rounded, size: 18, color: AppColors.primary),
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

/// 회색 입력 판 하나
class _Box extends StatelessWidget {
  const _Box({required this.child, this.multiline = false});

  final Widget child;
  final bool multiline;

  @override
  Widget build(BuildContext context) => Container(
    padding: multiline
        ? AppDecorations.fieldPaddingMultiline
        : AppDecorations.fieldPadding,
    decoration: AppDecorations.field(),
    child: child,
  );
}
