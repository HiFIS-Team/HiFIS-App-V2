import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/supplement_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/pressable.dart';
import 'supplement_presets.dart';

/// 새로 담기 — 자주 쓰는 표에서 고르고(또는 직접 적고) 저장까지.
///
/// **페이지가 아니라 팝업이다.** 다섯 칸뿐이라 화면을 통짜로 넘길 것이 없다 —
/// 일지처럼 페이지로 열면 PC 에서 상세 칸을 덮어 회원 정보가 안 보이고, 폰에서도
/// 들고 나는 걸음만 늘어난다. [showAppDialog] 가 키보드를 피해 밀어 올리고
/// 좁은 화면에서는 폭을 줄인다.
///
/// 무언가 바뀌었으면 true (부모가 목록을 다시 받는다)
Future<bool> addSupplement(
  BuildContext context, {
  required String memberId,
}) async {
  final preset = await _pickPreset(context);
  if (preset == null || !context.mounted) return false;
  return _openForm(context, memberId: memberId, preset: preset);
}

/// 이미 담긴 줄 고치기 — 팝업 안에서 지울 수도 있다
Future<bool> editSupplement(BuildContext context, Supplement row) =>
    _openForm(context, row: row);

// ── 자주 쓰는 표에서 고르기 ─────────────────────────────────

/// `직접 입력` 을 고르면 빈 칸으로 연다
const _blank = (name: '', dose: '', timing: '', reason: '', note: '');

Future<SupplementPreset?> _pickPreset(BuildContext context) =>
    showAppDialog<SupplementPreset>(context, (_) => _PresetPicker());

class _PresetPicker extends StatefulWidget {
  @override
  State<_PresetPicker> createState() => _PresetPickerState();
}

class _PresetPickerState extends State<_PresetPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SupplementPreset> get _shown {
    final key = _search.text.trim().replaceAll(' ', '').toLowerCase();
    if (key.isEmpty) return supplementPresets;
    return [
      for (final preset in supplementPresets)
        if ('${preset.name}${preset.reason}'
            .replaceAll(' ', '')
            .toLowerCase()
            .contains(key))
          preset,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _shown;
    // 화면이 낮으면 목록이 잘리지 않게 같이 줄인다 (폰 가로·작은 창)
    final maxList = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      160.0,
      320.0,
    );

    return Container(
      width: dialogWidth(context, 420),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '영양제 고르기',
            style: AppTextStyles.title3.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '고르면 얼마나·언제·왜가 함께 채워져요',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: AppDecorations.field(),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: AppColors.gray400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _search,
                    autofocus: false,
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: '이름·효능으로 찾기',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxList),
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      '찾는 영양제가 없어요 · 직접 적어 주세요',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) => _PresetRow(
                      preset: rows[i],
                      onTap: () => Navigator.pop(context, rows[i]),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: '직접 입력',
            onTap: () => Navigator.pop(context, _blank),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset, required this.onTap});

  final SupplementPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preset.dose} · ${preset.timing}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
        ],
      ),
    ),
  );
}

// ── 다섯 칸 폼 ──────────────────────────────────────────────

Future<bool> _openForm(
  BuildContext context, {
  Supplement? row,
  SupplementPreset? preset,
  String? memberId,
}) async {
  final saved = await showAppDialog<bool>(
    context,
    (_) => _SupplementForm(
      row: row,
      preset: preset,
      memberId: memberId ?? row?.memberId ?? '',
    ),
  );
  return saved ?? false;
}

class _SupplementForm extends StatefulWidget {
  const _SupplementForm({required this.memberId, this.row, this.preset});

  final String memberId;

  /// 고치는 중이면 그 줄 — 없으면 새로 담는 것이다
  final Supplement? row;

  /// 표에서 고른 값 (새로 담을 때만)
  final SupplementPreset? preset;

  @override
  State<_SupplementForm> createState() => _SupplementFormState();
}

class _SupplementFormState extends State<_SupplementForm> {
  late final _name = _field(widget.row?.name ?? widget.preset?.name);
  late final _dose = _field(widget.row?.dose ?? widget.preset?.dose);
  late final _timing = _field(widget.row?.timing ?? widget.preset?.timing);
  late final _reason = _field(widget.row?.reason ?? widget.preset?.reason);
  late final _note = _field(widget.row?.note ?? widget.preset?.note);

  bool _busy = false;

  TextEditingController _field(String? text) =>
      TextEditingController(text: text ?? '')..addListener(_onEdit);

  void _onEdit() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final field in [_name, _dose, _timing, _reason, _note]) {
      field.dispose();
    }
    super.dispose();
  }

  /// 이름만 있으면 저장된다 — 상담 자리에서 이름만 먼저 적어 두는 일이 잦다
  bool get _complete => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_complete || _busy) return;
    setState(() => _busy = true);
    try {
      final old = widget.row;
      if (old == null) {
        await SupplementApi.create(
          memberId: widget.memberId,
          name: _name.text.trim(),
          dose: _dose.text.trim(),
          timing: _timing.text.trim(),
          reason: _reason.text.trim(),
          note: _note.text.trim(),
        );
      } else {
        await SupplementApi.update(
          old.id,
          name: _name.text.trim(),
          dose: _dose.text.trim(),
          timing: _timing.text.trim(),
          reason: _reason.text.trim(),
          note: _note.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete() async {
    final old = widget.row;
    if (old == null || _busy) return;
    final yes = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: '${old.name}을(를) 뺄까요?',
      message: '회원 화면에서도 함께 사라져요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupplementApi.remove(old.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.row != null;

    return Container(
      width: dialogWidth(context, 420),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? '영양제 고치기' : '영양제 담기',
            style: AppTextStyles.title3.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _Field(label: '영양제', controller: _name, hint: '오메가3', max: 60),
          _Field(
            label: '얼마나?',
            controller: _dose,
            hint: '1000~3000mg',
            max: 80,
          ),
          _Field(label: '언제?', controller: _timing, hint: '아침식후', max: 80),
          _Field(
            label: '왜?',
            controller: _reason,
            hint: '성인병 예방, 염증완화',
            max: 500,
            lines: 2,
          ),
          _Field(
            label: '기억하기',
            controller: _note,
            hint: '식사 직후',
            max: 500,
            lines: 2,
            last: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (editing) ...[
                AppButton(
                  label: '삭제',
                  onTap: _delete,
                  shrinkWrap: true,
                  textColor: AppColors.error,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AppButton(
                  label: editing ? '수정' : '담기',
                  filled: true,
                  busy: _busy,
                  // 이름이 비면 안 눌린다 — 파란 면에 흰 글씨를 두면 눌러도
                  // 아무 일이 안 일어나는 버튼이 살아있는 것처럼 보인다
                  color: _complete ? null : AppColors.gray100,
                  textColor: _complete ? null : AppColors.gray400,
                  onTap: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 라벨 한 줄 + 칸 하나 — 다섯 칸이 같은 모양으로 선다
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.max,
    this.lines = 1,
    this.last = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  /// 서버가 받는 길이 — 넘어서 보내면 422 로 되돌아온다
  final int max;

  /// 여러 줄 칸 (왜? · 기억하기) — 길게 적히는 자리다
  final int lines;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          // 한 줄은 42, 여러 줄은 글이 늘어나는 만큼 자란다
          constraints: BoxConstraints(minHeight: lines == 1 ? 42 : 62),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: lines == 1 ? 0 : 10,
          ),
          decoration: AppDecorations.field(),
          child: TextField(
            controller: controller,
            style: AppTextStyles.body2,
            cursorColor: AppColors.primary,
            minLines: lines,
            maxLines: lines == 1 ? 1 : 4,
            maxLength: max,
            textInputAction: lines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
              counterText: '',
            ),
          ),
        ),
      ],
    ),
  );
}
