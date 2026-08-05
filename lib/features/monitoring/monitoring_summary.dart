part of 'monitoring_screen.dart';

// ---------------------------------------------------------------------------
// 오늘 요약
// ---------------------------------------------------------------------------

/// 잔디 옆 세로 요약 — 오늘 것만 본다
class _Today extends StatelessWidget {
  _Today({
    required this.people,
    required this.staffTotal,
    required this.visits,
    required this.failed,
    required this.yesterday,
    required this.last,
  });

  final int people;

  /// 재직 인원 — 접속률의 분모
  final int staffTotal;

  final int visits;
  final int failed;

  /// 어제 접속 횟수
  final int yesterday;

  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final at = last;
    final diff = visits - yesterday;
    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(radius: 20),
      // 옆 잔디에 높이를 맞추면 남는 자리가 생긴다. **Spacer 를 쓰면
      // IntrinsicHeight 가 높이를 재는 동안 터지므로**(급여 화면에서 겪었다)
      // 위·아래 두 덩어리로 나누고 빈자리를 사이에 몰아준다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 7),
                  Text('오늘', style: AppTextStyles.label),
                ],
              ),
              SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$people',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '명',
                    style: AppTextStyles.title3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                '들어왔어요',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          // 가운데 세 칸 — 숫자만 있으면 '많은지 적은지'를 알 수 없다.
          // 분모를 가진 값만 고른다 (몇 명 중 몇 명, 몇 번 중 몇 번, 어제 대비).
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cell(
                shape: _Donut(
                  ratio: staffTotal == 0 ? 0 : people / staffTotal,
                  color: AppColors.primary,
                ),
                label: '직원 접속률',
                value: '$people / $staffTotal명',
              ),
              SizedBox(height: 8),
              _Cell(
                shape: _Donut(
                  ratio: visits == 0 ? 0 : (visits - failed) / visits,
                  color: failed > 0 ? AppColors.error : AppColors.success,
                  // 아무도 안 왔으면 0% 가 아니라 잴 것이 없는 것이다
                  text: visits == 0 ? '—' : null,
                ),
                label: '로그인 성공률',
                value: '${visits - failed} / $visits회',
              ),
              SizedBox(height: 8),
              _Cell(
                shape: _Compare(today: visits, yesterday: yesterday),
                label: '어제보다',
                value: diff == 0 ? '같아요' : '${diff > 0 ? '+' : ''}$diff회',
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16),
              Container(height: 1, color: AppColors.divider),
              SizedBox(height: 12),
              _Line(label: '접속 횟수', value: '$visits회'),
              SizedBox(height: 8),
              _Line(
                label: '로그인 실패',
                value: '$failed건',
                // 0이면 굳이 빨갛게 물들이지 않는다 — 아무 일도 없다는 뜻이다
                color: failed > 0 ? AppColors.error : null,
              ),
              SizedBox(height: 8),
              _Line(label: '마지막 접속', value: at == null ? '—' : _clock(at)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 이름 — 값 한 줄
class _Line extends StatelessWidget {
  _Line({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ),
      SizedBox(width: 8),
      Text(
        value,
        style: AppTextStyles.body2.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// 왼쪽에 모양, 오른쪽에 이름·값 — 오늘 요약 가운데 세 칸이 같은 틀을 쓴다
class _Cell extends StatelessWidget {
  _Cell({required this.shape, required this.label, required this.value});

  /// 도넛이든 막대든 40~46 정사각 안에 들어오는 것
  final Widget shape;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        shape,
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 원형 게이지 — 링이 차오르고 가운데에 퍼센트
class _Donut extends StatelessWidget {
  _Donut({required this.ratio, required this.color, this.text});

  /// 0~1
  final double ratio;

  final Color color;

  /// 가운데 글자를 직접 정할 때 (잴 것이 없으면 '—')
  final String? text;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _DonutPainter(ratio: clamped, color: color),
        child: Center(
          child: Text(
            text ?? '${(clamped * 100).round()}%',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  /// 링 두께 — 46짜리 안에서 가운데 글자가 살아남는 굵기
  static const _stroke = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(_stroke / 2, _stroke / 2) &
        Size(size.width - _stroke, size.height - _stroke);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.gray200,
    );

    if (ratio <= 0) return;
    canvas.drawArc(
      rect,
      // 12시에서 시작해 시계 방향
      -math.pi / 2,
      math.pi * 2 * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.ratio != ratio || old.color != color;
}

/// 오늘·어제 막대 두 개 — 도넛만 셋이면 셋 다 같은 값처럼 보인다
class _Compare extends StatelessWidget {
  _Compare({required this.today, required this.yesterday});

  final int today;
  final int yesterday;

  static const _size = 46.0;

  /// 막대 높이 — 많은 쪽이 꽉 찬다. 0이어도 밑동은 남긴다
  double _height(int count) {
    final top = math.max(today, yesterday);
    if (top == 0) return 4;
    return 4 + (_size - 4) * (count / top);
  }

  Widget _bar(int count, Color color) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        width: 13,
        height: _height(count),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _size,
    height: _size,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(yesterday, AppColors.gray300),
        SizedBox(width: 6),
        _bar(today, AppColors.primary),
      ],
    ),
  );
}
