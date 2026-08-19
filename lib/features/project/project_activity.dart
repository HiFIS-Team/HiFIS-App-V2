part of 'project_screen.dart';

/// 활동 타임라인 — **시스템 기록만** (2026-08-19)
///
/// 예전에는 댓글이 여기 섞여 있고 입력칸도 있었다. 댓글이 오른쪽 세로 줄의
/// 말풍선(시트)으로 빠지면서 이 카드는 '무슨 일이 있었나' 만 남았다.
class _ActivityCard extends StatefulWidget {
  _ActivityCard({required this.project});

  final _Project project;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  /// 활동은 계속 쌓이므로 처음에는 최근 것만 보여준다
  static const _fold = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // **댓글은 오른쪽 세로 줄로 빠졌다 (2026-08-19)** — 여기엔 시스템 기록만
    // 남는다. 서버도 `project_activities` 에 더는 댓글을 안 쌓는다
    final all = widget.project.events.where((e) => !e.comment).toList();
    final events = _expanded ? all : all.take(_fold).toList();
    final hidden = all.length - events.length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('활동', style: AppTextStyles.label),
              SizedBox(width: 6),
              Text(
                '${all.length}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '아직 활동이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (final event in events)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.comment)
                      Avatar(name: event.author, size: 28)
                    else
                      // 시스템 기록은 아바타 대신 점으로 구분한다
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                event.author,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _relative(event.time),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1),
                          Text(
                            event.text,
                            style: AppTextStyles.body2.copyWith(
                              color: event.comment
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (hidden > 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Pressable(
                onTap: () => setState(() => _expanded = true),
                scale: 0.99,
                pressedColor: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  '이전 활동 $hidden개 더 보기',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
