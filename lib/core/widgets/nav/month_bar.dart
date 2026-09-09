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
  }) : compact = false;

  /// 머리말 줄에 얹는 작은 형태 — `‹ 2026년 9월 ›` 만 남기고 줄을 안 차지한다
  ///
  /// 판이 짧은 화면에서 달 이동에 한 줄을 통째로 내주기가 아깝다.
  /// 동료평가가 이걸 쓴다 — 폰은 `평가 전 · 평가 완료` 목록바 오른쪽,
  /// PC 는 `평가 작성` 머리말 오른쪽 끝이다 (2026-09-09 요청).
  ///
  /// **건수를 안 그린다.** 얹히는 자리마다 이미 건수를 말하고 있고,
  /// `총 N건` 까지 붙으면 머리말이 두 겹으로 읽힌다.
  const MonthBar.compact({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
  }) : count = 0,
       loading = false,
       unit = '건',
       showCount = false,
       padding = EdgeInsets.zero,
       compact = true;

  /// 머리말에 얹히는 작은 형태인가 — 글자를 머리말 제목과 같은 14 로 맞추고
  /// 줄 폭을 안 차지한다 (기본형은 15 에 한 줄을 다 쓴다)
  final bool compact;

  final DateTime month;
  final int count;

  /// 오른쪽 끝 건수를 그릴지 — [MonthBar.compact] 가 끈다.
  /// 얹히는 자리는 이미 건수를 말하고 있어서 `총 N건` 이 두 번이 된다.
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
        // 작은 형태는 누를 자리를 조금 줄인다 — 머리말 줄 높이를 안 늘리려고
        padding: EdgeInsets.all(compact ? 6 : 8),
        child: Icon(
          icon,
          size: compact ? 13 : 15,
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
      // 작은 형태는 얹히는 줄에서 제 폭만 쓴다
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _arrow(CupertinoIcons.chevron_left, onPrev),
        Text(
          '${month.year}년 ${month.month}월',
          // 머리말 제목(`label` 14)과 같은 크기로 맞춘다 — 옆에 나란히 서는데
          // 기본형(15)을 그대로 쓰면 달이 제목보다 커 보인다
          style: (compact ? AppTextStyles.label : AppTextStyles.body2).copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
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
