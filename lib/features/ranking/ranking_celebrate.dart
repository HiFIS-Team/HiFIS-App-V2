part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 지난달 랭킹 1위 축하 (2026-09-30 대표 요청)
//
// 매월 1일 오전 9시에 지난달 랭킹이 굳고 발표 푸시가 나간다. 그 뒤 **앱을
// 처음 열 때 한 번** 분야별 1위를 폭죽과 함께 띄운다. 전 권한이 본다.
//
// 굳은 판(`/scores/ranking/board?period=지난달`)을 그대로 쓴다 — 랭킹 화면에서
// 지난달로 넘겨 보는 1위와 같은 사람이어야 한다.
// ---------------------------------------------------------------------------

const _celebratedKey = 'ranking_celebrated';

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _celebrateChecked = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetRankingCelebration() => _celebrateChecked = false;

/// 지난달 1위 축하 — **띄웠으면 true**
///
/// 못 받으면 조용히 넘어간다 — 이것 때문에 앱 진입이 막히면 안 된다.
Future<bool> showRankingCelebration(BuildContext context) async {
  if (_celebrateChecked) return false;
  _celebrateChecked = true;

  final now = DateTime.now();
  // 1일 오전 9시에 굳는다 — 그 전에 열면 아직 움직이는 판이다
  if (now.day == 1 && now.hour < 9) return false;
  final last = DateTime(now.year, now.month - 1);
  final period = '${last.year}-${last.month.toString().padLeft(2, '0')}';

  // 기기에 사람마다 따로 남긴다 — 같은 폰에 다른 사람이 로그인해도 그 사람은 본다
  final prefs = await SharedPreferences.getInstance();
  final key = '$_celebratedKey:${currentUser?.id}';
  if (prefs.getString(key) == period) return false;

  final List<_Ranker> pool;
  try {
    pool = [
      for (final row in await ScoreApi.board(period: period))
        _Ranker.fromRow(row),
    ];
  } catch (_) {
    return false;
  }
  final winners = _winnersOf(pool);
  if (winners.isEmpty || !context.mounted) return false;

  await prefs.setString(key, period);
  if (!context.mounted) return false;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) =>
        _CelebrationPage(month: last.month, winners: winners),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
  return true;
}

/// 분야마다 1위 — 전 지점·전 직군 판에서. 값이 0 이면 그 분야는 뺀다
List<(_Metric, _Ranker, double)> _winnersOf(List<_Ranker> pool) => [
  for (final metric in _Metric.values)
    if (_topOf(pool, metric) case final top? when top.$2 > 0)
      (metric, top.$1, top.$2),
];

(_Ranker, double)? _topOf(List<_Ranker> pool, _Metric metric) {
  (_Ranker, double)? best;
  for (final r in pool) {
    final v = _valueOf(r, metric, pool);
    if (best == null || v > best.$2) best = (r, v);
  }
  return best;
}

/// 폭죽 뒤에 뜨는 카드 — 분야마다 한 줄
class _CelebrationPage extends StatelessWidget {
  const _CelebrationPage({required this.month, required this.winners});

  final int month;
  final List<(_Metric, _Ranker, double)> winners;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: dialogWidth(context, 340),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_medal(1).$1, _medal(1).$2],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text('$month월 랭킹 1위', style: AppTextStyles.title2),
          const SizedBox(height: 6),
          Text(
            '한 달 동안 정말 수고 많으셨어요!',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < winners.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _WinnerRow(winner: winners[i]),
          ],
          const SizedBox(height: 22),
          AppButton(label: '축하해요', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
    return Stack(
      children: [
        // 카드 뒤에서 터지고 앞으로도 떨어진다 — 누르는 것은 안 막는다
        Positioned.fill(child: IgnorePointer(child: _Confetti())),
        Center(
          child: Material(type: MaterialType.transparency, child: card),
        ),
      ],
    );
  }
}

/// 한 분야 1위 — 분야 · 이름 · 값. 내가 1위면 파랗게
class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.winner});

  final (_Metric, _Ranker, double) winner;

  @override
  Widget build(BuildContext context) {
    final (metric, ranker, value) = winner;
    final me = ranker.isMe;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: me ? AppColors.primary.withValues(alpha: 0.1) : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              metric.short,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              me ? '${ranker.name} (나)' : ranker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
                color: me ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            _format(metric, value),
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 랭킹 화면에서 **지난달**을 볼 때 맨 위 — 그 분야 1위 축하 (2026-09-30 대표 요청)
///
/// 이번 달은 아직 움직이는 판이라 안 띄운다. 전 권한이 본다.
class _ChampionCard extends StatelessWidget {
  const _ChampionCard({
    required this.month,
    required this.metric,
    required this.entry,
  });

  final int month;
  final _Metric metric;
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = _medal(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$month월 ${metric.label} 1등',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.ranker.name}님 축하해요!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title3.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _format(metric, entry.value),
            style: AppTextStyles.body2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 폭죽 — 위에서 색종이가 흩날리며 떨어진다 (4초 뒤 멎는다)
class _Confetti extends StatefulWidget {
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();

  /// 조각마다 출발점·속도·색 — 한 번 정해 두고 시간만 흘린다
  late final List<_Piece> _pieces = () {
    final rnd = math.Random();
    const colors = [
      Color(0xFF3182F6),
      Color(0xFFFFC94B),
      Color(0xFF00C471),
      Color(0xFFF04452),
      Color(0xFF7C5CFC),
      Color(0xFFFF9F0A),
    ];
    return [
      for (var i = 0; i < 90; i++)
        _Piece(
          x: rnd.nextDouble(),
          delay: rnd.nextDouble() * 0.35,
          speed: 0.55 + rnd.nextDouble() * 0.6,
          drift: (rnd.nextDouble() - 0.5) * 0.3,
          spin: (rnd.nextDouble() - 0.5) * 14,
          size: 6 + rnd.nextDouble() * 6,
          color: colors[i % colors.length],
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
        CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
  );
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x, delay, speed, drift, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final life = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (life <= 0) continue;
      final y = -20 + life * p.speed * (size.height + 60);
      if (y > size.height + 20) continue;
      final x =
          (p.x + p.drift * life + math.sin(life * 9 + p.x * 6) * 0.02) *
          size.width;
      // 끝 무렵엔 옅어진다 — 뚝 사라지지 않게
      paint.color = p.color.withValues(alpha: life > 0.8 ? (1 - life) * 5 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(life * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
