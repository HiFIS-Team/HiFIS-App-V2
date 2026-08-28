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
/// - 안드로이드: 글래스가 없어 비치는 효과를 못 얻으므로 타이틀·필터를
///   고정 헤더로 두고 목록만 스크롤한다. 스크롤을 시작하면 경계선이 생긴다.
class PhoneListScaffold extends StatefulWidget {
  PhoneListScaffold({
    super.key,
    required this.title,
    required this.children,
    this.count,
    this.filter,
    this.onCreate,
    this.leading,
    this.trailing,
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

  /// 타이틀과 **같은 줄 오른쪽 끝**에 붙는 것 (랭킹의 달 이동 줄).
  /// 스크롤 안에 따로 한 줄을 두는 것보다 자리를 덜 먹는다.
  final Widget? trailing;

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
        ?widget.trailing,
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

  /// 안드로이드 — 헤더 고정, 목록만 스크롤
  Widget _fixedHeader(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: AppColors.background,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 64, 20, _titleGap),
                  child: Column(
                    children: [
                      _titleRow(),
                      if (widget.filter != null) ...[
                        SizedBox(height: 14),
                        widget.filter!,
                      ],
                    ],
                  ),
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
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomBarInset(context)),
              children: widget.children,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          isApple ? _oneScroll(context) : _fixedHeader(context),
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
    this.leadingActions = const [],
    this.bottomBar,
    this.background,
  });

  final String title;
  final Widget child;

  /// 화면 배경 — 안 주면 회색([AppColors.background])이다.
  ///
  /// **폼 화면은 흰색([AppColors.surface])으로 준다.** 입력칸이 `gray50` 인데
  /// 라이트에서 그 색이 회색 배경과 **완전히 같다**(둘 다 `#F2F4F6`) — 그래서
  /// 회색 배경 위에 그냥 놓으면 칸이 안 보인다.
  ///
  /// 예전에는 폼 전체를 **흰 카드 한 장**에 넣어서 피했는데, 그러면 화면
  /// 하나가 좌우로 떠 있는 판이 되어 **모달처럼 보였다** (2026-08-28 대표 지적).
  /// 배경을 바꾸면 카드가 필요 없어지고 폼이 화면에 그대로 앉는다.
  final Color? background;

  /// 우측 상단 글래스 버튼들 (편집·삭제 등)
  final List<Widget> actions;

  /// **좌측** 상단 — 뒤로가기 바로 옆에 붙는 글래스 버튼들
  ///
  /// 오른쪽에 셋 넘게 몰리면 손이 닿기도 어렵고 제목과도 부딪힌다.
  /// 자주 안 쓰는 것 하나쯤은 이쪽으로 나눠 둔다 (2026-08-19).
  final List<Widget> leadingActions;

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
    // 블러는 **배경과 같은 색**이어야 한다 — 다르면 헤더 자리에 색이 다른
    // 띠가 생긴다
    final background = widget.background ?? AppColors.background;

    return Scaffold(
      backgroundColor: background,
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
          TopFrost(collapse: _collapse, color: background),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                  // 오른쪽 줄과 같은 간격으로 이어 붙인다
                  for (final action in widget.leadingActions) ...[
                    SizedBox(width: 10),
                    action,
                  ],
                ],
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
