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

  /// 서명 당시 패드 크기 — 이 크기로 PNG를 굽는다
  Size _padSize = Size.zero;

  bool _saving = false;

  bool get _signed => _strokes.any((stroke) => stroke.length > 1);

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

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

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
