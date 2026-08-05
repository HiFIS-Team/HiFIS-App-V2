import 'package:flutter/material.dart';

/// 끝이 정해지지 않은 목록을 정해진 높이 안에 가둔다.
///
/// 직원 명단처럼 **사람이 늘면 그만큼 길어지는** 자리에 쓴다.
/// 그냥 두면 스무 명만 넘어도 화면 밖으로 나가서, 고르려면 뒤 화면째
/// 스크롤해야 한다 (프로젝트 참여 멤버 팝업에서 실제로 그랬다).
///
/// **보이는 모양은 그대로다** — 줄 높이·간격·순서를 건드리지 않고
/// 넘치는 만큼만 안에서 스크롤한다.
class ScrollBox extends StatelessWidget {
  ScrollBox({super.key, required this.maxHeight, required this.child});

  /// 여기까지만 자란다. 내용이 이보다 짧으면 그 높이 그대로다.
  final double maxHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 화면이 낮으면 상한도 같이 낮춘다 — 폰 가로 모드에서 팝업이 화면을 덮지 않게
    final half = MediaQuery.sizeOf(context).height / 2;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight < half ? maxHeight : half,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// 아바타 알약을 줄바꿈해 늘어놓는 자리의 높이 상한 (네 줄쯤)
const double kChipBoxHeight = 140;

/// 세로로 한 줄씩 세우는 명단의 높이 상한 (일곱 줄쯤)
const double kListBoxHeight = 320;
