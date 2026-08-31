import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/lesson_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/pressable.dart';

/// 회원 정보를 고치거나 지웠을 때 상세 화면이 할 일
enum MemberEditResult {
  /// 고쳤다 — 상세를 다시 받는다
  saved,

  /// 지웠다 — 상세를 닫고 목록으로 나간다
  deleted,
}

/// 회원 정보 고치기 — **담당 트레이너 본인과 대표·관리자만** 연다
///
/// 예전에는 고치는 길도 지우는 길도 없어서, 이름을 잘못 적으면 대표가 손으로
/// 고쳐야 했다. 운영에 같은 사람이 두 줄로 들어간 것이 여럿이었다.
///
/// **담당 트레이너는 여기서 안 바꾼다** — 매출 귀속이 따라 움직이는 값이라
/// 인사 쪽에서 다룰 일이다. 서버도 관리자에게만 열어 두었다.
Future<MemberEditResult?> showMemberEdit(BuildContext context, Member member) =>
    showFullPage<MemberEditResult>(
      context,
      (_) => _MemberEditScreen(member: member),
    );

class _MemberEditScreen extends StatefulWidget {
  const _MemberEditScreen({required this.member});

  final Member member;

  @override
  State<_MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<_MemberEditScreen> {
  late final _name = TextEditingController(text: widget.member.name);
  late final _phone = TextEditingController(text: widget.member.phone);
  late final _memo = TextEditingController(text: widget.member.memo ?? '');
  late VisitPath? _visitPath = widget.member.visitPath;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 이름이 비면 저장 버튼이 꺼진다 — 지우는 순간 바로 반응해야 한다
    for (final c in [_name, _phone, _memo]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _memo]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _memoText => _memo.text.trim();

  /// 이름은 비울 수 없다 — 목록에서 그 사람을 가리키는 유일한 글자다
  bool get _complete => _name.text.trim().isNotEmpty;

  bool get _dirty =>
      _name.text.trim() != widget.member.name ||
      _phone.text.trim() != widget.member.phone ||
      _visitPath != widget.member.visitPath ||
      _memoText != (widget.member.memo ?? '').trim();

  Future<void> _save() async {
    if (_busy || !_complete || !_dirty) return;
    final ok = await showConfirmDialog(
      context,
      title: '이 내용으로 고칠까요?',
      message: '${_name.text.trim()} 회원님의 정보가 바뀌어요',
      confirmLabel: '고치기',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MemberApi.update(
        widget.member.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        visitPath: _visitPath,
        memo: _memoText,
      );
      if (!mounted) return;
      Navigator.pop(context, MemberEditResult.saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showConfirmDialog(
      context,
      title: '${widget.member.name} 회원님을 삭제할까요?',
      // 무엇이 같이 사라지는지 말해 준다 — 되돌릴 수 없는 자리다
      message: '등록권 · 세션 싸인 · 운동일지가 함께 지워지고 되돌릴 수 없어요',
      confirmLabel: '삭제',
      destructive: true,
      icon: CupertinoIcons.trash,
      iconColor: AppColors.error,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await MemberApi.remove(widget.member.id);
      if (!mounted) return;
      Navigator.pop(context, MemberEditResult.deleted);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                // 위 고정 타이틀 자리만큼 비운다 — 회원 등록 화면과 같은 값
                68,
                24,
                MediaQuery.paddingOf(context).bottom + 120,
              ),
              children: [
                const _Label('이름'),
                _Field(controller: _name, hint: '회원 이름'),
                const SizedBox(height: 16),
                const _Label('연락처'),
                _Field(
                  controller: _phone,
                  hint: '01012345678',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                const _Label('방문 경로'),
                _VisitPathChips(
                  value: _visitPath,
                  onPick: (path) => setState(() => _visitPath = path),
                ),
                const SizedBox(height: 16),
                const _Label('메모'),
                _Field(controller: _memo, hint: '상담에서 들은 것', lines: 3),
                const SizedBox(height: 28),
                Center(
                  child: Pressable(
                    onTap: _delete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        '회원 삭제',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('회원 정보', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'save-member',
                    label: _busy ? '저장 중...' : '저장',
                    filled: _complete && _dirty && !_busy,
                    onPressed: _save,
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

/// 칸 이름 — 회원 등록 화면과 같은 결
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(text, style: AppTextStyles.label),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppDecorations.fieldPaddingMultiline,
    decoration: AppDecorations.field(),
    child: TextField(
      controller: controller,
      style: AppTextStyles.body1,
      cursorColor: AppColors.primary,
      keyboardType: keyboardType,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
        border: InputBorder.none,
        isCollapsed: true,
      ),
    ),
  );
}

/// 방문 경로 칩 — 회원 등록 화면의 고르개와 같은 모양
///
/// **비울 수는 없다.** 이 칸이 생기기 전에 등록된 회원은 비어 있는데,
/// 고르면 채워지고 되돌리는 길은 두지 않는다 (점수는 등록할 때 한 번만
/// 붙으므로 여기서 바꿔도 지난 점수는 그대로다).
class _VisitPathChips extends StatelessWidget {
  const _VisitPathChips({required this.value, required this.onPick});

  final VisitPath? value;
  final ValueChanged<VisitPath> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final path in VisitPath.values)
        Pressable(
          onTap: () => onPick(path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: path == value ? AppColors.primary : AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              path.label,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w600,
                color: path == value
                    ? AppColors.surface
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
    ],
  );
}
