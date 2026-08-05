import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/app_button.dart';
import 'app_dialog.dart';

/// 반려 사유를 받는 창 — 급여·월차·홈 결재함이 같이 쓴다
///
/// 사유는 **신청한 사람에게 그대로 간다.** 비워 두면 왜 반려됐는지 알 길이
/// 없어서 빈 채로는 닫히지 않는다.
///
/// [hint] 만 자리마다 다르다 — 급여와 월차는 반려하는 이유가 달라서
/// 예시 문장이 같으면 도움이 안 된다.
Future<String?> askRejectReason(BuildContext context, {required String hint}) {
  final controller = TextEditingController();
  return showAppDialog<String>(context, (context) {
    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('반려 사유', style: AppTextStyles.title3),
          SizedBox(height: 4),
          Text('신청한 사람에게 그대로 전달돼요', style: AppTextStyles.caption),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              minLines: 3,
              style: AppTextStyles.body2,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '닫기',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '반려',
                  color: AppColors.error,
                  textColor: Colors.white,
                  onTap: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(context, text);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });
}
