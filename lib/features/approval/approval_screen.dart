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
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/placeholder_screen.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/util/when.dart';
part 'approval_list.dart';
part 'approval_detail.dart';
part 'approval_comments.dart';
part 'approval_composer.dart';
part 'approval_decide.dart';
part 'approval_fields.dart';
part 'approval_data.dart';

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
      AppToast.show(context, approve ? '승인했어요' : '반려했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 댓글 — 처리 전에 되묻는 자리다 (승인·반려 의견과 다르다)
  ///
  /// 서버가 문서를 통째로 돌려줘서 그대로 갈아끼운다.
  Future<void> _comment(_Doc doc, String body) async {
    try {
      final saved = await ApprovalApi.comment(doc.id, body: body);
      if (!mounted) return;
      setState(() => _replace(_fromServer(saved)));
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
                    onComment: (body) => _comment(selected, body),
                  ),
          ),
        ],
      ),
    );
  }
}
