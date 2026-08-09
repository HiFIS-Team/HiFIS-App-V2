/// 글래스 드롭다운 메뉴 — 버튼 아래에 뜨는 목록
///
/// 아이폰에서는 OS 가 그리는 네이티브 메뉴(`CNPopupMenuButton`)를 쓰지만,
/// **PC·안드로이드는 여기서 직접 그린다.** 패키지의 macOS 구현이 메뉴 위치를
/// 버튼 왼쪽에 고정해 둬서 오른쪽 끝 버튼이면 창 밖으로 새어 나간다.
///
/// Material 의 `showMenu` 를 대신한다 — 그쪽은 위에서 아래로 훑고 지나가는
/// 전개 애니메이션이라 디자인 시스템의 다른 면들과 결이 달랐다.
/// 여기서는 누른 모서리에서 커지면서 뜨고, 뒤가 비쳐 보인다.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_styles.dart';

/// 메뉴 한 줄
sealed class GlassMenuEntry<T> {
  const GlassMenuEntry();
}

/// 고를 수 있는 줄
class GlassMenuItem<T> extends GlassMenuEntry<T> {
  const GlassMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.trailing,
    this.selected = false,
  });

  final T value;
  final String label;

  /// 왼쪽 아이콘 — 없으면 글자가 왼쪽 끝에서 시작한다
  final IconData? icon;

  /// 오른쪽 끝에 붙일 것 (인원수 같은 것). 고른 줄의 체크는 [selected] 가 그린다
  final Widget? trailing;

  /// 지금 고른 값인가 — 글자가 굵어지고 오른쪽에 체크가 붙는다
  final bool selected;
}

/// 묶음을 가르는 선
class GlassMenuDivider<T> extends GlassMenuEntry<T> {
  const GlassMenuDivider();
}

/// 묶음 이름 — 못 누른다
class GlassMenuHeader<T> extends GlassMenuEntry<T> {
  const GlassMenuHeader(this.label);

  final String label;
}

/// [anchorKey] 버튼 아래에 메뉴를 띄우고 고른 값을 돌려준다 (밖을 누르면 null)
///
/// [alignRight] 면 메뉴 오른쪽 끝을 버튼 오른쪽 끝에 맞춘다. 오른쪽에 붙은
/// 버튼은 이렇게 해야 메뉴가 화면 안쪽으로 자란다.
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<GlassMenuEntry<T>> items,
  double width = 220,
  bool alignRight = true,
}) {
  final button = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  // **최상위 오버레이 기준으로 잰다.** 사내톡 패널 안의 오버레이를 쓰면 메뉴가
  // 그 상자에 갇히고, 바깥을 눌러도 안 닫혀서 누를 때마다 쌓인다 (실제 발생).
  final overlay =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox?;
  if (button == null || overlay == null) return Future.value(null);

  final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
  return Navigator.of(context, rootNavigator: true).push(
    _GlassMenuRoute<T>(
      anchor: origin & button.size,
      bounds: overlay.size,
      items: items,
      width: width,
      alignRight: alignRight,
    ),
  );
}

class _GlassMenuRoute<T> extends PopupRoute<T> {
  _GlassMenuRoute({
    required this.anchor,
    required this.bounds,
    required this.items,
    required this.width,
    required this.alignRight,
  });

  final Rect anchor;
  final Size bounds;
  final List<GlassMenuEntry<T>> items;
  final double width;
  final bool alignRight;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '메뉴 닫기';

  @override
  Duration get transitionDuration => Duration(milliseconds: 170);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 110);

  /// 버튼 아래 6 — 아래로 넘치면 버튼 위로 뒤집는다
  static const _gap = 6.0;

  /// 화면 가장자리에서 이만큼은 띄운다
  static const _margin = 8.0;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
  ) {
    final height = _estimateHeight();
    final below = anchor.bottom + _gap;
    final flip = below + height > bounds.height - _margin;
    final top = flip ? anchor.top - _gap - height : below;

    final left = alignRight ? anchor.right - width : anchor.left;
    final clamped = left.clamp(_margin, bounds.width - width - _margin);

    final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return Stack(
      children: [
        Positioned(
          left: clamped,
          top: top.clamp(_margin, bounds.height - _margin),
          width: width,
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curve),
              // 누른 모서리에서 커진다 — 버튼에서 자라 나온 것처럼 보인다
              alignment: Alignment(alignRight ? 1.0 : -1.0, flip ? 1.0 : -1.0),
              child: _GlassMenuBody<T>(items: items),
            ),
          ),
        ),
      ],
    );
  }

  /// 뒤집을지 정하려면 그리기 전에 높이를 알아야 한다
  double _estimateHeight() {
    var height = 12.0; // 위아래 여백
    for (final item in items) {
      height += switch (item) {
        GlassMenuItem() => 42.0,
        GlassMenuHeader() => 30.0,
        GlassMenuDivider() => 9.0,
      };
    }
    return height;
  }
}

class _GlassMenuBody<T> extends StatelessWidget {
  _GlassMenuBody({required this.items});

  final List<GlassMenuEntry<T>> items;

  /// 유리판 모서리 — 카드(20)보다 조금 작게 잡아 떠 있는 판으로 읽히게 한다
  static const _radius = 18.0;

  /// 뒤를 흐리면서 **색을 진하게** 뽑는다 — 이게 '리퀴드 글래스'의 핵심이다
  ///
  /// 흐리기만 하면 뒤가 뿌연 회색으로 뭉개져서 그냥 반투명 판이 된다.
  /// 애플 것은 흐린 뒤 채도를 올려서 밑에 깔린 색이 유리를 통해 배어 나온다.
  static ImageFilter get _glass => ImageFilter.compose(
    outer: ColorFilter.matrix(_saturate(1.7)),
    inner: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
  );

  /// 채도 행렬 — [amount] 가 1이면 그대로, 크면 진해진다
  static List<double> _saturate(double amount) {
    final r = 0.213 * (1 - amount);
    final g = 0.715 * (1 - amount);
    final b = 0.072 * (1 - amount);
    return [
      r + amount, g, b, 0, 0, //
      r, g + amount, b, 0, 0, //
      r, g, b + amount, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        // 떠 있는 판이라 그림자가 있어야 뒤와 갈린다. `popup` 은 원래
        // '메뉴·토스트·탭바' 용으로 만들어 둔 토큰인데 이 메뉴만 안 쓰고 있었다
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: AppShadows.popup,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: _glass,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // 반투명이라 뒤가 비친다. 글자가 묻히지 않을 만큼만 열어 둔다
                color: AppColors.surface.withValues(alpha: dark ? 0.66 : 0.74),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.14 : 0.6),
                ),
              ),
              // 위쪽에 흰 기를 얹어 유리 모서리에 빛이 닿은 것처럼 보이게 한다.
              // 단색 테두리만 두르면 판이 납작해 보인다.
              // **바탕색과 한 상자에 못 넣는다** — BoxDecoration 은 color 와
              // gradient 를 같이 주면 터진다. 그래서 층을 나눈다
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.10 : 0.34),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items)
                        switch (item) {
                          GlassMenuItem<T>() => _GlassMenuRow<T>(item: item),
                          GlassMenuHeader<T>() => Padding(
                            padding: EdgeInsets.fromLTRB(14, 7, 14, 5),
                            child: Text(
                              item.label,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GlassMenuDivider<T>() => Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1),
                          ),
                        },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 한 줄 — 마우스를 올리면 바탕이 깔린다 (PC)
class _GlassMenuRow<T> extends StatefulWidget {
  _GlassMenuRow({required this.item});

  final GlassMenuItem<T> item;

  @override
  State<_GlassMenuRow<T>> createState() => _GlassMenuRowState<T>();
}

class _GlassMenuRowState<T> extends State<_GlassMenuRow<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = item.selected ? AppColors.primary : AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, item.value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 110),
          height: 42,
          margin: EdgeInsets.symmetric(horizontal: 6),
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            // 고른 줄은 옅은 알약을 깔아 둔다 — 유리라 뒤가 비쳐서
            // 글자 색만 바꾸면 어느 줄이 걸렸는지 잘 안 보인다
            color: item.selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : _hover
                ? AppColors.gray100.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 17, color: AppColors.textSecondary),
                SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    color: color,
                    fontWeight: item.selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (item.trailing != null) ...[
                SizedBox(width: 8),
                item.trailing!,
              ],
              if (item.selected) ...[
                SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
