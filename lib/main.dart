import 'dart:async';

import 'package:flutter/material.dart';

import 'core/data/current_user.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/util/capture_guard.dart';
import 'core/util/platform.dart';
import 'core/widgets/app_loading.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/auth_session.dart';
import 'features/main/main_shell.dart';
import 'features/onboarding/schedule_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 캡처 방지를 먼저 켠다 — 대표면 아래 restore 가 꺼 준다.
  // 로그인 전에도 켜 둬야 못 막는 순간이 안 생긴다.
  unawaited(CaptureGuard.apply());
  // 자동 로그인 여부를 먼저 읽어야 스플래시 뒤에서 맞는 화면을 그릴 수 있다
  await AuthSession.instance.restore();
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
    // iOS 는 스크린샷을 못 막는 대신, 녹화·미러링이 도는 동안 같은 커버로 덮는다
    CaptureGuard.recording.addListener(_onRecording);
  }

  @override
  void dispose() {
    CaptureGuard.recording.removeListener(_onRecording);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRecording() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 데스크톱에서는 창이 포커스만 잃어도 inactive가 되어 커버가 덮이므로
    // (앱이 멈춘 것처럼 보인다) 프라이버시 커버를 모바일에서만 쓴다
    if (isDesktop) return;
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
      // 비활성 상태에 가림막을 덮는다 (토스식 프라이버시 커버).
      // 화면 녹화·미러링이 도는 동안에도 **같은 가림막**을 쓴다 — iOS 가
      // 스크린샷을 못 막으니 녹화만이라도 빈 화면이 찍히게 한다.
      builder: (context, child) => Stack(
        children: [
          child!,
          if ((_obscured || CaptureGuard.recording.value) && !isDesktop)
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

/// 로그인 상태에 따라 로그인 화면과 메인을 바꿔 낀다.
///
/// 로그인/로그아웃은 [AuthSession]의 값만 바꾸면 되고, 화면 교체는 여기서
/// 한 번에 처리한다. 갈아 끼울 때는 짧게 겹쳐 넘겨 뚝 끊기지 않게 한다.
class _AuthGate extends StatefulWidget {
  _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  /// 근무 설정을 방금 마쳤는지 — 저장 직후 메인으로 넘어가기 위한 표시
  bool _scheduleDone = false;

  Widget _signedInScreen() {
    // 근무 시간·요일이 없으면 서버가 지각·결근을 판정하지 못한다.
    // 첫 로그인에 한 번 받고 넘어간다.
    final needsSchedule = currentUser?.needsSchedule ?? false;
    if (needsSchedule && !_scheduleDone) {
      return ScheduleSetupScreen(
        key: ValueKey('schedule'),
        onDone: () => setState(() => _scheduleDone = true),
      );
    }
    return MainShell(key: ValueKey('main'));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthSession.instance,
      builder: (context, signedIn, _) => AnimatedSwitcher(
        duration: Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: signedIn
            ? _signedInScreen()
            : LoginScreen(key: ValueKey('login')),
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
  /// 메인 화면을 스플래시 뒤에서 미리 만들어 두는 중
  bool _warming = false;

  /// 스플래시를 걷어내는 중
  bool _ready = false;

  /// 다 걷어내서 스플래시를 트리에서 뺀 상태
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: 2600), _warmUp);
  }

  /// 스플래시 뒤에 메인을 먼저 그려두고, 다 그려진 다음에 걷어낸다.
  ///
  /// 예전처럼 넘어가는 순간에 메인을 처음 만들면 화면 만드는 비용과
  /// 사라지는 애니메이션이 한 프레임에 겹쳐서 진입할 때 끊겨 보인다.
  void _warmUp() {
    if (!mounted) return;
    setState(() => _warming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 배치와 네이티브 뷰(탭바) 생성까지 자리를 잡을 여유를 준다
      Timer(Duration(milliseconds: 120), () {
        if (mounted) setState(() => _ready = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_warming) _AuthGate(),
        if (!_done)
          IgnorePointer(
            ignoring: _ready,
            child: AnimatedOpacity(
              opacity: _ready ? 0 : 1,
              duration: Duration(milliseconds: 420),
              curve: Curves.easeOut,
              onEnd: () {
                if (_ready && mounted) setState(() => _done = true);
              },
              child: Scaffold(
                backgroundColor: AppColors.surface,
                // 런치 스크린 마크(110pt)와 같은 크기·위치에서 이어지도록
                body: Center(child: AppLoading(size: 110)),
              ),
            ),
          ),
      ],
    );
  }
}
