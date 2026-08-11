import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// 받아오는 동안 자리를 잡아 두는 회색 뼈대 (스켈레톤)
///
/// 가운데 동그라미 하나는 **화면이 통째로 비어 있다가 툭 나타난다.** 뼈대를
/// 미리 깔아 두면 어디에 무엇이 올지가 보여서 같은 시간도 짧게 느껴진다
/// (인스타·토스가 쓰는 방식).
///
/// 반드시 [SkeletonGroup] 안에서 쓴다 — 반짝임을 한 화면에 컨트롤러 하나로
/// 돌리려는 것이라, 밖에 두면 움직이지 않는 회색 면으로만 그려진다
/// (깨지지는 않는다).
class Skeleton extends StatelessWidget {
  Skeleton({super.key, this.width, this.height = 12, this.radius = 6});

  /// null 이면 부모가 주는 만큼 늘어난다
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final wave = SkeletonGroup._of(context);
    final shape = BorderRadius.circular(radius);

    if (wave == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: shape,
        ),
      );
    }

    return AnimatedBuilder(
      animation: wave,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: _sweep(wave.value),
        ),
      ),
    );
  }
}

/// 아바타 자리 — 동그란 뼈대
class SkeletonCircle extends StatelessWidget {
  SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Skeleton(width: size, height: size, radius: size / 2);
}

/// 카드 한 장짜리 뼈대 — 진짜 카드와 같은 껍데기(테두리·모서리·그림자)를 쓴다
///
/// 껍데기가 같아야 다 받아왔을 때 카드가 제자리에서 채워지는 것처럼 보인다.
class SkeletonCard extends StatelessWidget {
  SkeletonCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: AppDecorations.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

/// 줄이 늘어선 목록 뼈대 — 아바타 · 두 줄 · 오른쪽 값
///
/// 사람이나 문서가 줄줄이 서는 자리(알림·전자결재·조직도·문서함·초대키)가
/// 다 같은 짜임이라 하나로 쓴다. 카드 껍데기는 두르지 않으므로 필요하면
/// [SkeletonCard] 안에 넣는다.
class SkeletonRows extends StatelessWidget {
  SkeletonRows({
    super.key,
    this.rows = 5,
    this.avatar = 32,
    this.gap = 18,
    this.trailing = 44,
  });

  final int rows;

  /// 왼쪽 동그라미 지름 — 0 이면 안 그린다 (문서함처럼 아이콘이 없는 목록)
  final double avatar;
  final double gap;

  /// 오른쪽 끝 값의 폭 — 0 이면 안 그린다
  final double trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < rows; i++) ...[
        if (i > 0) SizedBox(height: gap),
        Row(
          children: [
            if (avatar > 0) ...[
              SkeletonCircle(size: avatar),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 줄마다 길이를 조금씩 달리해서 진짜 글처럼 보이게 한다
                  Skeleton(width: 132.0 + (i % 3) * 26, height: 12),
                  SizedBox(height: 7),
                  Skeleton(width: 78.0 + (i % 2) * 30, height: 10),
                ],
              ),
            ),
            if (trailing > 0) ...[
              SizedBox(width: 10),
              Skeleton(width: trailing, height: 12),
            ],
          ],
        ),
      ],
    ],
  );
}

/// 반짝임을 굴리는 껍데기 — 뼈대를 쓰는 화면을 이걸로 감싼다
///
/// 컨트롤러가 **화면당 하나**라 뼈대가 몇 개든 같은 박자로 흐른다.
/// [TickerMode] 를 타므로 안 보이는 탭에서는 저절로 멈춘다
/// (탭을 살려 두는 `LazyIndexedStack` 과 같은 약속이다).
class SkeletonGroup extends StatefulWidget {
  SkeletonGroup({super.key, required this.child});

  final Widget child;

  static Animation<double>? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonWave>()?.wave;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1200),
  )..repeat();

  /// 밝은 띠가 왼쪽 밖에서 들어와 오른쪽 밖으로 빠져나가게 여유를 둔다
  late final _wave = Tween(
    begin: -_halo,
    end: 1 + _halo,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonWave(wave: _wave, child: widget.child);
}

class _SkeletonWave extends InheritedWidget {
  _SkeletonWave({required this.wave, required super.child});

  final Animation<double> wave;

  @override
  bool updateShouldNotify(_SkeletonWave old) => old.wave != wave;
}

/// 밝은 띠의 반폭 — 넓을수록 부드럽게 흐른다
const _halo = 0.35;

/// 흐르는 띠 — 바탕 회색 위로 한 단계 밝은 면이 지나간다
///
/// 다크에서는 gray50 이 gray100 보다 **어둡다** (명도가 반전된 팔레트라
/// 그렇다). 밝은 쪽을 골라야 반짝이므로 테마마다 다른 칸을 쓴다.
LinearGradient _sweep(double at) {
  final base = AppColors.gray100;
  final halo = AppColors.isDark ? AppColors.gray200 : AppColors.gray50;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [base, halo, base],
    stops: [
      (at - _halo).clamp(0.0, 1.0),
      at.clamp(0.0, 1.0),
      (at + _halo).clamp(0.0, 1.0),
    ],
  );
}

/// PC 한 장 화면 뼈대 — 머리말(제목·한 줄 설명) + 본문
///
/// 근태·급여·조직도·모니터링처럼 `DesktopHeader` 아래로 카드가 쌓이는 화면이
/// 다 같은 여백(24·64·32)을 쓴다.
class SkeletonDesktopPage extends StatelessWidget {
  SkeletonDesktopPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            Skeleton(width: 150, height: 30, radius: 8),
            SizedBox(height: 10),
            Skeleton(width: 250, height: 13),
            SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// PC 2단 화면 뼈대 — 좌측 320 목록 + 우측 상세
///
/// 공지·회의록·프로젝트·전자결재·문서함이 다 같은 틀이다.
/// 상세 쪽은 아직 고른 것이 없는 상태라 **비워 둔다** — 진짜 화면도
/// 그때는 안내만 있다.
class SkeletonTwoPane extends StatelessWidget {
  SkeletonTwoPane({super.key, this.rows = 6, this.filter = true});

  final int rows;

  /// 목록 위 필터 줄이 있는 화면인지 (공지·프로젝트·전자결재)
  final bool filter;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 64, 20, 20),
                children: [
                  Skeleton(width: 96, height: 24, radius: 8),
                  SizedBox(height: 16),
                  if (filter) ...[
                    Skeleton(height: 40, radius: 12),
                    SizedBox(height: 16),
                  ],
                  SkeletonRows(rows: rows, avatar: 0, trailing: 0, gap: 22),
                ],
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(child: SizedBox()),
        ],
      ),
    ),
  );
}
