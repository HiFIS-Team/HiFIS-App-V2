import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/lesson_api.dart';
import '../../../core/data/current_user.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/widgets/display/progress_bar.dart';
import '../../../core/widgets/feedback/app_dialog.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/input/see_all_button.dart';
import '../../../core/util/when.dart';
part 'lesson_data.dart';
part 'lesson_cards.dart';
part 'lesson_history.dart';
part 'lesson_register.dart';
part 'lesson_pick.dart';
part 'lesson_sign.dart';

/// 수업 개수 탭 콘텐츠
///
/// 수업은 회원의 싸인을 받아야 인정된다.
/// - 상단: 회원 등록 / 세션 싸인 받기 버튼
/// - 세션 기록: 받은 싸인 기록 (서명 미리보기·회차·시각)
class LessonSection extends StatefulWidget {
  LessonSection({super.key});

  @override
  State<LessonSection> createState() => _LessonSectionState();
}

class _LessonSectionState extends State<LessonSection> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _LessonStore.instance.load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 회원 등록 화면을 연다 — 폰은 밀려 들어오고 PC는 모달로 뜬다
  Future<void> _register() async {
    final added = await showFullPage<bool>(context, (_) => _RegisterScreen());
    if (added == true && mounted) await _load();
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
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    // 상단 액션 버튼 두 개 — 폰·PC 공통. 대표·관리자는 수행자가 아니라 안 그린다
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
                  icon: CupertinoIcons.signature,
                  label: '세션 싸인 받기',
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
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      );
    }

    return Column(
      children: [
        // 월 목표·담당 회원은 본인 기준이라 대표·관리자에게는 뜻이 없다
        if (!_viewOnly) ...[
          _SessionGoalCard(),
          SizedBox(height: 16),
          actions,
          SizedBox(height: 16),
        ],
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
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 이번 달 세션 목표
///
/// 서버에 목표치 개념이 없어서 고정값이다 (backend-gap.md 4번).
/// 누가 정하는지(대표 일괄 / 점장이 지점별)가 정해지면 서버에서 받아 온다.
const _sessionGoal = 50;

/// 이번 달 목표 진행 — 세션 수와 담당 회원을 한자리에서 보여준다
///
/// 숫자만 있으면 지금 잘 가고 있는지 알 수 없어서 목표 대비 막대를 같이 둔다.
class _SessionGoalCard extends StatelessWidget {
  _SessionGoalCard();

  @override
  Widget build(BuildContext context) {
    final store = _LessonStore.instance;
    final now = DateTime.now();
    final count = store.signs
        .where(
          (s) => s.signedAt.year == now.year && s.signedAt.month == now.month,
        )
        .length;
    final left = _sessionGoal - count;
    final reached = left <= 0;
    final color = reached ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('${now.month}월 세션', style: AppTextStyles.label),
              ),
              Text(
                '$count',
                style: AppTextStyles.title2.copyWith(color: color),
              ),
              Text(
                ' / $_sessionGoal회',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: count / _sessionGoal, color: color),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                reached
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.flag_fill,
                size: 13,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  reached ? '이번 달 목표를 채웠어요' : '목표까지 $left회 남았어요',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                '담당 회원 ${store.myMembers.length}명',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
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
      scale: 0.96,
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
