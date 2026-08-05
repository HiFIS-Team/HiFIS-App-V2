import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 결재 버튼 한 쌍 (반려 · 승인)
///
/// 프로젝트 기한 연장 카드와 전자결재 상세가 같이 쓴다. 같은 일을 하는
/// 자리라 모양이 갈리면 안 된다. 홈 카드·일정 하루 팝업처럼 줄 안에
/// 들어가는 작은 자리는 [MiniButton] 을 쓴다.
///
/// **반려가 왼쪽, 승인이 오른쪽이다.** 승인만 파랗게 채우고 반려는 테두리만
/// 두르되 글씨는 빨갛게 한다 — 되돌릴 수 없는 쪽이라 눈에 띄어야 한다.
class DecideButtons extends StatelessWidget {
  DecideButtons({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.busy = false,
    this.fill = false,
  });

  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// 서버에 보내는 중 — **둘 다 안 눌린다**
  ///
  /// 목록을 다시 받아 줄이 사라질 때까지 버튼이 그대로 남아 있어서,
  /// 안 잠그면 승인을 두 번 보내고 두 번째가 400 으로 떨어진다
  /// (성공 토스트 뒤에 에러 토스트가 따라 뜬다).
  final bool busy;

  /// true면 가로를 꽉 채운다 (폰에서 버튼을 아래로 내릴 때)
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final reject = Pressable(
      onTap: busy ? () {} : onReject,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text(
          '반려',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final approve = Pressable(
      onTap: busy ? () {} : onApprove,
      scale: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '승인',
          style: AppTextStyles.body2.copyWith(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    // 도는 동안 둘 다 옅어진다 — 하나만 흐리면 다른 쪽은 눌릴 것처럼 보인다
    if (busy) {
      return Opacity(opacity: 0.5, child: _row(reject, approve));
    }
    return _row(reject, approve);
  }

  Widget _row(Widget reject, Widget approve) {
    return Row(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: fill
          ? [
              Expanded(child: reject),
              SizedBox(width: 8),
              Expanded(child: approve),
            ]
          : [reject, SizedBox(width: 6), approve],
    );
  }
}
