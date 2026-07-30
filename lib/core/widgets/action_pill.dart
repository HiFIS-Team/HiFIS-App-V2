import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_icon_button.dart';
import 'pressable.dart';
import 'top_frost.dart';

/// 화면 우상단 주요 동작 알약 (새 프로젝트·새 회의록·공지 작성)
///
/// 폰 목록 화면들이 같은 자리에 같은 모양으로 쓴다.
class ActionPill extends StatelessWidget {
  ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 9, 15, 9),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
  });

  final String title;
  final Widget child;

  /// 우측 상단 글래스 버튼들 (편집·삭제 등)
  final List<Widget> actions;

  /// 본문 스크롤 뷰가 위쪽에 잡아야 할 여백 (제목 아래로 내용이 시작된다)
  static const double topPadding = 68;

  @override
  State<PhoneDetailScaffold> createState() => _PhoneDetailScaffoldState();
}

class _PhoneDetailScaffoldState extends State<PhoneDetailScaffold> {
  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  double _collapse = 0;

  /// 본문 스크롤 컨트롤러를 넘겨받지 않아도 되도록 알림으로 오프셋을 읽는다
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final t = ((notification.metrics.pixels - 30) / 30).clamp(0.0, 1.0);
    if (t != _collapse) setState(() => _collapse = t);
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
