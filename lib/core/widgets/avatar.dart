import 'package:flutter/material.dart';

import '../data/staff.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 이름 첫 글자 동그라미 — 색은 직원 명단에서 가져온다
class Avatar extends StatelessWidget {
  Avatar({super.key, required this.name, this.size = 24});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: staffOf(name).color,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 참여자 아바타 겹쳐 보이기 (넘치면 +N)
class AvatarStack extends StatelessWidget {
  AvatarStack({super.key, required this.names, this.size = 22});

  final List<String> names;
  final double size;

  /// 이보다 많으면 나머지는 +N으로 접는다
  static const _max = 4;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(_max).toList();
    final rest = names.length - shown.length;
    final step = size * 0.72;

    return SizedBox(
      height: size,
      width: shown.length * step + (rest > 0 ? step + size * 0.4 : size - step),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                padding: EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Avatar(name: shown[i], size: size - 3),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  '+$rest',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
