import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/audit_log_api.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/page_numbers.dart';
import '../../core/widgets/pressable.dart';

/// 활동 기록 — 누가 무엇을 등록·수정·삭제했는지 (모니터링 둘째 탭)
///
/// 줄을 누르면 **그때 보낸 내용**이 펼쳐진다. 공지를 뭐라고 썼는지,
/// 누구 권한을 무엇으로 바꿨는지가 거기 있다 (비밀번호는 서버가 가려서 준다).
class ActivityPanel extends StatefulWidget {
  ActivityPanel({super.key});

  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<ActivityPanel> {
  /// 한 장에 몇 줄까지
  static const _perPage = 100;

  List<AuditLog> _logs = const [];
  bool _loading = true;

  /// 0 전체 · 1 막힌 시도
  int _tab = 0;

  /// 지금 보고 있는 장 (0부터)
  int _page = 0;

  /// 서버가 헤더로 알려 준 전체 건수 — 장 수와 탭 라벨이 이걸 쓴다
  int _total = 0;
  int _blocked = 0;

  /// 장을 넘기는 동안 고정하는 기준선
  ///
  /// **이 화면을 여는 것 자체가 활동 로그로 남는다.** 기준을 안 잡으면
  /// 2장으로 넘어가는 사이에 새 줄이 앞에 끼어들어 1장 마지막 줄이 또 나온다.
  /// 새로고침은 이 판을 통째로 다시 만들어서(`ValueKey('activity-N')`)
  /// 기준선도 그때 새로 잡힌다.
  final DateTime _since = DateTime.now();

  /// 펼쳐 둔 줄
  final _open = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AuditLogApi.page(
        failedOnly: _tab == 1,
        limit: _perPage,
        offset: _page * _perPage,
        before: _since,
      );
      if (!mounted) return;
      setState(() {
        _logs = result.items;
        _total = result.total;
        _blocked = result.failed;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 탭·장을 옮기면 그 자리를 새로 받아온다 (펼쳐 둔 줄은 접는다)
  void _go({int? tab, int? page}) {
    setState(() {
      if (tab != null && tab != _tab) {
        _tab = tab;
        _page = 0; // 다른 탭의 5장째로 넘어가면 빈 화면이 뜬다
      }
      if (page != null) _page = page;
      _open.clear();
      _loading = true;
    });
    _load();
  }

  /// 지금 탭에 걸린 건수 — 장 수를 셀 때 쓴다
  int get _count => _tab == 0 ? _total : _blocked;

  int get _pages => (_count / _perPage).ceil();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final rows = _logs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(
          labels: ['전체 $_total', '막힌 시도 $_blocked'],
          selected: _tab,
          onSelect: (i) => _go(tab: i),
        ),
        SizedBox(height: 16),
        if (rows.isEmpty)
          EmptyCard(
            icon: CupertinoIcons.doc_text_search,
            text: _tab == 0 ? '아직 활동 기록이 없어요' : '막힌 시도가 없어요',
          )
        else
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: AppDecorations.card(radius: 20),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Container(height: 1, color: AppColors.divider),
                    ),
                  _Row(
                    log: rows[i],
                    open: _open.contains(rows[i].id),
                    onTap: () => setState(() {
                      if (!_open.remove(rows[i].id)) _open.add(rows[i].id);
                    }),
                  ),
                ],
              ],
            ),
          ),
        PageNumbers(
          page: _page,
          pages: _pages,
          onPick: (i) => _go(page: i),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  _Row({required this.log, required this.open, required this.onTap});

  final AuditLog log;
  final bool open;
  final VoidCallback onTap;

  /// 한 사람 이름 — 로그인 전 요청이거나 명단에 없으면 null
  String? get _name {
    final id = log.employeeId;
    if (id == null) return null;
    final name = StaffDirectory.instance.byId(id)?.name;
    return name == null || name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    final summary = _summary(log.payload);

    return Pressable(
      onTap: onTap,
      scale: 1,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          // 막힌 시도는 면으로 먼저 눈에 들어오게 둔다
          color: log.ok
              ? Colors.transparent
              : AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: log.ok ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
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
                SizedBox(
                  width: 96,
                  child: Text(
                    name ?? '알 수 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: Text(
                    log.action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: log.ok ? AppColors.textPrimary : AppColors.error,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // 보낸 내용 한 줄 요약 — 누르면 아래에 전문이 펼쳐진다
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ),
                SizedBox(width: 12),
                if (!log.ok)
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      '${log.status}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 66,
                  child: Text(
                    ago(log.createdAt),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  open
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 12,
                  color: AppColors.gray400,
                ),
              ],
            ),
            if (open) ...[
              SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.method} ${log.path}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                    if (log.payload != null) ...[
                      SizedBox(height: 8),
                      SelectableText(
                        _pretty(log.payload!),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    SizedBox(height: 8),
                    Text(
                      '${log.ip ?? '—'} · ${log.userAgent ?? '—'}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 한 줄 요약 — `제목 오늘 공지 · 고정 false`
String _summary(Map<String, dynamic>? payload) {
  if (payload == null || payload.isEmpty) return '';
  // 서버가 본문 대신 사유만 남긴 경우
  if (payload['_note'] case final String note) return note;
  if (payload['_query'] case final String query) return query;
  final parts = [
    for (final entry in payload.entries)
      if (!entry.key.startsWith('_')) '${entry.key} ${_short(entry.value)}',
  ];
  return parts.join(' · ');
}

String _short(Object? value) {
  final text = value is String ? value : jsonEncode(value);
  final flat = text.replaceAll('\n', ' ');
  return flat.length > 40 ? '${flat.substring(0, 40)}…' : flat;
}

String _pretty(Map<String, dynamic> payload) =>
    JsonEncoder.withIndent('  ').convert(payload);

/// '방금' · '12분 전' · '3시간 전' · '8.2.'
///
/// 접속 기록 목록과 같은 규칙 — 두 탭이 같은 시각 표기를 써야 안 헷갈린다.
String ago(DateTime time) {
  final gap = DateTime.now().difference(time);
  if (gap.inMinutes < 1) return '방금';
  if (gap.inMinutes < 60) return '${gap.inMinutes}분 전';
  if (gap.inHours < 24) return '${gap.inHours}시간 전';
  if (gap.inDays < 7) return '${gap.inDays}일 전';
  return '${time.month}.${time.day}.';
}
