part of 'monitoring_screen.dart';

// ---------------------------------------------------------------------------
// 순위 두 판
// ---------------------------------------------------------------------------

/// 가로 막대 순위 — 사람과 프로그램이 같은 모양을 쓴다
class _Ranked extends StatelessWidget {
  _Ranked({required this.title, required this.rows, required this.avatars});

  final String title;

  /// (이름, 건수) — 이미 많은 순으로 정렬돼 있다
  final List<(String, int)> rows;

  /// 왼쪽에 아바타를 둘지 (프로그램에는 안 둔다)
  final bool avatars;

  @override
  Widget build(BuildContext context) {
    final top = rows.isEmpty ? 0 : rows.first.$2;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '아직 없어요',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              Row(
                children: [
                  if (avatars) ...[
                    Avatar(name: rows[i].$1, size: 24),
                    SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: avatars ? 58 : 120,
                    child: Text(
                      rows[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 8, color: AppColors.gray50),
                          FractionallySizedBox(
                            // 1등이 꽉 차고 나머지는 그 비율만큼
                            widthFactor: top == 0 ? 0 : rows[i].$2 / top,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gradientStart,
                                    AppColors.gradientEnd,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${rows[i].$2}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
