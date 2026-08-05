part of 'monitoring_screen.dart';

// ---------------------------------------------------------------------------
// 들어온 순서
// ---------------------------------------------------------------------------

/// 접속 목록 — 실패한 줄은 빨간 면으로 눈에 먼저 들어오게 둔다
class _LogList extends StatelessWidget {
  _LogList({required this.logs});

  final List<AccessLog> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Container(height: 1, color: AppColors.divider),
              ),
            _LogRow(log: logs[i]),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  _LogRow({required this.log});

  final AccessLog log;

  /// 로그인에 성공한 사람 이름 — 실패거나 명단에 없으면 null
  String? get _name {
    final id = log.employeeId;
    if (id == null) return null;
    final name = StaffDirectory.instance.byId(id)?.name;
    return name == null || name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final failed = log.event.failed;
    final name = _name;
    final color = failed ? AppColors.error : AppColors.success;

    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: failed
            ? AppColors.error.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 14),
          if (name != null)
            Avatar(name: name, size: 32)
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.question,
                size: 16,
                color: AppColors.gray500,
              ),
            ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name ?? (log.email ?? '알 수 없음'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: failed ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  failed && name != null
                      ? '${log.email ?? ''} 로 로그인 실패'
                      : log.event.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          // 접속한 프로그램 — 서버가 받은 문자열 그대로
          Expanded(
            flex: 3,
            child: Text(
              log.userAgent ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              log.ip ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 66,
            child: Text(
              _ago(log.createdAt),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 새로 받아오기 — 헤더 오른쪽
class _RefreshButton extends StatelessWidget {
  _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: AppColors.gray500),
            SizedBox(width: 6),
            Text(
              '새로고침',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '방금' · '12분 전' · '3시간 전' · '8.2.'
String _ago(DateTime time) {
  final gap = DateTime.now().difference(time);
  if (gap.inMinutes < 1) return '방금';
  if (gap.inMinutes < 60) return '${gap.inMinutes}분 전';
  if (gap.inHours < 24) return '${gap.inHours}시간 전';
  if (gap.inDays < 7) return '${gap.inDays}일 전';
  return '${time.month}.${time.day}.';
}

/// '09:14'
String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
