import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// **늦을 때만** 보이는 로딩 스피너
///
/// 서버가 가까우면 값이 10ms 안에 온다. 그 사이에 스피너를 그렸다 지우면
/// 한두 프레임만 떴다 사라져서 **화면이 깜빡인다.** 게다가 스피너 자리는
/// 200 남짓인데 내용은 그 몇 배라 높이까지 튄다.
///
/// 그래서 [delay] 동안은 아무것도 안 그리고, 그보다 오래 걸릴 때만 나타난다.
/// **느린 경우의 모양은 예전 그대로다** — 오래 기다리는데 빈 화면만 두면
/// 멈춘 줄 안다.
class DelayedSpinner extends StatefulWidget {
  DelayedSpinner({super.key, this.height}) : bare = false;

  /// 부모가 이미 크기를 정해 줄 때 (`Expanded` 안 등) — 자리 계산을 안 한다
  DelayedSpinner.bare({super.key}) : height = null, bare = true;

  /// 이만큼 지나도 안 끝나면 그때 보여준다
  static const delay = Duration(milliseconds: 220);

  /// 로딩 자리의 높이. null 이면 스피너가 뜨기 전까지 자리를 안 차지한다
  /// (자리를 잡아 봐야 내용 높이와 달라서 어차피 한 번 튄다).
  final double? height;

  final bool bare;

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner> {
  bool _show = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DelayedSpinner.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget get _spinner => CircularProgressIndicator(
    strokeWidth: 2.4,
    valueColor: AlwaysStoppedAnimation(AppColors.primary),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.bare) {
      return Center(child: _show ? _spinner : SizedBox.shrink());
    }
    if (widget.height case final height?) {
      // 높이를 아는 자리는 지켜 준다 — 여기서 자리를 비우면 내용이 들어올 때 튄다
      return SizedBox(
        height: height,
        child: Center(child: _show ? _spinner : SizedBox.shrink()),
      );
    }
    if (!_show) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: _spinner),
    );
  }
}
