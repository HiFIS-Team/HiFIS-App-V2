import 'package:flutter/material.dart';

/// 그림자 토큰 — **높이 네 단계**
///
/// 연회색 배경 위 흰 면에만 쓴다. 진한 그림자 금지.
///
/// 예전에는 자리마다 값을 직접 적어서 알파가 15가지였다. 같은 층(메뉴와
/// 토스트, 검색바와 입력바)인데 무게가 달라 보이는 자리가 있었다.
/// **새 화면에서 그림자가 필요하면 여기서 고른다. 값을 새로 적지 않는다.**
///
/// | | 무엇 | 값 |
/// |---|---|---|
/// | [card] | 면 위에 놓인 카드 | 0.04 · 24 · (0,6) |
/// | [popup] | 위에 뜬 판 — 메뉴·토스트·탭바 | 0.12 · 24 · (0,8) |
/// | [float] | 떠 있는 바 — 검색바·입력바·반응 칩 | 0.12 · 32 · (0,10) |
/// | [modal] | 화면을 덮는 것 — 팝업 카드·패널 | 0.20 · 40 · (0,14) |
///
/// [float] 이 [popup] 보다 무거운 건 자리 때문이다 — 떠 있는 바는 **콘텐츠가
/// 그 아래로 지나가서** 그림자가 약하면 바닥에 붙어 보인다.
abstract final class AppShadows {
  /// 그림자 잉크 — **순검정이 아니라 남색 기가 도는 먹색**이다
  ///
  /// 순검정은 회색 면 위에서 탁해진다. 예전에는 절반이 `Colors.black` 이라
  /// 같은 층인데 한쪽만 무겁게 떨어졌다.
  static const ink = Color(0xFF101828);

  /// 면 위에 놓인 카드
  static const card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 24, offset: Offset(0, 6)),
  ];

  /// 위에 뜬 판 — 메뉴·토스트·탭바
  static const popup = [
    BoxShadow(color: Color(0x1F101828), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// 떠 있는 바 — 검색바·입력바·반응 칩
  static const float = [
    BoxShadow(color: Color(0x1F101828), blurRadius: 32, offset: Offset(0, 10)),
  ];

  /// 화면을 덮는 것 — 팝업 카드·데스크톱 패널
  static const modal = [
    BoxShadow(color: Color(0x33101828), blurRadius: 40, offset: Offset(0, 14)),
  ];
}
