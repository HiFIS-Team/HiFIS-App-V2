import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/docs/approval_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/display/placeholder_screen.dart';
import '../../core/widgets/input/pressable.dart';

/// 전자결재 화면 (목업)
///
/// 구매·출장·근무 변경처럼 승인이 필요한 일을 올리고, 결재선을 따라
/// 승인·반려를 받는다. 데스크톱은 좌측 목록 + 우측 상세 2단 구조.
/// 모바일 화면은 아직 준비 중 — PC를 먼저 다듬는다.
class ApprovalScreen extends StatefulWidget {
  ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

/// 결재를 올릴 수 있는 사람 — **MASTER·ADMIN 은 못 올린다**
///
/// 결재는 대표가 판단해 주는 것이라, 판단하는 쪽이 올리면 자기가 올려
/// 자기가 결재하는 자리가 된다. 서버도 같은 기준으로 막는다
/// (`NOT_A_REQUESTER`) — 눌러도 403 날 버튼은 안 낸다.
bool get _canWrite => myRole != Role.master && myRole != Role.admin;

class _ApprovalScreenState extends State<ApprovalScreen> {
  _State _filter = _State.pending;

  /// 고른 문서 — 목록이 갈릴 때마다 새 객체가 오므로 id 로 들고 있는다
  String? _selectedId;

  bool _loading = !_docsLoaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadDocs();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Doc> get _visible {
    // 회수는 흔치 않아 탭을 따로 두지 않고 반려 칸에 같이 보여준다
    bool matches(_Doc doc) => _filter == _State.rejected
        ? doc.state == _State.rejected || doc.state == _State.withdrawn
        : doc.state == _filter;
    return _docs.where(matches).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  _Doc? _syncSelection(List<_Doc> list) {
    if (list.isEmpty) return null;
    for (final doc in list) {
      if (doc.id == _selectedId) return doc;
    }
    return list.first;
  }

  Future<void> _create() async {
    final draft = await _showComposer(context);
    if (draft == null || !mounted) return;

    final approver = _defaultApprover;
    if (approver == null) {
      AppToast.show(context, '결재를 받을 대표를 찾지 못했어요');
      return;
    }
    try {
      final created = _fromServer(
        await ApprovalApi.create(
          kind: draft.kind.label,
          title: draft.title,
          content: draft.body,
          approverIds: [approver.id],
          amount: draft.amount == 0 ? null : draft.amount,
          startDate: draft.startDate,
          endDate: draft.endDate,
          place: draft.place,
        ),
      );
      if (!mounted) return;
      setState(() {
        _docs.add(created);
        _filter = _State.pending;
        _selectedId = created.id;
      });
      AppToast.show(context, '결재를 올렸어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 승인·반려 모두 의견을 남겨야 처리된다
  Future<void> _decide(_Doc doc, {required bool approve}) async {
    if (!doc.myTurn) return;
    final comment = await _showDecisionDialog(
      context,
      doc: doc,
      approve: approve,
    );
    if (comment == null || !mounted) return;

    try {
      final saved = approve
          ? await ApprovalApi.approve(doc.id, comment: comment)
          : await ApprovalApi.reject(doc.id, comment: comment);
      if (!mounted) return;
      setState(() => _replace(_fromServer(saved)));
      AppToast.show(context, approve ? '결재를 승인했어요' : '결재를 반려했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 회수 — 올린 사람이 진행 중인 결재를 물린다
  Future<void> _withdraw(_Doc doc) async {
    final ok = await showConfirmDialog(
      context,
      title: '결재를 회수할까요?',
      message: '올린 문서를 물립니다. 다시 올리려면 새로 작성해야 해요.',
      confirmLabel: '회수',
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      final saved = await ApprovalApi.withdraw(doc.id);
      if (!mounted) return;
      setState(() {
        _replace(_fromServer(saved));
        // 회수한 건 대기 목록에서 빠져 반려 칸으로 간다
        _filter = _State.rejected;
      });
      AppToast.show(context, '결재를 회수했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '✅', title: '전자결재');

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final list = _visible;
    final selected = _syncSelection(list);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _DocList(
                docs: list,
                selected: selected,
                filter: _filter,
                onFilter: (v) => setState(() {
                  _filter = v;
                  _selectedId = null;
                }),
                onSelect: (doc) => setState(() => _selectedId = doc.id),
                onCreate: _canWrite ? _create : null,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyDetail(
                    filter: _filter,
                    onCreate: _canWrite ? _create : null,
                  )
                : _DocDetail(
                    key: ValueKey(selected.id),
                    doc: selected,
                    onApprove: () => _decide(selected, approve: true),
                    onReject: () => _decide(selected, approve: false),
                    onWithdraw: () => _withdraw(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 목록 ──

class _DocList extends StatelessWidget {
  _DocList({
    required this.docs,
    required this.selected,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Doc> docs;
  final _Doc? selected;
  final _State filter;
  final ValueChanged<_State> onFilter;
  final ValueChanged<_Doc> onSelect;

  /// null 이면 올리기 버튼을 안 그린다 (MASTER·ADMIN)
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 글래스 헤더 버튼 영역만큼 비워둔다
        SizedBox(height: 64),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text('전자결재', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${docs.length}',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (onCreate case final create?)
                Pressable(
                  onTap: create,
                  scale: 0.94,
                  pressedColor: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(100),
                  padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '결재 올리기',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _StateTabs(selected: filter, onSelect: onFilter),
        ),
        Expanded(
          child: docs.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    '${filter.label} 결재가 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _DocTile(
                    doc: docs[i],
                    selected: docs[i] == selected,
                    onTap: () => onSelect(docs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 대기 / 승인 / 반려 세그먼트
class _StateTabs extends StatelessWidget {
  _StateTabs({required this.selected, required this.onSelect});

  final _State selected;
  final ValueChanged<_State> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 회수는 탭을 따로 두지 않는다 — 반려 칸에 같이 들어간다
          for (final state in _State.tabs)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(state),
                scale: 0.97,
                // 배경은 애니메이션 없이 즉시 바꾼다
                child: Container(
                  decoration: BoxDecoration(
                    color: state == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: state == selected
                          ? AppColors.gray100
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      state.label,
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 13,
                        color: state == selected
                            ? AppColors.textPrimary
                            : AppColors.gray500,
                        fontWeight: state == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocTile extends StatefulWidget {
  _DocTile({required this.doc, required this.selected, required this.onTap});

  final _Doc doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends State<_DocTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(doc.kind.icon, size: 15, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    doc.kind.label,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  _StateBadge(state: doc.state),
                ],
              ),
              SizedBox(height: 6),
              Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Avatar(name: doc.writer, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '${doc.writer} · ${_date(doc.date)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  if (doc.amount > 0)
                    Text(
                      _won(doc.amount),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  _EmptyDetail({required this.filter, required this.onCreate});

  final _State filter;

  /// null 이면 올리기 버튼을 안 그린다 (MASTER·ADMIN)
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.assignment_turned_in_outlined,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('전자결재', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '${filter.label} 결재가 아직 없어요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          if (onCreate case final create?) ...[
            SizedBox(height: 24),
            Pressable(
              onTap: create,
              scale: 0.97,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '결재 올리기',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 우측 상세 ──

class _DocDetail extends StatelessWidget {
  _DocDetail({
    super.key,
    required this.doc,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
  });

  final _Doc doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(32, 64, 32, bottomBarInset(context)),
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                doc.kind.icon,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              doc.kind.label,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 10),
            _StateBadge(state: doc.state),
          ],
        ),
        SizedBox(height: 12),
        Text(doc.title, style: AppTextStyles.title1),
        SizedBox(height: 8),
        Row(
          children: [
            Avatar(name: doc.writer, size: 22),
            SizedBox(width: 8),
            Text(
              '${doc.writer} ${_rankOf(doc.writerId)} · ${_date(doc.date)} 신청',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        SizedBox(height: 20),
        if (doc.state == _State.pending) ...[
          // 프로젝트 기한 연장 카드와 같은 틀 — 아이콘 + 옅은 색 바탕 + 오른쪽 버튼.
          // 버튼은 **내 차례일 때만** 나온다 (아니면 서버가 403 을 준다)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '결재 승인 대기',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        // 승인은 어차피 대표만 한다 — 누구 차례인지는 안 적는다
                        doc.myTurn ? '의견을 남겨야 처리돼요' : '대표 결재를 기다리고 있어요',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 올린 사람은 아직 아무도 처리하지 않은 결재를 물릴 수 있다
                if (doc.canWithdraw) ...[
                  SizedBox(width: 12),
                  Pressable(
                    onTap: onWithdraw,
                    scale: 0.96,
                    pressedColor: AppColors.gray100,
                    borderRadius: BorderRadius.circular(10),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Text(
                      '회수',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (doc.myTurn) ...[
                  SizedBox(width: 12),
                  DecideButtons(onApprove: onApprove, onReject: onReject),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        if (doc.amount > 0) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: AppDecorations.card(),
            child: Row(
              children: [
                Text('금액', style: AppTextStyles.label),
                Spacer(),
                Text(
                  _won(doc.amount),
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        if (doc.startDate case final start?) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('기간', style: AppTextStyles.label),
                    Spacer(),
                    Text(
                      _period(start, doc.endDate),
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if ((doc.place ?? '').isNotEmpty) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text('장소', style: AppTextStyles.label),
                      Spacer(),
                      Text(
                        doc.place!,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내용', style: AppTextStyles.label),
              SizedBox(height: 10),
              Text(
                doc.body.isEmpty ? '적어둔 내용이 없어요' : doc.body,
                style: AppTextStyles.body2.copyWith(
                  height: 1.6,
                  color: doc.body.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (doc.state != _State.pending) ...[
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: doc.state.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (doc.state) {
                    _State.approved => Icons.check_circle_rounded,
                    _State.withdrawn => Icons.undo_rounded,
                    _ => Icons.cancel_rounded,
                  },
                  size: 20,
                  color: doc.state.color,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            switch (doc.state) {
                              _State.approved => '승인됨',
                              _State.withdrawn => '회수됨',
                              _ => '반려됨',
                            },
                            style: AppTextStyles.body2.copyWith(
                              color: doc.state.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          // 처리한 사람은 결재선에서 꺼낸다 — 회수는 올린 사람이다
                          Text(
                            _decidedBy(doc),
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      if (doc.lastActed?.comment case final comment?
                          when comment.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          comment,
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 처리 상태 알약
class _StateBadge extends StatelessWidget {
  _StateBadge({required this.state});

  final _State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: state.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── 결재 올리기 ──

Future<_Draft?> _showComposer(BuildContext context) {
  return showDialog<_Draft>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(
      child: Material(type: MaterialType.transparency, child: _Composer()),
    ),
  );
}

class _Composer extends StatefulWidget {
  _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _body = TextEditingController();
  final _place = TextEditingController();
  final _titleFocus = FocusNode();

  _Kind _kind = _Kind.expense;

  /// 외근·출장, 근무 변경일 때만 쓴다 (기본은 오늘 하루)
  late DateTime _start = DateTime.now();
  late DateTime _end = DateTime.now();

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _body.dispose();
    _place.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// 날짜 고르기 — 일정 화면과 같은 달력을 쓴다
  Future<void> _pick({required bool start}) async {
    final base = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              (AppColors.isDark
                      ? ColorScheme.dark(surface: AppColors.surface)
                      : ColorScheme.light(surface: AppColors.surface))
                  .copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        // 시작이 끝보다 뒤로 가면 끝도 같이 민다
        if (_end.isBefore(_start)) _end = picked;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '결재 제목을 입력해주세요');
      _titleFocus.requestFocus();
      return;
    }
    final place = _place.text.trim();
    Navigator.pop(
      context,
      _Draft(
        kind: _kind,
        title: title,
        amount: int.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
        body: _body.text.trim(),
        // 기간·장소는 그 종류일 때만 보낸다 — 안 보이는 칸의 값이 따라가면 안 된다
        startDate: _kind.needsWhen ? _start : null,
        endDate: _kind.needsWhen ? _end : null,
        place: _kind.needsWhen && place.isNotEmpty ? place : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = _title.text.trim().isEmpty;

    return Container(
      width: 520,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('결재 올리기', style: AppTextStyles.title2),
            SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('결재 종류', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    // 두 칸씩 끊어 카드로 고른다
                    for (var i = 0; i < _Kind.values.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (var j = i; j < i + 2; j++) ...[
                              if (j > i) SizedBox(width: 8),
                              Expanded(
                                child: _KindCard(
                                  kind: _Kind.values[j],
                                  selected: _kind == _Kind.values[j],
                                  onTap: () =>
                                      setState(() => _kind = _Kind.values[j]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(height: 10),
                    Text('제목', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    _Field(
                      controller: _title,
                      focusNode: _titleFocus,
                      hint: '무엇에 대한 결재인가요?',
                      onSubmitted: _submit,
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Text('금액', style: AppTextStyles.label),
                        SizedBox(width: 4),
                        Text('(선택)', style: AppTextStyles.caption),
                      ],
                    ),
                    SizedBox(height: 8),
                    _Field(
                      controller: _amount,
                      hint: '0',
                      align: TextAlign.right,
                      suffix: '원',
                      digitsOnly: true,
                    ),
                    // 외근·출장, 근무 변경은 언제 어디로 가는지가 결재의 핵심이다.
                    // 나머지 종류에는 이 두 칸이 안 나온다.
                    if (_kind.needsWhen) ...[
                      SizedBox(height: 14),
                      Text('기간', style: AppTextStyles.label),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              value: _start,
                              onTap: () => _pick(start: true),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('~', style: AppTextStyles.body2),
                          ),
                          Expanded(
                            child: _DateField(
                              value: _end,
                              onTap: () => _pick(start: false),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Text('장소', style: AppTextStyles.label),
                          SizedBox(width: 4),
                          Text('(선택)', style: AppTextStyles.caption),
                        ],
                      ),
                      SizedBox(height: 8),
                      _Field(controller: _place, hint: '어디로 가나요?'),
                    ],
                    SizedBox(height: 14),
                    Text('내용', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    _Field(
                      controller: _body,
                      hint: '사유·근거·견적 등 결재에 필요한 내용을 적어주세요',
                      lines: 4,
                    ),
                    SizedBox(height: 14),
                    // 결재선은 아직 못 고른다 — 대표 한 사람에게 올린다
                    // (서버는 여러 명을 순서대로 세울 수 있다, backend-gap.md 48번)
                    Row(
                      children: [
                        Text('결재자', style: AppTextStyles.label),
                        SizedBox(width: 10),
                        if (_defaultApprover case final approver?) ...[
                          Avatar(name: approver.name, size: 24),
                          SizedBox(width: 6),
                          Text(
                            '${approver.name} ${approver.rank.label}',
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          Text(
                            '대표를 찾지 못했어요',
                            style: AppTextStyles.body2.copyWith(
                              fontSize: 14,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.97,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Text(
                    '취소',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Pressable(
                  onTap: _submit,
                  scale: 0.97,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      // 제목을 적기 전에는 흐리게 — 눌러도 안내만 뜬다
                      color: empty ? AppColors.gray200 : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '올리기',
                      style: AppTextStyles.body2.copyWith(
                        color: empty ? AppColors.gray500 : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

/// 결재 종류 카드 — 아이콘 아래 이름, 고르면 파랗게 찬다
class _KindCard extends StatefulWidget {
  _KindCard({required this.kind, required this.selected, required this.onTap});

  final _Kind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_KindCard> createState() => _KindCardState();
}

class _KindCardState extends State<_KindCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : AppColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.gray200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.kind.icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                widget.kind.label,
                style: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 승인·반려 ──

/// 승인·반려 의견 받기 (취소면 null)
Future<String?> _showDecisionDialog(
  BuildContext context, {
  required _Doc doc,
  required bool approve,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _DecisionDialog(doc: doc, approve: approve),
      ),
    ),
  );
}

class _DecisionDialog extends StatefulWidget {
  _DecisionDialog({required this.doc, required this.approve});

  final _Doc doc;
  final bool approve;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _comment = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _comment.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      AppToast.show(
        context,
        widget.approve ? '승인 의견을 입력해주세요' : '반려 사유를 입력해주세요',
      );
      _focus.requestFocus();
      return;
    }
    Navigator.pop(context, comment);
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final doc = widget.doc;
    final empty = _comment.text.trim().isEmpty;

    return Container(
      width: 400,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(approve ? '결재 승인' : '결재 반려', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            approve ? '다음 결재자에게 넘어갑니다' : '반려하면 이 결재는 여기서 끝납니다',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
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
                Row(
                  children: [
                    Icon(
                      doc.kind.icon,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      doc.kind.label,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                    if (doc.amount > 0) ...[
                      Spacer(),
                      Text(
                        _won(doc.amount),
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  doc.title,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${doc.writer} 신청',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _Field(
            controller: _comment,
            focusNode: _focus,
            hint: approve ? '승인 의견을 적어주세요' : '반려 사유를 적어주세요',
            lines: 3,
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Pressable(
                onTap: () => Navigator.pop(context),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Text(
                  '취소',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Pressable(
                onTap: _submit,
                scale: 0.97,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: empty
                        ? AppColors.gray200
                        : (approve ? AppColors.primary : AppColors.error),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    approve ? '승인' : '반려',
                    style: AppTextStyles.body2.copyWith(
                      color: empty ? AppColors.gray500 : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 공통 조각 ──

/// 날짜 고르는 칸 — 입력칸([_Field])과 같은 면·높이로 맞춘다
class _DateField extends StatelessWidget {
  _DateField({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${value.year}. ${value.month}. ${value.day}.',
                style: AppTextStyles.body2,
              ),
            ),
            Icon(
              CupertinoIcons.calendar,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 폼 입력칸
class _Field extends StatelessWidget {
  _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.lines = 1,
    this.align = TextAlign.start,
    this.suffix,
    this.digitsOnly = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int lines;
  final TextAlign align;
  final String? suffix;

  /// 금액처럼 숫자만 받고 천 단위로 끊어 보여줄지
  final bool digitsOnly;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.body2,
              textAlign: align,
              cursorColor: AppColors.primary,
              minLines: lines,
              maxLines: lines,
              keyboardType: digitsOnly
                  ? TextInputType.number
                  : (lines > 1 ? TextInputType.multiline : null),
              inputFormatters: digitsOnly ? [_ThousandsFormatter()] : null,
              textInputAction: lines > 1
                  ? TextInputAction.newline
                  : TextInputAction.done,
              onSubmitted: (_) => onSubmitted?.call(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.body2.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (suffix != null) ...[
            SizedBox(width: 8),
            Text(
              suffix!,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 숫자만 받아 천 단위로 끊어 보여준다
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final text = _comma(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ── 데이터 ──

/// 결재 종류
///
/// 서버는 종류를 enum 이 아니라 **자유 문자열**로 받는다. [label] 을 그대로
/// 주고받으므로 라벨을 고치면 이미 올라간 결재가 '기타 품의'로 떨어진다.
enum _Kind {
  expense('지출결의', Icons.credit_card_rounded),
  purchase('구매 요청', Icons.shopping_cart_rounded),
  supply('비품 신청', Icons.inventory_2_rounded),
  trip('외근·출장', Icons.flight_rounded, needsWhen: true),
  shift('근무 변경', Icons.schedule_rounded, needsWhen: true),
  etc('기타 품의', Icons.description_rounded);

  const _Kind(this.label, this.icon, {this.needsWhen = false});

  final String label;
  final IconData icon;

  /// 언제·어디로 가는지를 받아야 하는 종류인가
  ///
  /// 지출결의·구매 요청에는 기간이 없다. 모든 종류에 칸을 세우면
  /// 안 쓰는 자리가 늘 비어 있게 된다.
  final bool needsWhen;

  static _Kind parse(String? value) =>
      _Kind.values.firstWhere((k) => k.label == value, orElse: () => _Kind.etc);
}

/// 처리 상태 (목록 탭 순서와 같다)
enum _State {
  pending('대기'),
  approved('승인'),
  rejected('반려'),

  /// 신청자가 스스로 물린 것 — 반려와 섞이면 안 돼서 따로 둔다
  withdrawn('회수');

  const _State(this.label);

  final String label;

  /// 목록 탭에 올리는 것 — 회수는 흔치 않아 탭을 늘리지 않고 '반려' 칸에 같이 둔다
  static const tabs = [_State.pending, _State.approved, _State.rejected];

  Color get color => switch (this) {
    _State.pending => AppColors.warning,
    _State.approved => AppColors.success,
    _State.rejected => AppColors.error,
    _State.withdrawn => AppColors.gray400,
  };

  static _State of(ApprovalStatus status) => switch (status) {
    ApprovalStatus.inProgress => _State.pending,
    ApprovalStatus.approved => _State.approved,
    ApprovalStatus.rejected => _State.rejected,
    ApprovalStatus.withdrawn => _State.withdrawn,
  };
}

/// 결재선 기본값 — 대표에게 올린다
///
/// 서버는 여러 명을 순서대로 세울 수 있지만 앱에는 아직 결재선을 짜는 자리가
/// 없다 (backend-gap.md 48번). 명단에 대표가 없으면 못 올린다.
Employee? get _defaultApprover {
  final people = StaffDirectory.instance.employees;
  for (final person in people) {
    if (person.role == Role.master) return person;
  }
  return null;
}

/// 폼이 돌려주는 것 — 아직 서버에 없어서 id·결재선이 없다
class _Draft {
  _Draft({
    required this.kind,
    required this.title,
    required this.amount,
    required this.body,
    this.startDate,
    this.endDate,
    this.place,
  });

  final _Kind kind;
  final String title;
  final int amount;
  final String body;

  /// 외근·출장, 근무 변경일 때만 채워진다
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;
}

/// 결재 문서 한 건
class _Doc {
  _Doc({
    required this.id,
    required this.kind,
    required this.title,
    required this.amount,
    required this.body,
    required this.writerId,
    required this.date,
    required this.state,
    required this.approverIds,
    required this.steps,
    this.currentApproverId,
    this.startDate,
    this.endDate,
    this.place,
  });

  final String id;
  final _Kind kind;
  final String title;
  final int amount;
  final String body;

  /// 외근·출장, 근무 변경에만 있다 (없으면 상세에서 그 줄을 안 그린다)
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;

  /// 신청자 uuid
  final String writerId;

  final DateTime date;

  /// 처리 상태 — 결재선을 다 돌면 바뀐다
  final _State state;

  final List<String> approverIds;
  final List<ApprovalStep> steps;
  final String? currentApproverId;

  String get writer => _nameOf(writerId);

  /// 마지막으로 처리한 사람이 남긴 의견
  ApprovalStep? get lastActed {
    ApprovalStep? last;
    for (final step in steps) {
      if (step.status == ApprovalStepStatus.pending) continue;
      last = step;
    }
    return last;
  }

  bool get myTurn =>
      state == _State.pending && currentApproverId == currentUser?.id;

  bool get canWithdraw =>
      state == _State.pending && writerId == currentUser?.id;
}

/// 받아 둔 결재. 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _docs = <_Doc>[];

bool _docsLoaded = false;

/// 서버는 '전체 결재'를 안 준다 — 내가 얽힌 세 함을 합쳐서 목록을 만든다
///
/// 그래서 이 목록은 '모든 결재'가 아니라 **내가 올렸거나 내가 결재하는 것**이다.
/// 남의 결재는 애초에 열람 권한이 없다 (서버 `_require_participant`).
Future<void> _loadDocs() async {
  final boxes = await Future.wait([
    for (final box in ApprovalBox.values) ApprovalApi.list(box),
  ]);
  // 함끼리 겹친다 — 내가 올리고 내가 결재하는 문서는 mine·inbox 둘 다에 있다
  final merged = <String, Approval>{};
  for (final rows in boxes) {
    for (final row in rows) {
      merged[row.id] = row;
    }
  }
  _docs
    ..clear()
    ..addAll([for (final row in merged.values) _fromServer(row)]);
  _docsLoaded = true;
}

_Doc _fromServer(Approval row) => _Doc(
  id: row.id,
  kind: _Kind.parse(row.kind),
  title: row.title,
  amount: row.amount ?? 0,
  body: row.content,
  writerId: row.requesterId,
  date: row.createdAt,
  state: _State.of(row.status),
  approverIds: row.approverIds,
  steps: row.steps,
  currentApproverId: row.currentApproverId,
  startDate: row.startDate,
  endDate: row.endDate,
  place: row.place,
);

/// 목록에서 바뀐 한 건만 갈아끼운다
void _replace(_Doc doc) {
  final index = _docs.indexWhere((d) => d.id == doc.id);
  if (index >= 0) _docs[index] = doc;
}

/// uuid → 이름. 명단에 없으면(퇴사자 등) '알 수 없음'
String _nameOf(String? id) {
  if (id == null) return '알 수 없음';
  final name = StaffDirectory.instance.byId(id)?.name;
  return name == null || name.isEmpty ? '알 수 없음' : name;
}

/// uuid → 직급 라벨. 이름 옆에 붙인다
String _rankOf(String? id) {
  if (id == null) return '';
  return StaffDirectory.instance.byId(id)?.rank.label ?? '';
}

/// 처리한 사람과 처리한 날 — '대표 · 8.3' 꼴
///
/// 회수는 결재선에 안 남으니 올린 사람을 쓴다
String _decidedBy(_Doc doc) {
  if (doc.state == _State.withdrawn) {
    return '${doc.writer} ${_rankOf(doc.writerId)}';
  }
  final step = doc.lastActed;
  if (step == null) return '';
  final who = '${_nameOf(step.approverId)} ${_rankOf(step.approverId)}'.trim();
  final when = step.actedAt;
  return when == null ? who : '$who · ${_date(when)}';
}

// ── 표시용 계산 ──

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';

/// 기간 한 줄 — 하루짜리면 날짜 하나만
String _period(DateTime start, DateTime? end) {
  final from = '${start.year}. ${start.month}. ${start.day}.';
  if (end == null ||
      (end.year == start.year &&
          end.month == start.month &&
          end.day == start.day)) {
    return from;
  }
  return '$from ~ ${end.year}. ${end.month}. ${end.day}.';
}

/// '1,240,000원' 형태
String _won(int amount) => '${_comma(amount)}원';

String _comma(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
