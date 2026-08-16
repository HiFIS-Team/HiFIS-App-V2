import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../util/layout.dart';
import '../../util/sf_symbols.dart';
import '../glass/glass_icon_button.dart';
import '../glass/top_frost.dart';

/// 폰 목록 화면 좌측 상단 만들기 버튼
///
/// 우측의 공용 헤더 버튼(바코드·사내톡·알림·프로필)과 같은 높이·크기로 둔다.
class PhoneCreateButton extends StatelessWidget {
  PhoneCreateButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(top: 8, left: 16),
        child: GlassIconButton(symbol: 'plus', onPressed: onTap),
      ),
    );
  }
}

/// 폰 목록 화면 공통 껍데기 — 타이틀 + 개수 + 필터 + 목록
///
/// 플랫폼에 따라 헤더를 다르게 다룬다.
/// - iOS: 화면 전체가 하나의 스크롤. 타이틀·필터가 같이 올라가면서 상단
///   글래스 버튼 뒤로 지나가 비쳐 보인다 (글래스를 쓰는 이유).
/// - 안드로이드: **삼성 One UI 식으로 제목이 접힌다.** 크게 떴다가 스크롤하면
///   앱바 제목 크기로 줄면서 위로 붙고, 필터는 그 아래 고정된다.
///   스크롤을 시작하면 경계선이 생긴다.
class PhoneListScaffold extends StatefulWidget {
  PhoneListScaffold({
    super.key,
    required this.title,
    required this.children,
    this.count,
    this.filter,
    this.onCreate,
    this.leading,
  });

  final String title;

  /// 타이틀 옆에 흐리게 붙는 개수 (없으면 안 그린다)
  final int? count;

  /// 타이틀 아래 필터 (단계 탭·전체/안읽음 전환 등)
  final Widget? filter;

  /// 목록 본문 — 카드들 또는 빈 카드
  final List<Widget> children;

  /// 좌측 상단 만들기 버튼 (없으면 안 그린다)
  final VoidCallback? onCreate;

  /// 좌측 상단에 놓을 다른 버튼 (필터 등) — [onCreate] 와 같은 자리다.
  /// 만들기 버튼이 없는 화면에서 쓴다 (랭킹 지점 필터).
  final Widget? leading;

  @override
  State<PhoneListScaffold> createState() => _PhoneListScaffoldState();
}

class _PhoneListScaffoldState extends State<PhoneListScaffold> {
  /// 안드로이드 고정 헤더 아래 경계선을 보일지.
  /// 값만 흘려보내서 목록 전체가 다시 그려지지 않게 한다.
  final _scrolled = ValueNotifier(false);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _scrolled.value = notification.metrics.pixels > 4;
    }
    return false;
  }

  /// 필터가 있으면 그 아래 간격이 따로 붙으므로 타이틀 아래는 조금만 띄운다
  double get _titleGap => widget.filter == null ? 16 : 14;

  Widget _titleRow() {
    return Row(
      children: [
        Text(widget.title, style: AppTextStyles.title1),
        if (widget.count != null) ...[
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.count}',
              style: AppTextStyles.title2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ] else
          Spacer(),
      ],
    );
  }

  /// iOS — 타이틀·필터까지 전부 한 스크롤
  Widget _oneScroll(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 64, 20, bottomBarInset(context)),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: _titleGap),
            child: _titleRow(),
          ),
          if (widget.filter != null) ...[widget.filter!, SizedBox(height: 16)],
          ...widget.children,
        ],
      ),
    );
  }

  /// 안드로이드 — One UI 식으로 제목이 접힌다
  ///
  /// 제목만 줄어들고 **필터와 경계선은 그 아래 고정**된다 (예전과 같다).
  /// 목록은 접히는 제목 뒤로 지나가므로 헤더 배경이 불투명해야 한다.
  Widget _oneUiHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _OneUiTitle(
                title: widget.title,
                count: widget.count,
                bottomGap: _titleGap,
                dark: AppColors.isDark,
              ),
            ),
            PinnedHeaderSliver(child: _pinnedBelowTitle()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomBarInset(context)),
              sliver: SliverList.list(children: widget.children),
            ),
          ],
        ),
      ),
    );
  }

  /// 제목 아래 고정되는 줄 — 필터와 경계선
  Widget _pinnedBelowTitle() {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.filter case final filter?)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, _titleGap),
              child: filter,
            ),
          ValueListenableBuilder<bool>(
            valueListenable: _scrolled,
            builder: (context, scrolled, child) => AnimatedOpacity(
              opacity: scrolled ? 1 : 0,
              duration: Duration(milliseconds: 150),
              child: child,
            ),
            child: Container(height: 1, color: AppColors.gray200),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          isApple ? _oneScroll(context) : _oneUiHeader(context),
          if (widget.onCreate != null)
            PhoneCreateButton(onTap: widget.onCreate!),
          if (widget.leading case final leading?)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 8, left: 16),
                child: leading,
              ),
            ),
        ],
      ),
    );
  }
}

/// 안드로이드 목록 제목 — 스크롤하면 앱바 제목 크기로 줄어든다 (One UI)
///
/// One UI 는 화면을 **위는 보는 곳, 아래는 만지는 곳**으로 나눈다. 제목이
/// 크게 떴다가 스크롤하면 작아지면서 위로 붙는 게 그 방식이다.
///
/// ⚠️ **접힌 제목을 글래스 버튼 줄(위 8~48) 안에 넣지 않는다.** 그 줄은 좌우가
/// 이미 차 있다 — 오른쪽에 권한에 따라 최대 5개(바코드·지점·사내톡·알림·프로필,
/// 256px), 왼쪽에 만들기 버튼(56px). 360dp 폰이면 48px 밖에 안 남아서
/// `프로젝트` 가 안 들어간다. 그래서 **버튼 줄 바로 아래**로 접힌다.
class _OneUiTitle extends SliverPersistentHeaderDelegate {
  _OneUiTitle({
    required this.title,
    required this.count,
    required this.bottomGap,
    required this.dark,
  });

  final String title;
  final int? count;

  /// 제목 아래 여백 — 필터가 있으면 그 앞 간격, 없으면 경계선까지의 간격
  final double bottomGap;

  /// 테마가 바뀌면 다시 그려야 한다 — 안 보면 [shouldRebuild] 가 false 라
  /// 제목만 옛 색으로 남는다 (제목·개수는 그대로니까)
  final bool dark;

  /// 펼침 — 위 여백 · 글자 크기 · 줄 높이
  static const _topMax = 64.0;
  static const _sizeMax = 28.0; // AppTextStyles.display
  static const _lineMax = 38.0;

  /// 접힘 — 글래스 버튼 줄(48) 바로 아래
  static const _topMin = 52.0;
  static const _sizeMin = 17.0; // AppTextStyles.title3 (앱바 타이틀)
  static const _lineMin = 24.0;

  /// 개수는 제목보다 한 단계 작게 따라간다
  static const _countMax = 20.0; // AppTextStyles.title2
  static const _countMin = 15.0;

  @override
  double get maxExtent => _topMax + _lineMax + bottomGap;

  @override
  double get minExtent => _topMin + _lineMin + bottomGap;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final span = maxExtent - minExtent;
    final t = span <= 0 ? 0.0 : (shrinkOffset / span).clamp(0.0, 1.0);

    // **높이를 받은 만큼 꽉 채운다.** 슬리버가 주는 건 느슨한 제약이라
    // 안 채우면 그 높이가 그대로 paintExtent 가 되고, 선언한 extent 와
    // 어긋나 `layoutExtent exceeds paintExtent` 로 죽는다.
    //
    // 위 여백과 아래 여백을 빼고 남는 높이가 곧 제목 줄이다
    // (extent · top 이 같은 기울기로 줄어서 늘 `_lineMax`~`_lineMin` 이 된다).
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.only(
            top: _lerp(_topMax, _topMin, t),
            left: 20,
            right: 20,
            bottom: bottomGap,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: AppTextStyles.title1.copyWith(
                  fontSize: _lerp(_sizeMax, _sizeMin, t),
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count',
                    style: AppTextStyles.title2.copyWith(
                      fontSize: _lerp(_countMax, _countMin, t),
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ] else
                Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_OneUiTitle old) =>
      old.title != title ||
      old.count != count ||
      old.bottomGap != bottomGap ||
      old.dark != dark;
}

/// 폰 상세 화면 공통 껍데기 — 상단 가운데 제목 + 좌측 뒤로가기 글래스 버튼
///
/// 본문은 스스로 스크롤하는 위젯([ListView] 등)을 넘기고,
/// 위쪽 여백은 [topPadding]만큼 잡아 콘텐츠가 헤더 뒤로 지나가게 한다.
class PhoneDetailScaffold extends StatefulWidget {
  PhoneDetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottomBar,
  });

  final String title;
  final Widget child;

  /// 우측 상단 글래스 버튼들 (편집·삭제 등)
  final List<Widget> actions;

  /// 하단 탭바 자리에 띄울 버튼 (GlassBottomButton 등)
  final Widget? bottomBar;

  /// 본문 스크롤 뷰가 위쪽에 잡아야 할 여백 (제목 아래로 내용이 시작된다)
  static const double topPadding = 68;

  @override
  State<PhoneDetailScaffold> createState() => _PhoneDetailScaffoldState();
}

class _PhoneDetailScaffoldState extends State<PhoneDetailScaffold> {
  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  final _collapse = ScrollCollapse();

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  /// 본문 스크롤 컨트롤러를 넘겨받지 않아도 되도록 알림으로 오프셋을 읽는다
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    _collapse.update(notification.metrics.pixels);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
          // 스크롤 시 상단 프로그레시브 블러 — 콘텐츠가 헤더 뒤로 흐려진다
          TopFrost(collapse: _collapse, color: AppColors.background),
          // 상단 중앙 고정 타이틀 (터치는 아래 본문으로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(widget.title, style: AppTextStyles.title3),
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
          if (widget.bottomBar != null)
            Align(alignment: Alignment.bottomCenter, child: widget.bottomBar),
          if (widget.actions.isNotEmpty)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.actions.length; i++) ...[
                        if (i > 0) SizedBox(width: 10),
                        widget.actions[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
