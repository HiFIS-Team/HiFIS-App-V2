import 'package:flutter/widgets.dart';

import '../widgets/android_tab_bar.dart';
import 'platform.dart';
import 'sf_symbols.dart';

/// 스크롤 콘텐츠가 하단바에 가리지 않도록 아래에 남겨야 할 여백.
///
/// 하단바 모양이 플랫폼마다 달라서(iOS 떠 있는 캡슐 / 안드로이드 바닥 바 /
/// 데스크톱은 사내톡 필만) 고정값을 쓰면 어딘가는 잘린다.
double bottomBarInset(BuildContext context) {
  final safe = MediaQuery.paddingOf(context).bottom;

  // 데스크톱은 하단바가 없고 우하단 사내톡 필만 떠 있다
  if (isDesktop) return 80;

  // 안드로이드는 바닥에 붙는 바(64) 위로 가운데 버튼이 10만큼 솟는다
  if (!isApple) return safe + AndroidTabBar.barHeight + 24;

  // iOS는 떠 있는 캡슐(56)이 아래 여백 10 위에 놓인다
  return safe + 78;
}
