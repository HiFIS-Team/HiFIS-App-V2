import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../input/app_button.dart';

/// 목록을 **못 받았을 때** 자리를 채우는 카드
///
/// [EmptyCard] 와 같은 틀이되 다시 받는 버튼이 붙는다. 둘을 가르는 게 이
/// 위젯의 이유다 — 예전에는 서버가 죽어도 `아직 공지가 없어요` 로 떴다.
/// **비어 있는 것과 못 받은 것은 다른 일이고, 하나는 사용자가 할 게 없고
/// 하나는 다시 눌러 보면 된다.**
///
/// 무엇을 못 받았는지는 안 적는다. `공지를 못 받았어요` 처럼 자리마다 문구를
/// 만들면 결국 또 갈린다 — 어차피 그 화면에 서 있는 사람은 뭘 보려던 참인지
/// 안다. 대신 **왜 안 됐는지**를 적는다 (거의 인터넷이다).
class FailedCard extends StatelessWidget {
  FailedCard({super.key, required this.onRetry, this.framed = true});

  /// 다시 받기 — 누르면 [busy] 로 잠기는 건 부르는 쪽이 정한다
  final VoidCallback onRetry;

  /// false면 카드 면과 여백을 빼고 안쪽만 그린다 (이미 카드 안일 때)
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: framed ? EdgeInsets.symmetric(vertical: 44) : EdgeInsets.zero,
      decoration: framed ? AppDecorations.card() : null,
      child: Column(
        // 높이가 정해진 칸 안에서도 내용만큼만 잡는다 (EmptyCard 와 같다)
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 28,
              color: AppColors.gray400,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '불러오지 못했어요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            '인터넷 연결을 확인하고 다시 눌러 주세요',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          // 글자 폭만큼만 — 꽉 채우면 이 자리가 화면의 주인공처럼 보인다
          AppButton(label: '다시 받기', onTap: onRetry, shrinkWrap: true),
        ],
      ),
    );
  }
}
