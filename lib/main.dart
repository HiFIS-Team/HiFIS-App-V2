import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_loading.dart';
import 'features/main/main_shell.dart';

void main() {
  runApp(HiFISApp());
}

class HiFISApp extends StatefulWidget {
  HiFISApp({super.key});

  @override
  State<HiFISApp> createState() => _HiFISAppState();
}

class _HiFISAppState extends State<HiFISApp> with WidgetsBindingObserver {
  /// 앱이 비활성 상태(앱 전환 화면 등)일 때 화면을 가릴지 여부
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscured = state != AppLifecycleState.resumed;
    if (obscured != _obscured) setState(() => _obscured = obscured);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiFIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: _SplashGate(),
      // 앱 전환 화면(멀티태스킹)에서는 내용 대신 마크만 보이도록
      // 비활성 상태에 가림막을 덮는다 (토스식 프라이버시 커버)
      builder: (context, child) => Stack(
        children: [
          child!,
          if (_obscured)
            Positioned.fill(
              child: Container(
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/hifis_mark.png',
                  height: 96,
                  cacheHeight: 288,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 앱 시작 시 케틀벨 로딩 애니메이션을 한 사이클 보여준 뒤 메인으로 넘어간다.
/// 실제 초기 데이터 로딩이 생기면 타이머 대신 그 완료 시점으로 교체한다.
class _SplashGate extends StatefulWidget {
  _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 350),
      child: _ready
          ? MainShell()
          : Scaffold(
              key: ValueKey('splash'),
              backgroundColor: AppColors.surface,
              body: Center(child: AppLoading(size: 84)),
            ),
    );
  }
}
