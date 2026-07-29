import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
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

  /// 데스크톱(macOS)에서는 넓은 창에서도 폰 레이아웃이 늘어지지 않게
  /// 가운데 고정 폭으로 담고, 양옆은 옅은 회색 여백으로 채운다
  Widget _desktopFrame(Widget child) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return child;
    return ColoredBox(
      color: AppColors.gray50,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560),
          child: Container(
            // 회색 여백과 콘텐츠의 경계를 헤어라인으로 살짝 구분한다
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: AppColors.gray100),
              ),
            ),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
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
          _desktopFrame(child!),
          if (_obscured)
            Positioned.fill(
              child: Container(
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/hifis_mark.png',
                  // 런치 스크린 마크와 같은 크기
                  height: 110,
                  cacheHeight: 330,
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
              // 런치 스크린 마크(110pt)와 같은 크기·위치에서 이어지도록
              body: Center(child: AppLoading(size: 110)),
            ),
    );
  }
}
