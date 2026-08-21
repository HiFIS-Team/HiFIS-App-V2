/// 사람 하나를 담는 카드 — 조직도 카드와 같은 틀
///
/// 업무 화면의 사람 목록들이 각자 다른 줄 모양을 쓰고 있었다. 같은 사람을
/// 보는 자리인데 조직도와 결이 달라서, 틀을 조직도 카드에 맞추고 **그 목록이
/// 원래 보여주던 값만** 아래에 담는다.
///
/// **조직도 카드의 이메일·근무 상태·메시지·복사 버튼은 안 들어온다.**
/// 그건 조직도가 하는 일이고, 여기서는 틀과 아바타·이름·직군까지만 같다.
///
/// PC 전용이다 — 폰은 화면마다 이미 제 카드를 갖고 있다.
library;

import 'package:flutter/material.dart';

import '../../data/staff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';
import 'avatar.dart';

class PersonCard extends StatefulWidget {
  const PersonCard({
    super.key,
    required this.name,
    this.subtitle,
    this.subtitleColor,
    this.subtitleWeight,
    this.color,
    this.avatarUrl,
    this.dimmed = false,
    this.tag,
    this.trailing,
    this.body,
    this.onTap,
  });

  final String name;

  /// 이름 아래 한 줄 — 직군처럼 그 사람을 가리키는 값
  final String? subtitle;
  final Color? subtitleColor;
  final FontWeight? subtitleWeight;

  /// 아바타 색 — 안 주면 명단에서 찾는다
  ///
  /// 서버가 사람마다 색을 주므로([Employee.color]) 그 값을 쓰는 자리는
  /// 직접 넘긴다. 명단을 못 받았을 때만 이름에서 만든 색으로 떨어진다.
  final Color? color;
  final String? avatarUrl;

  /// 이미 처리한 사람 — 아바타를 한 톤 흐리게 한다
  final bool dimmed;

  /// 이름 옆 작은 배지 (`나` 같은 것)
  final Widget? tag;

  /// 오른쪽 위 — 상태 배지나 체크
  final Widget? trailing;

  /// 이름 줄 아래에 붙는 것 — **그 목록이 원래 보여주던 값**
  final Widget? body;

  final VoidCallback? onTap;

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? staffOf(widget.name).color;

    final card = AnimatedContainer(
      duration: Duration(milliseconds: 140),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // 커서를 올린 카드만 테두리에 색을 준다 (조직도와 같다)
        border: Border.all(
          color: _hovered ? AppColors.primary : AppColors.gray100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(color),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title3,
                          ),
                        ),
                        if (widget.tag != null) ...[
                          SizedBox(width: 6),
                          widget.tag!,
                        ],
                      ],
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: widget.subtitleColor,
                          fontWeight: widget.subtitleWeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                SizedBox(width: 6),
                widget.trailing!,
              ],
            ],
          ),
          if (widget.body != null) ...[SizedBox(height: 14), widget.body!],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? card
          : Pressable(onTap: widget.onTap!, child: card),
    );
  }

  /// 아바타 — 색을 직접 받는 자리라 [Avatar] 대신 여기서 그린다
  ///
  /// [Avatar] 는 이름으로 색을 찾는데, 서버가 준 색을 쓰는 목록들이 있다.
  Widget _avatar(Color color) {
    const size = 44.0;
    final url = widget.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Avatar(name: widget.name, size: size, imageUrl: url);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 이미 끝낸 사람은 한 톤 흐리게 — 남은 사람이 먼저 눈에 들어온다
        color: widget.dimmed ? color.withValues(alpha: 0.35) : color,
        shape: BoxShape.circle,
      ),
      child: Text(
        widget.name.characters.first,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 사람 카드를 폭에 맞춰 늘어놓는다 — 조직도 카드 보기와 같은 셈
///
/// 카드가 너무 넓어지지 않게 최소 폭으로 열 수를 잡고, 남는 폭은 카드들이
/// 나눠 갖는다. **왼쪽부터 채운다** (`Wrap` 기본값).
class PersonGrid extends StatelessWidget {
  const PersonGrid({
    super.key,
    required this.children,
    this.minWidth = 260,
    this.gap = 16,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + gap) / (minWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
