part of 'approval_screen.dart';

// ── 폰 화면 ──

/// 폰: 상태 탭 + 문서 목록. 누르면 상세가 옆에서 밀려 들어온다.
///
/// 데스크톱은 `320 목록 | 상세` 2단인데 폰 폭(375)에 두 칸을 넣을 수 없다.
/// 프로젝트 폰 화면과 같은 결로 **두 화면으로 나눈다**.
///
/// **폰에는 전자결재 탭이 없다** — 홈 왼쪽 위 바로가기로만 들어온다.
/// 그래서 목록도 뒤로가기가 있어야 해서 [PhoneDetailScaffold] 를 쓴다
/// (왼쪽 `<` · 가운데 제목 · 오른쪽 `+` — 알림 화면과 같은 머리 모양).
class _ApprovalPhone extends StatelessWidget {
  _ApprovalPhone({
    required this.docs,
    required this.filter,
    required this.onFilter,
    required this.onCreate,
    required this.onOpen,
  });

  final List<_Doc> docs;
  final _State filter;
  final ValueChanged<_State> onFilter;

  /// null 이면 올릴 수 없는 사람이라 `+` 를 안 그린다 (MASTER·ADMIN)
  final VoidCallback? onCreate;

  /// 상세를 열고 돌아온다 — 승인·반려로 바뀐 것이 목록에 반영돼야 한다
  final ValueChanged<_Doc> onOpen;

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '전자결재',
      actions: [
        if (onCreate case final create?)
          GlassIconButton(symbol: 'plus', onPressed: create),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          _StateTabs(selected: filter, onSelect: onFilter),
          SizedBox(height: 16),
          if (docs.isEmpty)
            EmptyCard(
              icon: CupertinoIcons.tray,
              text: '${filter.label} 결재가 없어요',
            )
          else
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _DocTile(
                doc: docs[i],
                selected: false,
                onTap: () => onOpen(docs[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 폰 결재 상세 — 밀려 들어오는 한 장
///
/// 본문은 데스크톱 우측 판([_DocDetail])을 그대로 쓴다. 그쪽이 이미 세로로
/// 쌓이는 목록이라 폭만 좁아지면 된다.
class _DocDetailScreen extends StatelessWidget {
  _DocDetailScreen({
    required this.doc,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
    required this.onComment,
  });

  final _Doc doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onWithdraw;
  final Future<void> Function(String) onComment;

  @override
  Widget build(BuildContext context) => PhoneDetailScaffold(
    title: '전자결재',
    child: _DocDetail(
      doc: doc,
      onApprove: onApprove,
      onReject: onReject,
      onWithdraw: onWithdraw,
      onComment: onComment,
    ),
  );
}
