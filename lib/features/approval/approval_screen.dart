import 'package:flutter/cupertino.dart';
import '../../core/data/data_signal.dart';
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
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/failed_card.dart';
import '../../core/widgets/feedback/empty_state.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_input_bar.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/util/screen_refresh.dart';
import '../../core/util/skeleton_delay.dart';
part 'approval_list.dart';
part 'approval_detail.dart';
part 'approval_phone.dart';
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

class _ApprovalScreenState extends State<ApprovalScreen>
    with ScreenRefresh<ApprovalScreen>, SkeletonDelay<ApprovalScreen> {
  _State _filter = _State.pending;

  /// 고른 문서 — 목록이 갈릴 때마다 새 객체가 오므로 id 로 들고 있는다
  String? _selectedId;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  /// 대기·승인·반려 세 목록이 다 바뀐다
  @override
  List<ValueNotifier<int>> get watchSignals => [approvalChanged];

  @override
  void initState() {
    super.initState();
    // 받아 둔 목록이 있으면 뼈대 없이 시작한다 (다시 열 때 안 깜빡인다)
    if (_docsLoaded) skipFirstSkeleton();
    _load();
  }

  /// 못 받았다 — **목록이 비어 있을 때만** 실패 카드를 낸다 (2026-08-21)
  ///
  /// 안 두면 못 받은 것이 `대기 결재가 없어요` 로 떨어져서 **없는 것처럼
  /// 보인다.** 랭킹이 같은 자리에서 걸렸다 — 공지·알림·프로젝트·조직도는
  /// 다 실패 카드를 낸다.
  bool _failed = false;

  Future<void> _load() async {
    try {
      await _loadDocs();
      _failed = false;
    } catch (error) {
      _failed = true;
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  /// 다시 시도 — **여기서는 뼈대를 바로 띄운다** (claude.md 의 `_retry()` 예외)
  void _retry() {
    setState(beginLoad);
    _load();
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

  /// 폰에서 상세를 열고 돌아온다 — 승인·반려로 바뀐 것이 목록에 반영돼야 한다
  ///
  /// **문서를 통째로 넘기지 않는다.** 승인·댓글은 서버가 돌려준 문서로
  /// `_docs` 를 갈아끼우는데([_replace]), 넘긴 객체는 그때 옛것이 된다 —
  /// 상세가 그걸 들고 있으면 승인해도 '대기'로 남고 댓글도 안 붙는다.
  /// 상세가 id 로 지금 문서를 찾아 쓰게 하고, 여기서는 처리만 해 준다.
  Future<void> _openDoc(_Doc doc) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _DocDetailScreen(
          doc: doc,
          onApprove: (d) => _decide(d, approve: true),
          onReject: (d) => _decide(d, approve: false),
          onWithdraw: _withdraw,
          onComment: _comment,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) {
      return isDesktop ? SkeletonTwoPane(rows: 6) : _ApprovalSkeleton();
    }

    final list = _visible;

    if (!isDesktop) {
      return _ApprovalPhone(
        docs: list,
        filter: _filter,
        onFilter: (v) => setState(() => _filter = v),
        onCreate: _canWrite ? _create : null,
        onOpen: _openDoc,
        // 받아 둔 것이 있으면 그대로 보여준다 — 실패 카드는 빌 때만
        onRetry: _failed && _docs.isEmpty ? _retry : null,
      );
    }

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
                onRetry: _failed && _docs.isEmpty ? _retry : null,
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
