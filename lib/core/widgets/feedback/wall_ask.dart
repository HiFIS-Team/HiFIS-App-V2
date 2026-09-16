import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';
import 'app_dialog.dart';

/// 컴플레인을 승인할 때 **매장 TV 에 걸지 물어본다** (2026-09-16 대표 요청)
///
/// 해결은 해결인데 **벽에 걸 글이 아닌** 컴플레인이 있다. 사람이나 무리를
/// 지목하는 것이 그렇다 — 회원이 보는 벽에 다른 회원 이야기를 거는 셈이다.
/// 실제로 두 건 나왔다 (운동부 학생들 · 특정 회원 인상착의).
///
/// **어느 쪽을 골라도 승인은 된다.** 점수·회원 문자·앱 기록은 그대로 가고
/// 빠지는 것은 매장 TV 하나뿐이라, 취소가 아니라 두 갈래로 묻는다.
///
/// | 돌아오는 값 | 뜻 |
/// |---|---|
/// | `true` | 승인하고 **벽에 건다** |
/// | `false` | 승인하되 **벽에는 안 건다** |
/// | `null` | 바깥을 눌러 닫았다 — **아무것도 안 한다** |
///
/// 승인은 되돌리기 번거로운 일이라, 닫으면 아무 일도 안 일어나는 쪽이 맞다.
/// 부르는 쪽은 `null` 이면 그냥 빠져나온다.
Future<bool?> askPutOnWall(BuildContext context) =>
    showAppDialog<bool>(context, (context) => _WallCard());

class _WallCard extends StatelessWidget {
  _WallCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tv_rounded, size: 28, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            '매장 TV 에 걸까요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.title3,
          ),
          SizedBox(height: 10),
          Text(
            // **안 걸어도 무엇이 되는지를 적는다.** 안 적으면 '안 걸기' 가
            // 반려처럼 보여서 누르기를 망설인다
            '회원들이 보는 화면이에요.\n'
            '안 걸어도 해결 완료·점수·회원 문자는 그대로 가요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          SizedBox(height: 22),
          // **세로로 쌓는다** — 둘 다 승인이라 글자가 길어서, 가로로 두면
          // `승인하고 안 걸기` 가 두 줄로 접힌다
          _WallButton(
            label: '승인하고 TV 에 걸기',
            filled: true,
            onTap: () => Navigator.pop(context, true),
          ),
          SizedBox(height: 8),
          _WallButton(
            label: '승인만 하고 안 걸기',
            filled: false,
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _WallButton extends StatelessWidget {
  _WallButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
