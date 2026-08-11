part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 점수 내역 — 종합 탭에서 사람을 누르면 뜬다
// ---------------------------------------------------------------------------

/// 내역 한 줄에 쓰는 값 — 라벨과 점수, 그리고 근거 한 마디
typedef _BreakdownLine = ({String label, int score, String note});

/// 한 사람이 항목별로 몇 점을 받았는지
///
/// **매출은 점수가 아니라 금액이다.** 종합은 항목마다 1등을 100점으로 두고
/// 환산해 평균 내는 값이라 여기서 항목 점수를 더해도 종합이 안 나온다 —
/// 그래서 합계 줄을 두지 않는다.
List<_BreakdownLine> _breakdownOf(_Ranker r) => [
  (
    label: '매출',
    score: r.revenue,
    note: '신규 ${r.newSignups} · 재등록 ${r.reSignups}',
  ),
  (label: '친절', score: r.kindness, note: '설문 ${r.reviews}건'),
  (
    label: '프로젝트',
    score: r.projectScore,
    note: '${r.projectDone} / ${r.projectTotal}건',
  ),
  (label: '환경정비', score: r.careScore, note: '${r.care}회'),
  (label: '수업', score: r.lessonScore, note: '${r.lessons}개'),
  (label: '블로그', score: r.blogScore, note: '${r.blogScore ~/ 5}명'),
  (label: '인스타', score: r.instaScore, note: '${r.instaScore ~/ 5}명'),
  (label: 'OT → PT', score: r.otptScore, note: '${r.otptScore ~/ 5}명'),
];

/// 점수 내역 카드 — PC 는 순위표 옆에, 폰은 아래에서 올라오는 시트 안에 놓인다
class _ScoreBreakdown extends StatelessWidget {
  _ScoreBreakdown({required this.ranker, this.onClose, this.sheet = false});

  final _Ranker ranker;

  /// PC 에서 판을 닫는 X. 폰 시트는 밖을 눌러 닫으므로 안 준다.
  final VoidCallback? onClose;

  /// 폰 시트 안인가 — 시트가 곧 면이라 카드 껍데기를 두르지 않고
  /// 대신 위에 쓸어내릴 손잡이를 둔다
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: sheet
          ? EdgeInsets.fromLTRB(20, 8, 20, 4)
          : EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: sheet ? null : AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sheet) ...[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
          Row(
            children: [
              Avatar(name: ranker.name, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ranker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (ranker.team.isNotEmpty)
                      Text(
                        ranker.team,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (onClose != null)
                Pressable(
                  onTap: onClose!,
                  scale: 0.9,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: AppColors.gray500,
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          for (final line in _breakdownOf(ranker)) ...[
            _BreakdownRow(line: line),
            SizedBox(height: 2),
          ],
          // 시트는 화면 아래 끝에 붙는다 — 홈 인디케이터 자리를 비워 준다
          if (sheet) SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  _BreakdownRow({required this.line});

  final _BreakdownLine line;

  @override
  Widget build(BuildContext context) {
    // 0점인 항목은 흐리게 — 지운 게 아니라 아직 안 쌓인 것이다
    final empty = line.score <= 0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              line.label,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                color: empty ? AppColors.gray400 : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.gray400,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            // 매출만 금액이라 순위표와 같은 '만원' 표기를 쓴다. 나머지는 점수다
            line.label == '매출'
                ? '${_comma((line.score / 10000).round())}만원'
                : '${line.score}점',
            style: AppTextStyles.body2.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: empty ? AppColors.gray400 : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
