part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 항목 · 지점 고르기
// ---------------------------------------------------------------------------

/// 폰 항목 탭 — 밑줄 탭 (업무 탭과 같은 결)
///
/// 알약을 늘어놓으면 화면 폭을 넘겨 옆으로 밀어야 하는데,
/// 항목이 몇 개인지 한눈에 안 보인다. 한 화면에 다 세운다.
///
/// **칸을 6등분하지 않는다.** 등분하면 글자 길이가 달라서 남는 여백이
/// 칸마다 달라진다 — `프로젝트`·`환경정비`(4자)는 칸을 꽉 채워 서로 붙고,
/// `매출`·`친절`(2자)은 양옆이 남아 멀어 보였다 (실제로 그렇게 보였다).
/// **칸 = 글자 폭 + 똑같은 여백**으로 잡으면 어느 두 글자 사이든 간격이 같다.
/// 칸끼리는 여전히 붙어 있어서 **밑줄은 지금처럼 한 줄로 이어진다.**
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  /// 글자 폭을 잴 때 쓰는 스타일 — **늘 굵게** 잰다
  ///
  /// 고른 칸만 굵어지는데, 그때그때 재면 탭을 옮길 때마다 칸 폭이 달라져서
  /// 글자들이 좌우로 흔들린다. 제일 넓은 상태로 고정해 둔다.
  static TextStyle get _measureStyle =>
      AppTextStyles.body2.copyWith(fontSize: 14, fontWeight: FontWeight.w700);

  double _widthOf(String text, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _measureStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final metric in _Metric.values) _widthOf(metric.short, scaler),
    ];
    final textTotal = widths.fold<double>(0, (sum, w) => sum + w);

    return LayoutBuilder(
      builder: (context, box) {
        // 글자만으로도 폭이 모자라면(글자 크기를 크게 키운 기기) 예전처럼 등분한다.
        // 그때는 `FittedBox` 가 줄여서 맞춘다 — 넘쳐서 잘리는 것보다 낫다.
        final gap = (box.maxWidth - textTotal) / widths.length;
        final last = _Metric.values.length - 1;
        return Row(
          children: [
            for (var i = 0; i < _Metric.values.length; i++)
              // 마지막 칸은 남는 폭을 그대로 받는다 — 소수점이 쌓여 1px 넘치면
              // 줄이 통째로 빨간 넘침 줄무늬가 된다
              if (gap <= 0 || i == last)
                Expanded(child: _tab(i))
              else
                SizedBox(width: widths[i] + gap, child: _tab(i)),
          ],
        );
      },
    );
  }

  Widget _tab(int i) {
    return Pressable(
      onTap: () => onSelect(i),
      scale: 0.94,
      child: Container(
        padding: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: i == selected ? AppColors.primary : AppColors.gray100,
              width: 2,
            ),
          ),
        ),
        child: Center(
          // 칸보다 이름이 길면 줄여서 맞춘다 (칸을 등분으로 되돌린 경우)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _Metric.values[i].short,
              maxLines: 1,
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: i == selected ? AppColors.primary : AppColors.gray500,
                fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
