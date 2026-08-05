part of 'staff_screen.dart';

// ---------------------------------------------------------------------------
// 내 프로필 요약
// ---------------------------------------------------------------------------

/// 맨 위 내 카드 — 내가 누구인지와 지점 규모를 같이 보여준다
class _MyCard extends StatelessWidget {
  _MyCard({required this.branch});

  /// 보고 있는 지점 — 동료·직급 수를 이 지점 기준으로 센다
  final String branch;

  @override
  Widget build(BuildContext context) {
    final mine = _meOrSelf;
    // '전체'를 보고 있으면 전사를 센다 — 지점을 고르면 그 지점만
    final here = _members
        .where((m) => m.active && _inBranch(m, branch))
        .toList();
    final ranks = {for (final m in here) m.rank}.length;
    final working = here.where((m) => m.status.present).length;

    return Container(
      decoration: AppDecorations.card(radius: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // 내 카드임을 알리는 브랜드 띠
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Row(
                children: [
                  _StatusAvatar(member: mine, size: 62),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '내 프로필',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 6),
                            _PermissionTag(permission: mine.permission),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(mine.name, style: AppTextStyles.title2),
                        // 목업에 없는 계정으로 로그인하면 지점을 모른다.
                        // 빈 값을 그대로 이으면 ' · 대표' 처럼 앞이 비어 보인다
                        if (_subtitle(mine).isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            _subtitle(mine),
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: 2),
                        Text(mine.email, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  _count('동료', here.where((m) => !m.isMe).length),
                  _divider(),
                  _count('직급', ranks),
                  _divider(),
                  _count('근무중', working, color: AppColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// '강남점 · 대표' — 모르는 값은 빼고 잇는다
  String _subtitle(_Member member) =>
      [member.branchLabel, member.role].where((s) => s.isNotEmpty).join(' · ');

  Widget _count(String label, int value, {Color? color}) => SizedBox(
    width: 74,
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.title1.copyWith(
            fontSize: 26,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 34, color: AppColors.gray100);
}
