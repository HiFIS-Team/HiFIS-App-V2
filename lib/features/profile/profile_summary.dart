part of 'profile_screen.dart';

// ---------------------------------------------------------------------------
// 프로필 요약
// ---------------------------------------------------------------------------

class _ProfileSummaryCard extends StatelessWidget {
  _ProfileSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 데스크톱에서 스크롤 밖에 놓이면 세로로 늘어나므로 내용만큼만 차지한다
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Avatar(size: 56),
              SizedBox(width: 16),
              // 이름이 길면 이메일과 함께 카드 밖으로 넘친다
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title2,
                    ),
                    SizedBox(height: 2),
                    Text(
                      currentUser?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: _SummaryField(
                  label: '사번',
                  value: currentUser?.empNo ?? '-',
                ),
              ),
              Expanded(
                child: _SummaryField(
                  label: '직급',
                  value: currentUser?.rank.label ?? '-',
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                // 팀은 관리자가 넣어 주는 값이라 비어 있을 수 있다
                child: _SummaryField(
                  label: '팀',
                  value: currentUser?.team ?? '-',
                ),
              ),
              Expanded(
                child: _SummaryField(
                  label: '권한',
                  value: currentUser?.role.label ?? '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  _SummaryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 내 아바타 — 사진이 있으면 사진, 없으면 아바타 색 + 이름 첫 글자
class _Avatar extends StatelessWidget {
  _Avatar({required this.size, this.color});

  final double size;

  /// 색 고르는 자리에서 미리보기로 쓸 때만 넘긴다. 없으면 지금 내 색
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final url = user?.avatarImageUrl;
    final fill = color ?? user?.color ?? AppColors.primary;
    final initial = me.isEmpty ? '·' : me.characters.first;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: url == null
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // 서명이 만료됐거나 못 받으면 색 아바타로 떨어진다
              errorBuilder: (_, _, _) => Text(
                initial,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}
