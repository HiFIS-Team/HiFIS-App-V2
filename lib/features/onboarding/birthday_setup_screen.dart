import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/native_picker.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/pressable.dart';

/// 생일 등록 — **첫 로그인에 딱 한 번** (2026-09-21 대표 요청)
///
/// 받아서 두 가지에 쓴다.
///
/// | | |
/// |---|---|
/// | 달력 | `이건주님 생일` 로 해마다 선다 |
/// | 근태 | **그날은 휴무다** — 결근·개인 업무 누락이 안 잡힌다 |
///
/// ## 한 번 적으면 다시 안 뜬다
///
/// 서버가 `birthday` 를 채우고, 두 번째 요청은 409 로 막는다
/// (`POST /employees/me/birthday`). 게이트는 그 값이 비었는지만 본다
/// ([Employee.needsBirthday]) — 앱에 따로 '봤다' 표시를 두지 않는다.
/// 표시를 두면 앱을 지우거나 기기를 바꿨을 때 다시 뜬다.
///
/// ## 건너뛰기가 없다
///
/// 넘기면 그 사람만 달력에서 빠지고 휴무도 못 받는데, 나중에 넣을 자리가
/// 어디에도 없다 (고치는 길이 없는 값이라 프로필에도 안 연다).
/// 근무 설정([ScheduleSetupScreen])과 같은 규칙이다.
class BirthdaySetupScreen extends StatefulWidget {
  const BirthdaySetupScreen({super.key, this.onDone});

  /// 저장이 끝나면 알린다 (게이트가 다음 화면으로 넘어간다)
  final VoidCallback? onDone;

  @override
  State<BirthdaySetupScreen> createState() => _BirthdaySetupScreenState();
}

class _BirthdaySetupScreenState extends State<BirthdaySetupScreen> {
  /// 고른 생일 — null 이면 아직 안 골랐다 (저장 버튼이 잠겨 있다)
  ///
  /// **미리 채우지 않는다.** 오늘 날짜로 띄워 두면 그대로 저장해 버리는
  /// 사람이 생기는데, 한 번 넣으면 못 고치는 값이다.
  DateTime? _picked;

  bool _busy = false;

  /// 고르개를 열 때 서는 자리 — **서른 살쯤**에서 시작한다
  ///
  /// 오늘에서 시작하면 연도를 서른 번 넘겨야 한다. 직원 나이대 한가운데를
  /// 잡아 두면 위아래로 몇 번만 움직이면 된다.
  static DateTime get _opensAt {
    final now = DateTime.now();
    return DateTime(now.year - 30, now.month, now.day);
  }

  String get _label {
    final at = _picked;
    if (at == null) return '생년월일을 골라주세요';
    return '${at.year}년 ${at.month}월 ${at.day}일';
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: _picked ?? _opensAt,
      first: DateTime(now.year - 100),
      // **오늘까지다** — 앞날은 서버도 400 으로 막는다
      last: now,
      title: '생년월일',
    );
    if (picked == null) return;
    setState(() => _picked = picked);
  }

  Future<void> _save() async {
    final at = _picked;
    if (at == null) return;
    setState(() => _busy = true);
    try {
      currentUser = await StaffApi.setBirthday(at);
      if (!mounted) return;
      widget.onDone?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _picked != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.cake_rounded, size: 26, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text('생일이 언제세요?', style: AppTextStyles.title1),
        const SizedBox(height: 8),
        Text(
          '달력에 생일이 표시되고, 그날은 휴무로 처리돼요.\n'
          '한 번만 입력하면 다시 묻지 않아요.',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        // 근무 설정의 시간 상자와 같은 모양 — 온보딩 두 장이 한 벌로 보이게
        Pressable(
          onTap: _busy
              ? () {}
              : () {
                  _pick();
                },
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('생년월일', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        _label,
                        style: chosen
                            ? AppTextStyles.title3
                            : AppTextStyles.title3.copyWith(
                                color: AppColors.gray400,
                              ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.gray300,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.gray400,
            ),
            const SizedBox(width: 4),
            // 고치는 길이 없다는 것을 **누르기 전에** 말해 둔다
            Text(
              '입력 후에는 변경할 수 없어요.',
              style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
            ),
          ],
        ),
      ],
    );

    void onSave() {
      if (chosen && !_busy) _save();
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(36, 30, 36, 30),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    content,
                    const SizedBox(height: 28),
                    AppButton(
                      label: '저장',
                      filled: chosen,
                      busy: _busy,
                      onTap: onSave,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 폰은 폼 화면들(월차 신청·급여 신청)처럼 흰 바탕 + 아래 고정 버튼
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                40,
                24,
                GlassBottomButton.inset(context),
              ),
              child: content,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomButton(
              label: '저장',
              active: chosen,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}
