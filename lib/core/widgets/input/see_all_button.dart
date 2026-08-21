import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pressable.dart';

/// 카드 머리말 오른쪽의 '전체 보기' 버튼
///
/// 카드에는 최근 몇 건만 보여주고 나머지는 [showFullPage]로 여는 패턴이
/// 여러 화면(월차·급여·수업·칭찬·환경정비)에 반복된다. 화면마다 따로 그리면
/// 글자색·화살표 크기가 조금씩 어긋나므로 여기 한 곳에서만 그린다.
class SeeAllButton extends StatelessWidget {
  SeeAllButton({super.key, required this.onTap, this.label = '전체 보기'});

  final VoidCallback onTap;

  /// 기본은 '전체 보기' — 뜻이 다를 때만 바꾼다
  final String label;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 2),
          Icon(
            CupertinoIcons.chevron_right,
            size: 11,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
