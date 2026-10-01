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
  // 이미 보낸 축하 — 못 받아도 페이지는 띄운다 (누르면 서버가 한 번만 받는다)
  final cheered = await ScoreApi.rankingCheers(
    period,
  ).catchError((_) => <String>{});

  await prefs.setString(key, period);
  if (!context.mounted) return false;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _CelebrationPage(
      period: period,
      month: last.month,
      winners: winners,
      cheered: cheered,
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(
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

/// 축하 페이지 — 폭죽이 **2초마다** 터지고, 1위 줄의 🎉 를 누르면 그 사람에게 축하 푸시
///
/// 생일 축하 모달과 같은 규칙이다 — 한 사람에게 그달 한 번만 가고(서버가 막는다),
/// 보낸 줄은 잠근다. 여러 분야 1위면 그 사람 줄이 **다 같이** 잠긴다.
class _CelebrationPage extends StatefulWidget {
  const _CelebrationPage({
    required this.period,
    required this.month,
    required this.winners,
    required this.cheered,
  });

  final String period;
  final int month;
  final List<(_Metric, _Ranker, double)> winners;
  final Set<String> cheered;

  @override
  State<_CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<_CelebrationPage> {
  late final Set<String> _sent = {...widget.cheered};
  final Set<String> _busy = {};

  /// 🎉 를 누른 자리에서도 한 번 터뜨린다
  final _fireworks = _FireworksController();

  Future<void> _cheer(_Ranker ranker, Offset at) async {
    if (_sent.contains(ranker.id) || _busy.contains(ranker.id)) return;
    _fireworks.burstAt(at);
    setState(() => _busy.add(ranker.id));
    try {
      await ScoreApi.rankingCheer(employeeId: ranker.id, period: widget.period);
      if (!mounted) return;
      setState(() {
        _busy.remove(ranker.id);
        _sent.add(ranker.id);
      });
      AppToast.show(context, '${ranker.name}님에게 축하를 보냈어요');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy.remove(ranker.id));
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (gold, deep) = _medal(1);
    final card = Container(
      width: dialogWidth(context, 350),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.45),
            blurRadius: 48,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 금빛 머리 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFFFE08A), gold, deep],
              ),
            ),
            child: Column(
              children: [
                _GlowTrophy(),
                const SizedBox(height: 14),
                Text(
                  '${widget.month}월 랭킹 1위',
                  style: AppTextStyles.title1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: deep.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '한 달 동안 정말 수고 많으셨어요!',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // ── 분야마다 한 줄 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Column(
              children: [
                for (var i = 0; i < widget.winners.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _WinnerRow(
                    winner: widget.winners[i],
                    sent: _sent.contains(widget.winners[i].$2.id),
                    busy: _busy.contains(widget.winners[i].$2.id),
                    onCheer: (at) => _cheer(widget.winners[i].$2, at),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
            child: Text(
              '🎉 를 누르면 1위에게 축하가 전해져요',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: AppButton(label: '닫기', onTap: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
    return Stack(
      children: [
        // 카드 뒤 — 금빛이 은은하게 번진다
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.75,
                  colors: [gold.withValues(alpha: 0.32), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Material(type: MaterialType.transparency, child: card),
          ),
        ),
        // 폭죽은 카드 **위**로도 날린다 — 누르는 것은 안 막는다
        Positioned.fill(
          child: IgnorePointer(child: _Fireworks(controller: _fireworks)),
        ),
      ],
    );
  }
}

/// 빛나는 트로피 — 숨 쉬듯 커졌다 작아진다
class _GlowTrophy extends StatefulWidget {
  @override
  State<_GlowTrophy> createState() => _GlowTrophyState();
}

class _GlowTrophyState extends State<_GlowTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = Curves.easeInOut.transform(_c.value);
      return Transform.scale(
        scale: 1 + t * 0.06,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35 + t * 0.35),
                blurRadius: 18 + t * 14,
              ),
            ],
          ),
          child: child,
        ),
      );
    },
    child: const Icon(
      Icons.emoji_events_rounded,
      size: 42,
      color: Colors.white,
    ),
  );
}

/// 분야 아이콘 — 한눈에 무슨 1위인지 보이게
IconData _metricIcon(_Metric metric) => switch (metric) {
  _Metric.revenue => Icons.payments_rounded,
  _Metric.kindness => Icons.favorite_rounded,
  _Metric.project => Icons.folder_rounded,
  _Metric.care => Icons.cleaning_services_rounded,
  _Metric.lesson => Icons.fitness_center_rounded,
  _Metric.overall => Icons.workspace_premium_rounded,
};

/// 한 분야 1위 — 아이콘 · 분야 · 이름 · 값 · 🎉. 내가 1위면 파랗고 🎉 가 없다
class _WinnerRow extends StatelessWidget {
  const _WinnerRow({
    required this.winner,
    required this.sent,
    required this.busy,
    required this.onCheer,
  });

  final (_Metric, _Ranker, double) winner;
  final bool sent;
  final bool busy;

  /// 누른 자리(화면 좌표) — 거기서 폭죽이 터진다
  final ValueChanged<Offset> onCheer;

  @override
  Widget build(BuildContext context) {
    final (metric, ranker, value) = winner;
    final me = ranker.isMe;
    final (gold, deep) = _medal(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: me ? AppColors.primary.withValues(alpha: 0.1) : AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [gold, deep],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(_metricIcon(metric), size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric.short} · ${_format(metric, value)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  me ? '${ranker.name} (나)' : ranker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w800,
                    color: me ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (!me)
            Builder(
              builder: (box) => Pressable(
                onTap: () {
                  final r = box.findRenderObject() as RenderBox?;
                  final at = r == null
                      ? Offset.zero
                      : r.localToGlobal(r.size.center(Offset.zero));
                  onCheer(at);
                },
                child: AnimatedScale(
                  scale: sent ? 1.12 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: busy ? 0.4 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sent
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sent
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.gray100,
                        ),
                      ),
                      child: Text(
                        sent ? '💙' : '🎉',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 랭킹 화면에서 **굳은 달**을 볼 때 — 내 순위(대표·관리자는 추월 기록) 자리에
/// 그 분야 1등 축하 (2026-09-30 대표 요청)
///
/// **내 순위 카드와 같은 틀**이다 — 아바타 · 머리말 · 큰 글씨 · 오른쪽 값.
/// 테두리만 파랑 대신 금색이다. 이번 달은 아직 움직이는 판이라 안 띄운다.
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
    final (gold, deep) = _medal(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.85), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(gold.withValues(alpha: 0.18), AppColors.surface),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: deep, width: 2.5),
                    ),
                    child: Avatar(name: entry.ranker.name, size: 46),
                  ),
                  Positioned(
                    right: -4,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [gold, deep]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$month월 ${metric.label} 1등',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: deep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.ranker.name}님 축하해요!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _format(metric, entry.value),
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w800,
                  color: deep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 손으로 터뜨릴 자리를 넘기는 통로 — 🎉 를 누른 자리에서 한 번 더 터진다
class _FireworksController {
  final _pending = <Offset>[];
  void burstAt(Offset at) => _pending.add(at);
}

/// 폭죽 — **2초마다** 화면 위쪽 아무 데서나 터지고, 처음 4초는 색종이도 내린다
class _Fireworks extends StatefulWidget {
  const _Fireworks({required this.controller});

  final _FireworksController controller;

  @override
  State<_Fireworks> createState() => _FireworksState();
}

class _Burst {
  _Burst(this.origin, this.start, this.seed, {this.big = false});

  /// 화면 좌표(px). 자동 폭죽은 크기가 정해진 뒤에 비율로 정한다
  final Offset origin;
  final double start;
  final int seed;
  final bool big;
}

class _FireworksState extends State<_Fireworks>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  int _nextAuto = 0;
  final _bursts = <_Burst>[];
  final _rnd = math.Random();
  Size _size = Size.zero;

  /// 처음 4초 내리는 색종이 — 한 번 정해 두고 시간만 흘린다
  late final List<_Piece> _rain = [
    for (var i = 0; i < 110; i++)
      _Piece(
        x: _rnd.nextDouble(),
        delay: _rnd.nextDouble() * 0.4,
        speed: 0.55 + _rnd.nextDouble() * 0.6,
        drift: (_rnd.nextDouble() - 0.5) * 0.3,
        spin: (_rnd.nextDouble() - 0.5) * 14,
        size: 6 + _rnd.nextDouble() * 7,
        color: _confettiColors[i % _confettiColors.length],
      ),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _t = elapsed.inMicroseconds / 1e6;
      // 2초마다 둘씩 — 시작하자마자 첫 발
      while (_t >= _nextAuto * 2.0) {
        if (_size != Size.zero) {
          for (var k = 0; k < 2; k++) {
            _bursts.add(
              _Burst(
                Offset(
                  _size.width * (0.15 + _rnd.nextDouble() * 0.7),
                  _size.height * (0.12 + _rnd.nextDouble() * 0.3),
                ),
                _nextAuto * 2.0 + k * 0.35,
                _rnd.nextInt(1 << 30),
              ),
            );
          }
        }
        _nextAuto++;
      }
      for (final at in widget.controller._pending) {
        _bursts.add(_Burst(at, _t, _rnd.nextInt(1 << 30), big: true));
      }
      widget.controller._pending.clear();
      _bursts.removeWhere((b) => _t - b.start > _Burst_life);
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      _size = box.biggest;
      // 놓인 자리 기준으로 그린다 — 손으로 넘긴 좌표는 화면 좌표라 옮겨 준다
      final r = context.findRenderObject() as RenderBox?;
      final shift = r != null && r.hasSize
          ? r.localToGlobal(Offset.zero)
          : Offset.zero;
      return CustomPaint(
        size: box.biggest,
        painter: _FireworksPainter(_bursts, _rain, _t, shift),
      );
    },
  );
}

/// 폭죽 한 발이 사는 시간(초)
// ignore: constant_identifier_names
const _Burst_life = 1.9;

const _confettiColors = [
  Color(0xFF3182F6),
  Color(0xFFFFC94B),
  Color(0xFF00C471),
  Color(0xFFF04452),
  Color(0xFF7C5CFC),
  Color(0xFFFF9F0A),
  Color(0xFFFF6FB5),
];

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

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.bursts, this.rain, this.t, this.shift);

  final List<_Burst> bursts;
  final List<_Piece> rain;
  final double t;

  /// 이 칠판이 화면에서 놓인 자리 — 손으로 넘긴 화면 좌표를 여기 기준으로 옮긴다
  final Offset shift;

  static const _gravity = 260.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // ── 색종이 비 — 처음 4초 ──
    final life0 = (t / 4.2).clamp(0.0, 1.0);
    if (life0 < 1) {
      for (final p in rain) {
        final life = ((life0 - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
        if (life <= 0) continue;
        final y = -20 + life * p.speed * (size.height + 60);
        if (y > size.height + 20) continue;
        final x =
            (p.x + p.drift * life + math.sin(life * 9 + p.x * 6) * 0.02) *
            size.width;
        paint.color = p.color.withValues(
          alpha: life > 0.8 ? (1 - life) * 5 : 1,
        );
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

    // ── 폭죽 — 한 점에서 사방으로 퍼지고 떨어지며 옅어진다 ──
    for (final b in bursts) {
      final age = t - b.start;
      if (age < 0 || age > _Burst_life) continue;
      final rnd = math.Random(b.seed);
      final origin = b.big ? b.origin - shift : b.origin;
      final count = b.big ? 46 : 38;
      final hue = _confettiColors[rnd.nextInt(_confettiColors.length)];
      final fade = age < _Burst_life * 0.55
          ? 1.0
          : 1 - (age - _Burst_life * 0.55) / (_Burst_life * 0.45);
      // 터지는 순간 가운데가 번쩍
      if (age < 0.18) {
        paint
          ..color = Colors.white.withValues(alpha: (1 - age / 0.18) * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(origin, 22 * (b.big ? 1.3 : 1), paint);
        paint.maskFilter = null;
      }
      for (var i = 0; i < count; i++) {
        final angle = i / count * math.pi * 2 + rnd.nextDouble() * 0.2;
        final speed = (b.big ? 230 : 190) + rnd.nextDouble() * 150;
        // 공기 저항 — 처음엔 빠르게 퍼지고 점점 느려진다
        final travel = speed * (1 - math.exp(-age * 2.4)) / 2.4;
        final pos = Offset(
          origin.dx + math.cos(angle) * travel,
          origin.dy + math.sin(angle) * travel + 0.5 * _gravity * age * age,
        );
        final color = i.isEven
            ? hue
            : _confettiColors[(i ~/ 2) % _confettiColors.length];
        paint.color = color.withValues(alpha: fade.clamp(0.0, 1.0));
        // 꼬리 — 지나온 길을 짧게
        final tail = Offset(
          origin.dx + math.cos(angle) * travel * 0.82,
          origin.dy +
              math.sin(angle) * travel * 0.82 +
              0.5 * _gravity * age * age * 0.9,
        );
        paint
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, pos, paint);
        canvas.drawCircle(pos, 2.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter old) => true;
}
