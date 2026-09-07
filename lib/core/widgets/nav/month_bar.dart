import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../feedback/skeleton.dart';
import '../input/pressable.dart';

/// 달 이동 줄 — `‹ 2026년 8월 ›` 과 오른쪽 끝의 건수
///
/// 한 달치를 쭉 내려 보는 화면들이 같이 쓴다 (세션 기록 · 환경정비 수행
/// 내역 · 개인 업무 내역). **한 곳에 두는 이유는 자리와 여백이 픽셀까지
/// 같아야 하기 때문이다** — 화면마다 따로 그리면 달 이름이 몇 px씩 어긋난다.
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.month,
    required this.count,
    required this.loading,
    required this.onPrev,
    required this.onNext,
    this.unit = '건',
    this.showCount = true,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 24, 6),
  });

  final DateTime month;
  final int count;

  /// 오른쪽 끝 건수를 그릴지 — 동료평가 폰 화면만 끈다 (2026-09-07 요청).
  /// 거기는 명단이 곧 건수라 `총 0건` 이 같은 말을 두 번 하는 자리다.
  final bool showCount;

  /// 줄 바깥 여백 — **기본값을 바꾸지 않는다.** 이 줄을 쓰는 화면이 다섯인데
  /// 달 이름 위치가 픽셀까지 같아야 해서, 다르게 둘 화면만 여기로 넘긴다.
  final EdgeInsets padding;

  /// 건수 뒤에 붙는 한 글자 — 환경정비는 `회`, 세션은 `건`
  final String unit;

  /// 받아 오는 동안은 건수도 뼈대다 — 글자로 바꿔 두면 달을 넘길 때마다
  /// `총 12건` → `불러오는 중` → `총 8건` 으로 세 번 바뀌어 깜빡인다
  final bool loading;

  final VoidCallback onPrev;

  /// null 이면 더 갈 데가 없다 (이번 달)
  final VoidCallback? onNext;

  /// 테두리 없이 아이콘만 두고 여백으로 누를 자리를 만든다. 회색 상자를
  /// 두르면 줄이 무거워진다.
  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.textSecondary : AppColors.gray300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    // 기본 왼쪽 16 인 것은 화살표가 제 안에 8 을 갖고 있어서다 — 눈에 보이는
    // 끝이 24 로 아래 목록과 맞는다
    padding: padding,
    child: Row(
      children: [
        _arrow(CupertinoIcons.chevron_left, onPrev),
        Text(
          '${month.year}년 ${month.month}월',
          style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
        ),
        _arrow(CupertinoIcons.chevron_right, onNext),
        if (showCount) ...[
          const Spacer(),
          if (loading)
            Skeleton(width: 46, height: 12)
          else
            Text(
              '총 $count$unit',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ],
    ),
  );
}
