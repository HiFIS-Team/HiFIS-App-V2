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
    this.onRetry,
  });

  final List<_Doc> docs;
  final _State filter;
  final ValueChanged<_State> onFilter;

  /// 못 받았다 — 넘어오면 빈 카드 대신 **다시 시도**를 낸다 (2026-08-21).
  /// null 이면 그냥 비어 있는 것이다
  final VoidCallback? onRetry;

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
            // 못 받은 것과 없는 것을 가른다 — 다른 화면과 같은 규칙이다
            if (onRetry case final retry?)
              FailedCard(onRetry: retry)
            else
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

/// 폰 결재 상세 — 밀려 들어오는 한 장 (프로젝트 상세와 같은 틀)
///
/// 본문은 데스크톱 우측 판([_DocDetail])을 그대로 쓴다. 그쪽이 이미 세로로
/// 쌓이는 목록이라 폭만 좁아지면 된다.
///
/// **넘겨받은 문서를 그대로 들고 있지 않는다.** 승인·반려·댓글은 서버가
/// 돌려준 문서로 목록을 갈아끼우므로([_replace]), 처음 넘어온 객체는 곧
/// 옛것이 된다. 매번 [_docs] 에서 같은 id 를 찾아 쓴다.
class _DocDetailScreen extends StatefulWidget {
  _DocDetailScreen({
    required this.doc,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
    required this.onComment,
  });

  /// 열 때의 문서 — id 를 얻고, 목록에서 못 찾을 때의 대비책으로도 쓴다
  final _Doc doc;

  final Future<void> Function(_Doc) onApprove;
  final Future<void> Function(_Doc) onReject;
  final Future<void> Function(_Doc) onWithdraw;
  final Future<void> Function(_Doc, String) onComment;

  @override
  State<_DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends State<_DocDetailScreen> {
  _Doc get _doc {
    for (final doc in _docs) {
      if (doc.id == widget.doc.id) return doc;
    }
    return widget.doc;
  }

  /// 처리하고 이 화면을 다시 그린다 — 안 그리면 승인해도 '대기'로 남는다
  Future<void> _run(Future<void> Function(_Doc) action) async {
    await action(_doc);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => PhoneDetailScaffold(
    title: '전자결재',
    child: _DocDetail(
      doc: _doc,
      onApprove: () => _run(widget.onApprove),
      onReject: () => _run(widget.onReject),
      onWithdraw: () => _run(widget.onWithdraw),
      onComment: (body) => _run((doc) => widget.onComment(doc, body)),
    ),
  );
}

/// 받아오는 동안의 뼈대 — 상태 탭과 결재 카드 자리를 잡아 둔다
class _ApprovalSkeleton extends StatelessWidget {
  _ApprovalSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: PhoneDetailScaffold(
      title: '전자결재',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          // _StateTabs 와 같은 높이(44)
          Skeleton(height: 44, radius: 14),
          SizedBox(height: 16),
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(height: 12),
            SkeletonCard(
              children: [
                Row(
                  children: [
                    Skeleton(width: 52, height: 20, radius: 10),
                    SizedBox(width: 8),
                    Skeleton(width: 120, height: 14),
                    Spacer(),
                    Skeleton(width: 40, height: 11),
                  ],
                ),
                SizedBox(height: 12),
                Skeleton(width: 200, height: 11),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonCircle(size: 22),
                    SizedBox(width: 8),
                    Skeleton(width: 96, height: 11),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
