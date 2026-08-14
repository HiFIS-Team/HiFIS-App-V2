/// 셸 헤더(바코드 줄) **맨 왼쪽**에 화면이 끼워 넣는 버튼
///
/// 헤더는 [MainShell] 이 그리고 화면 위에 떠 있어서, 화면 쪽에서 직접
/// 버튼을 놓을 자리가 없다. 지점 고르개(`branchScope`)와 같은 방식으로
/// **값 하나를 여기 두고 헤더가 읽는다.**
///
/// 지금 쓰는 곳은 업무 화면의 `내 업무 추가` 하나다 (2026-08-14).
///
/// - 넣을 때는 `headerAction.value = ...`
/// - **화면을 벗어날 때 반드시 비운다** (`dispose`·탭 전환). 안 비우면
///   다른 탭에서도 남의 버튼이 떠 있게 된다
library;

import 'package:flutter/foundation.dart';

/// 헤더 맨 왼쪽 버튼 한 개 — null 이면 아무것도 안 그린다
class HeaderAction {
  const HeaderAction({required this.symbol, required this.onPressed});

  /// SF 심볼 이름 — [sfIcon] 매핑표에 있어야 안드로이드에서 안 깨진다
  final String symbol;
  final VoidCallback onPressed;
}

final headerAction = ValueNotifier<HeaderAction?>(null);

/// 로그아웃할 때 되돌린다 — 다음 사람 화면에 앞사람 버튼이 남지 않게
void resetHeaderAction() => headerAction.value = null;
