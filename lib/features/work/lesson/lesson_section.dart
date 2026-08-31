import '../../../core/widgets/display/avatar.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/lesson_api.dart';
import '../../../core/data/branch_scope.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/employee.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/nav/month_bar.dart';
import '../../../core/widgets/nav/pick_filter_button.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
import '../../../core/api/work/workout_api.dart';
import '../../member/member_screen.dart';
import '../work_skeleton.dart';
import '../../../core/widgets/feedback/skeleton.dart';
part 'lesson_data.dart';
part 'lesson_cards.dart';
part 'lesson_history.dart';
part 'lesson_register.dart';
part 'lesson_pick.dart';
part 'lesson_sign.dart';

/// 회원 등록 화면을 연다 — **회원 관리 화면도 같은 것을 쓴다**
///
/// 등록 화면은 이 파일의 part 라 밖에서 이름을 못 부른다. 화면을 하나 더
/// 만들면 신규·재등록·소개·방문 경로 규칙이 두 벌이 되므로 통로만 연다.
///
/// 돌아온 값이 true 면 회원이 하나 늘었다는 뜻이다 — 부른 쪽이 목록을 다시 받는다.
Future<bool?> showMemberRegister(BuildContext context) =>
    showFullPage<bool>(context, (_) => _RegisterScreen());

/// 수업 개수 탭 콘텐츠
///
/// 수업은 회원의 싸인을 받아야 인정된다.
/// - 상단: 회원 등록 / 운동 일지 / 세션 싸인 버튼
/// - 세션 기록: 받은 싸인 기록 (서명 미리보기·회차·시각)
class LessonSection extends StatefulWidget {
  LessonSection({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 전 지점
  ///
  /// MASTER·ADMIN 만 고를 수 있고, 그 밖에는 늘 null 이라 서버가 본인 지점으로
  /// 고정한다. 바뀌면 [didUpdateWidget] 에서 다시 받는다.
  final String? branchId;

  @override
  State<LessonSection> createState() => _LessonSectionState();
}

class _LessonSectionState extends State<LessonSection>
    with SkeletonDelay<LessonSection> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LessonSection old) {
    super.didUpdateWidget(old);
    // 지점을 바꾸면 화면이 통째로 다른 지점 것이 된다 — 다시 받는다
    if (old.branchId != widget.branchId) _load();
  }

  Future<void> _load() async {
    try {
      await _LessonStore.instance.load(branchId: widget.branchId);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  /// 회원 등록 화면을 연다 — 폰은 밀려 들어오고 PC는 모달로 뜬다
  Future<void> _register() async {
    final added = await showFullPage<bool>(context, (_) => _RegisterScreen());
    if (added == true && mounted) await _load();
  }

  /// 운동일지를 쓰러 간다 — 회원 관리 화면이 곧 일지 목록이다
  ///
  /// **홈 바로가기에 있던 자리를 여기로 옮겼다** (2026-08-31 대표 요청).
  /// 일지를 써야 싸인이 되므로 수업 흐름이 한 화면에서 이어져야 한다.
  Future<void> _openWorkouts() async {
    await showFullPage<void>(context, (_) => MemberScreen());
    if (mounted) await _load();
  }

  /// 회원을 골라 싸인을 받는다
  Future<void> _pickAndSign() async {
    final signed = await showFullPage<bool>(
      context,
      (_) => _PickMemberScreen(),
    );
    if (signed == true && mounted) await _load();
  }

  /// 세션 기록 전체 화면을 연다
  void _openHistory() {
    showFullPage<void>(context, (_) => _SignHistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) return WorkSectionSkeleton();

    // 상단 액션 버튼 두 개 — 폰·PC 공통. 대표·관리자는 수행자가 아니라 안 그린다
    // 셋 다 네 글자라 똑같이 나눠도 폰에서 안 넘친다
    final actions = _viewOnly
        ? SizedBox.shrink()
        : Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.person_add,
                  label: '회원 등록',
                  onTap: _register,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.doc_text,
                  label: '운동 일지',
                  onTap: _openWorkouts,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.signature,
                  label: '세션 싸인',
                  highlighted: true,
                  onTap: _pickAndSign,
                ),
              ),
            ],
          );

    // 폰은 싸인마다 카드 하나 (회원 친절도 목록과 같은 결).
    // 데스크톱은 2단 화면이라 카드가 과해서 기존 줄 목록을 그대로 쓴다.
    if (!isDesktop) {
      final sorted = _LessonStore.instance.shownSigns;
      // 목록에는 최근 5건만 — 나머지는 전체 보기 화면에서
      final recent = sorted.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actions,
          if (!_viewOnly) SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '세션 기록',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Text('${sorted.length}', style: AppTextStyles.caption),
                Spacer(),
                SeeAllButton(onTap: _openHistory),
              ],
            ),
          ),
          SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(icon: Icons.draw_rounded, text: '아직 받은 싸인이 없어요')
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _SignCard(
                sign: recent[i],
                showTrainer: _viewOnly,
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      );
    }

    return Column(
      children: [
        // 회원 등록·싸인 받기는 본인이 하는 일이라 대표·관리자에게는 뜻이 없다
        if (!_viewOnly) ...[actions, SizedBox(height: 16)],
        _buildRecordCard(),
      ],
    );
  }

  Widget _buildRecordCard() {
    final sorted = _LessonStore.instance.shownSigns;
    // 카드에는 최근 5건만 — 나머지는 전체 보기 화면에서
    final recent = sorted.take(5).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('세션 기록', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sorted.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: _openHistory),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (sorted.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '아직 받은 싸인이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _SignRow(
                sign: recent[i],
                showTrainer: _viewOnly,
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 상단 액션 버튼 — 강조(파랑)와 기본(흰색) 두 가지
class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.primary : AppColors.textPrimary;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.gray100,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 신규/재등록 배지
class _MemberBadge extends StatelessWidget {
  _MemberBadge({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isNew ? AppColors.primaryLight : AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isNew ? '신규' : '재등록',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: isNew ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
