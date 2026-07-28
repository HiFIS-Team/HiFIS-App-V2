import 'dart:ui';

import 'package:flutter/material.dart';

/// 스크롤 시 화면 상단에 생기는 프로그레시브 블러
///
/// Stack의 상단 레이어로 두고, 스크롤 오프셋에서 계산한 collapse(0~1)를
/// 넘겨서 사용한다. color는 화면 배경색과 맞춘다.
class TopFrost extends StatelessWidget {
  TopFrost({super.key, required this.collapse, required this.color});

  /// 0이면 투명, 1이면 완전히 흐려진 상태.
  final double collapse;

  /// 그라데이션에 사용할 화면 배경색.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          // sigma 0은 렌더링 오류가 나므로 최소값을 둔다
          filter: ImageFilter.blur(
            sigmaX: 20 * collapse + 0.01,
            sigmaY: 20 * collapse + 0.01,
          ),
          child: Container(
            height: topInset + 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.85 * collapse),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
