import 'package:flutter/material.dart';

/// 카드용 그림자 토큰
///
/// 연회색 배경 위 흰 카드에만 사용한다. 진한 그림자 금지.
abstract final class AppShadows {
  /// 그림자 잉크 — **순검정이 아니라 남색 기가 도는 먹색**이다
  ///
  /// 앱의 모든 그림자가 이 색을 쓴다. 예전에는 절반이 `Colors.black` 이라
  /// 같은 층인데 한쪽만 무겁게 떨어졌다 (순검정은 회색 면 위에서 탁해진다).
  ///
  /// 진하기는 자리마다 다르다 — 떠 있는 버튼은 옅게, 팝업은 진하게.
  /// 그 값까지 하나로 묶으면 버튼과 모달이 같은 높이로 보인다.
  static const ink = Color(0xFF101828);

  static const card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 24, offset: Offset(0, 6)),
  ];
}
