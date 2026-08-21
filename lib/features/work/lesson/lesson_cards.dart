part of 'lesson_section.dart';

/// 세션 기록 한 줄 — 서명 미리보기, 이름·배지, 회차·시각, +1
/// 폰 목록 카드 — 회원 친절도·동료 평가 목록과 같은 결로 싸인 하나에 카드 하나
///
/// 데스크톱은 아직 [_SignRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _SignCard extends StatelessWidget {
  _SignCard({
    required this.sign,
    required this.onTap,
    this.showTrainer = false,
  });

  final SessionSign sign;
  final VoidCallback onTap;

  /// 누가 받은 싸인인지를 같이 적을지 — 남의 기록이 섞여 있을 때만 켠다
  final bool showTrainer;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sign.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        // 전사 기록에서는 누가 받았는지가 먼저다
                        showTrainer
                            ? '${_trainerName(sign)} · '
                                  '${_formatStamp(sign.signedAt)}'
                            : _formatStamp(sign.signedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _MemberBadge(isNew: sign.isNewRegistration),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                // 서명 미리보기 — 이 기록의 증거라 카드에서도 크게 둔다
                Container(
                  width: 92,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: _SignImage(url: sign.signatureFullUrl),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sign.roundLabel,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '+1',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignRow extends StatelessWidget {
  _SignRow({required this.sign, required this.onTap, this.showTrainer = false});

  final SessionSign sign;
  final VoidCallback onTap;

  /// 누가 받은 싸인인지를 같이 적을지 — 남의 기록이 섞여 있을 때만 켠다
  final bool showTrainer;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // 서명 미리보기
          Container(
            width: 64,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray100),
            ),
            child: _SignImage(url: sign.signatureFullUrl),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sign.displayName,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    _MemberBadge(isNew: sign.isNewRegistration),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  // 전사 기록에서는 누가 받았는지가 먼저다
                  showTrainer
                      ? '${_trainerName(sign)} · ${sign.roundLabel}'
                            ' · ${_formatStamp(sign.signedAt)}'
                      : '${sign.roundLabel} · ${_formatStamp(sign.signedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '+1',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 기록 화면 상단의 달 넘김 줄
class _MonthBar extends StatelessWidget {
  _MonthBar({
    required this.month,
    required this.count,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final int count;
  final bool loading;
  final VoidCallback onPrev;

  /// null 이면 더 갈 데가 없다 (이번 달)
  final VoidCallback? onNext;

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.textSecondary : AppColors.gray300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Row(
        children: [
          _arrow(CupertinoIcons.chevron_left, onPrev),
          Text(
            '${month.year}년 ${month.month}월',
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
          ),
          _arrow(CupertinoIcons.chevron_right, onNext),
          Spacer(),
          // 받아 오는 동안은 건수도 뼈대다 — 글자로 바꿔 두면 달을 넘길 때마다
          // `총 12건` → `불러오는 중` → `총 8건` 으로 세 번 바뀌어 깜빡인다
          if (loading)
            Skeleton(width: 46, height: 12)
          else
            Text(
              '총 $count건',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
