part of 'lesson_section.dart';

/// 싸인 받기 화면 — 회원이 손가락으로 서명하고 완료를 누르면 기록된다
class _SignScreen extends StatefulWidget {
  _SignScreen({required this.member});

  final _LessonMember member;

  @override
  State<_SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<_SignScreen> {
  final List<List<Offset>> _strokes = [];

  /// 이번 회차 운동일지를 찾는 중
  bool _checking = true;

  /// 일지가 없다 — 서명 패드 대신 경고를 그린다
  bool _needsLog = false;

  /// 서명 당시 패드 크기 — 이 크기로 PNG를 굽는다
  Size _padSize = Size.zero;

  bool _saving = false;

  bool get _signed => _strokes.any((stroke) => stroke.length > 1);

  @override
  void initState() {
    super.initState();
    _checkWorkout();
  }

  /// **일지를 써야 싸인이다** (2026-08-31 대표 요청)
  ///
  /// 서버도 `NO_WORKOUT_LOG` 로 막지만, 거기까지 가면 **회원이 이미 서명을
  /// 마친 뒤**라 다시 받아야 한다. 그래서 패드를 그리기 전에 먼저 본다.
  ///
  /// 못 받아오면 **막지 않는다** — 통신이 흔들렸다고 싸인을 못 받으면
  /// 회원을 앞에 세워 두고 손을 놓게 된다. 그 경우는 서버가 걸러 준다.
  Future<void> _checkWorkout() async {
    try {
      final logs = await WorkoutApi.list(
        widget.member.id,
        kind: WorkoutKind.pt,
      );
      var written = 0;
      for (final log in logs) {
        final no = log.sessionNo ?? 0;
        if (no > written) written = no;
      }
      if (!mounted) return;
      setState(() {
        _needsLog = written < widget.member.nextWorkoutNo;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 경고에서 나가면 **수업 개수 화면까지** 돌아간다 (회원 고르기도 같이 닫는다)
  void _exitToLesson() {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (navigator.canPop()) navigator.pop();
  }

  void _clear() => setState(_strokes.clear);

  Future<void> _complete() async {
    if (!_signed) {
      AppToast.show(context, '먼저 싸인을 받아주세요');
      return;
    }
    if (_saving) return;

    final member = widget.member;
    final registration = member.registration;
    if (registration == null) {
      AppToast.show(context, '등록권이 없어 기록할 수 없어요');
      return;
    }

    // 굽기 전에 읽어 둔다 — await 뒤에는 context 를 쓰지 않는다
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    setState(() => _saving = true);
    try {
      final image = await _encodeSignature(
        _strokes,
        _padSize,
        pixelRatio: pixelRatio,
      );
      final result = await SessionSignApi.create(
        registrationId: registration.id,
        signatureBase64: image,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        '${member.name}님 ${result.sign.sessionNo}회차 수업이 기록되었습니다',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 일지가 없다 — **서명 패드를 아예 안 연다** (2026-08-31 대표 요청)
  ///
  /// 예전에는 다 받고 나서 아래 토스트로 알렸다. 그러면 회원이 서명을 마친
  /// 뒤에 무를 수 없다는 말을 듣게 된다.
  Widget _needWorkout(_LessonMember member) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 72,
                    color: AppColors.warning,
                  ),
                  SizedBox(height: 24),
                  Text(
                    '운동 일지를\n작성해주세요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title1.copyWith(height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '${member.name}님 ${member.nextWorkoutNo}회차 일지가 아직 없어요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'sign-need-workout',
                    label: '나가기',
                    onPressed: _exitToLesson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    // 일지를 확인하는 동안은 패드를 안 그린다 — 그렸다가 경고로 바뀌면
    // 회원이 이미 손을 대고 있다
    if (_checking) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: DelayedSpinner.bare()),
      );
    }
    if (_needsLog) return _needWorkout(member);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${member.done + 1}/${member.total}회차 수업 확인',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      // 다시 쓰기
                      Pressable(
                        onTap: _clear,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_counterclockwise,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '다시 쓰기',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                // 서명 패드 — 남은 화면을 채운다
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _padSize = constraints.biggest;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: GestureDetector(
                            onPanStart: (d) =>
                                setState(() => _strokes.add([d.localPosition])),
                            onPanUpdate: (d) => setState(
                              () => _strokes.last.add(d.localPosition),
                            ),
                            child: Container(
                              color: AppColors.gray50,
                              child: Stack(
                                children: [
                                  if (!_signed)
                                    Center(
                                      child: Text(
                                        '여기에 싸인해주세요',
                                        style: AppTextStyles.body1.copyWith(
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ),
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: _SignPainter(
                                      strokes: _strokes,
                                      color: AppColors.textPrimary,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('${member.name} 싸인', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 하단 고정: 완료 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'sign-done',
                    label: _saving ? '기록 중...' : '싸인 완료',
                    // 서명해야 채워진 상태가 되고,
                    // 미서명 시 동작은 _complete에서 무시한다
                    filled: _signed && !_saving,
                    onPressed: _complete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 서명 획을 그리는 페인터
class _SignPainter extends CustomPainter {
  _SignPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignPainter oldDelegate) => true;
}
