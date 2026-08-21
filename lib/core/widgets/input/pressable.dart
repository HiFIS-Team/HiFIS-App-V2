import 'package:flutter/material.dart';

/// 탭 래퍼 — **눌림 표시를 안 준다** (2026-08-21 대표 결정).
///
/// 예전에는 누르는 동안 살짝 줄었다 돌아왔다(`AnimatedScale`). 걷어낸 이유:
///
/// - **두 번 누른 것처럼 보였다.** 크기가 줄었다 커지는 것과 화면이 바뀌는
///   것이 겹쳐서, 아바타가 움찔한 뒤 팝업이 튀어나오면 두 번 튄 것으로 읽혔다
///   (프로젝트 상세 인원 조회에서 실제로 걸렸다).
/// - **끝까지 재생되지도 않았다.** 되돌아오는 시점이 손을 떼는 순간이라,
///   빠르게 누르면 1.5% 만 움직였다가 방향을 틀었다 — 그 움찔거림이 원인이었다.
/// - **세기가 제각각이었다.** `0.55` 부터 `0.995` 까지 열다섯 가지가 섞여
///   있어서 같은 동작인데 자리마다 다르게 느껴졌다.
/// - 무신사·배민 같은 앱들도 버튼에 눌림 애니메이션을 안 준다.
///
/// **화면이 바뀌는 것 자체가 반응이다.** 팝업이 안 뜨는 자리(칩 켜기·체크)는
/// 눌린 결과가 그 자리에서 보이므로 따로 표시할 것이 없다.
///
/// 그래도 남긴 것 둘 —
/// - [padding] 은 **자리를 만드는 값**이다. 빼면 누를 수 있는 넓이가 줄어든다.
/// - 데스크톱 손가락 커서. 애니메이션이 아니라 **눌 수 있다는 표시**라,
///   빼면 마우스로는 어디가 눌리는지 알 방법이 없어진다.
class Pressable extends StatelessWidget {
  Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.padding,
  });

  final VoidCallback onTap;

  /// 꾹 누르기 — 없으면 길게 눌러도 탭과 같다 (기본 동작 그대로)
  final VoidCallback? onLongPress;

  final Widget child;

  /// 누를 수 있는 넓이 — **모양이 아니라 자리다**
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // 데스크톱(macOS·윈도우)에서 눌 수 있는 요소임을 커서로 알려준다
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
