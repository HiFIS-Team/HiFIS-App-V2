import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_loading.dart';
import 'features/main/main_shell.dart';

void main() {
  runApp(HiFISApp());
}

class HiFISApp extends StatelessWidget {
  HiFISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiFIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: _SplashGate(),
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
