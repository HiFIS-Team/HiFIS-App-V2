import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';

/// 번호 페이지 줄 — `‹ 1 2 3 4 5 ›`
///
/// 모니터링의 접속·활동 목록이 쓴다. 로그는 90일치가 쌓여서 한 번에 다 받을 수
/// 없고, 스크롤로 이어 붙이면 어디까지 봤는지를 잃는다. 번호로 끊어 본다.
///
/// 장이 많아도 한 번에 [_window] 개만 세운다 — 90일이면 수백 장이 될 수 있다.
class PageNumbers extends StatelessWidget {
  PageNumbers({
    super.key,
    required this.page,
    required this.pages,
    required this.onPick,
  });

  /// 지금 보고 있는 장 (0부터)
  final int page;

  /// 전체 장 수
  final int pages;

  final ValueChanged<int> onPick;

  /// 한 번에 세우는 번호 개수
  static const _window = 7;

  @override
  Widget build(BuildContext context) {
    if (pages < 2) return SizedBox.shrink();

    // 지금 장을 가운데 두되 양 끝에서는 안쪽으로 붙인다
    var first = page - _window ~/ 2;
    if (first + _window > pages) first = pages - _window;
    if (first < 0) first = 0;
    final last = (first + _window).clamp(0, pages);

    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrow(CupertinoIcons.chevron_left, page > 0 ? page - 1 : null),
          SizedBox(width: 4),
          for (var i = first; i < last; i++) ...[
            if (i > first) SizedBox(width: 4),
            _number(i),
          ],
          SizedBox(width: 4),
          _arrow(
            CupertinoIcons.chevron_right,
            page < pages - 1 ? page + 1 : null,
          ),
        ],
      ),
    );
  }

  Widget _number(int index) {
    final here = index == page;
    final box = Container(
      constraints: BoxConstraints(minWidth: 32),
      height: 32,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: here ? AppColors.primary : AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${index + 1}',
        style: AppTextStyles.body2.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: here ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
    // 지금 보고 있는 장은 누를 것이 없다
    return here ? box : Pressable(onTap: () => onPick(index), child: box);
  }

  /// 끝에 닿으면 [target]이 null — 자리는 그대로 두고 흐리게만 한다
  Widget _arrow(IconData icon, int? target) {
    final box = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 13,
        color: target == null ? AppColors.gray300 : AppColors.textSecondary,
      ),
    );
    if (target == null) return box;
    return Pressable(onTap: () => onPick(target), child: box);
  }
}
