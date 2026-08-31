part of 'lesson_section.dart';

/// 세션 기록 한 줄 — 서명 미리보기, 이름·배지, 회차·시각, +1
/// 폰 목록 카드 — **동료 평가·센터 기여도 카드와 같은 짜임**이다
///
/// 셋이 같은 화면(업무)에서 목록으로 서는데 이것만 모양이 달랐다.
/// 저 둘은 `[왼쪽 40] [이름 / 부제] [오른쪽 배지]` 한 줄에 아래 한 줄인데,
/// 여기는 서명을 아래에 **92×52** 로 크게 깔아서 카드가 한 겹 더 두꺼웠다.
/// 서명 원본은 흰 바탕이라 회색 상자 안에서 **흰 판이 박힌 것처럼** 보였다.
///
/// 그래서 서명을 왼쪽 40 자리(동료 평가의 아바타·센터 기여도의 항목 아이콘)로
/// 옮기고 상자 바탕을 **흰색**으로 바꿨다 — 흰 바탕끼리 만나 이음매가 없다.
/// 크게 보는 것은 눌렀을 때 뜨는 창이 맡는다.
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
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    // 회색이 아니라 흰색이다 — 서명 원본이 흰 바탕이라
                    // 회색을 깔면 남는 자리가 흰 판으로 도드라진다
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
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
                          Flexible(
                            child: Text(
                              sign.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body1.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
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
                // 센터 기여도의 `+N` 알약과 같은 모양이다
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '+1',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            // 아래 한 줄 — 센터 기여도의 내용 줄, 동료 평가의 별점 줄 자리다
            Text(
              sign.roundLabel,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
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
