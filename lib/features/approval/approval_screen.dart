import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';

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

class _ApprovalScreenState extends State<ApprovalScreen> {
  _State _filter = _State.pending;
  _Doc? _selected;

  List<_Doc> get _visible {
    final list = _docs.where((d) => d.state == _filter).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  _Doc? _syncSelection(List<_Doc> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  Future<void> _create() async {
    final created = await _showComposer(context);
    if (created == null || !mounted) return;
    setState(() {
      _docs.add(created);
      _filter = _State.pending;
      _selected = created;
    });
    AppToast.show(context, '결재를 올렸어요');
  }

  /// 승인·반려 모두 의견을 남겨야 처리된다
  Future<void> _decide(_Doc doc, {required bool approve}) async {
    if (doc.state != _State.pending) return;
    final comment = await _showDecisionDialog(
      context,
      doc: doc,
      approve: approve,
    );
    if (comment == null) return;

    setState(() {
      doc
        ..state = approve ? _State.approved : _State.rejected
        ..comment = comment
        ..decidedAt = DateTime.now();
    });
    if (!mounted) return;
    AppToast.show(context, approve ? '결재를 승인했어요' : '결재를 반려했어요');
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '✅', title: '전자결재');

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
                  _selected = null;
                }),
                onSelect: (doc) => setState(() => _selected = doc),
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyDetail(filter: _filter, onCreate: _create)
                : _DocDetail(
                    key: ValueKey(selected),
                    doc: selected,
                    onApprove: () => _decide(selected, approve: true),
                    onReject: () => _decide(selected, approve: false),
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
  final VoidCallback onCreate;

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
              Pressable(
                onTap: onCreate,
                scale: 0.94,
                pressedColor: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
                padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
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
          for (final state in _State.values)
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
  final VoidCallback onCreate;

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
          SizedBox(height: 24),
          Pressable(
            onTap: onCreate,
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
  });

  final _Doc doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
              '${doc.writer} ${staffOf(doc.writer).role} · ${_date(doc.date)} 신청',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        SizedBox(height: 20),
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
                  doc.state == _State.approved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
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
                            doc.state == _State.approved ? '승인됨' : '반려됨',
                            style: AppTextStyles.body2.copyWith(
                              color: doc.state.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '$_admin ${staffOf(_admin).role}'
                            '${doc.decidedAt == null ? '' : ' · ${_date(doc.decidedAt!)}'}',
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      if (doc.comment.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          doc.comment,
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
        if (doc.state == _State.pending) ...[
          SizedBox(height: 18),
          // 안내는 왼쪽, 버튼은 오른쪽에 작게
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_admin ${staffOf(_admin).role} 결재 대기 · 의견을 남겨야 처리돼요',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(width: 12),
              Pressable(
                onTap: onReject,
                scale: 0.96,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Text(
                    '반려',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Pressable(
                onTap: onApprove,
                scale: 0.96,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '승인',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
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

Future<_Doc?> _showComposer(BuildContext context) {
  return showDialog<_Doc>(
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
  final _titleFocus = FocusNode();

  _Kind _kind = _Kind.expense;

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
    _titleFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '결재 제목을 입력해주세요');
      _titleFocus.requestFocus();
      return;
    }
    Navigator.pop(
      context,
      _Doc(
        kind: _kind,
        title: title,
        amount: int.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
        body: _body.text.trim(),
        writer: me,
        date: DateTime.now(),
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
                    SizedBox(height: 14),
                    Text('내용', style: AppTextStyles.label),
                    SizedBox(height: 8),
                    _Field(
                      controller: _body,
                      hint: '사유·근거·견적 등 결재에 필요한 내용을 적어주세요',
                      lines: 4,
                    ),
                    SizedBox(height: 14),
                    // 결재는 최고관리자 한 사람이 처리한다
                    Row(
                      children: [
                        Text('결재자', style: AppTextStyles.label),
                        SizedBox(width: 10),
                        Avatar(name: _admin, size: 24),
                        SizedBox(width: 6),
                        Text(
                          '$_admin ${staffOf(_admin).role}',
                          style: AppTextStyles.body2.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

// ── 데이터 (목업) ──

/// 결재 종류
enum _Kind {
  expense('지출결의', Icons.credit_card_rounded),
  purchase('구매 요청', Icons.shopping_cart_rounded),
  supply('비품 신청', Icons.inventory_2_rounded),
  trip('외근·출장', Icons.flight_rounded),
  shift('근무 변경', Icons.schedule_rounded),
  etc('기타 품의', Icons.description_rounded);

  const _Kind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 처리 상태 (목록 탭 순서와 같다)
enum _State {
  pending('대기'),
  approved('승인'),
  rejected('반려');

  const _State(this.label);

  final String label;

  Color get color => switch (this) {
    _State.pending => AppColors.warning,
    _State.approved => AppColors.success,
    _State.rejected => AppColors.error,
  };
}

/// 결재는 최고관리자(대표)가 처리한다
///
/// 서버 명단에는 대표 직급이 없을 수도 있어서 못 찾으면 첫 사람으로 떨어진다.
/// (상수로 두면 명단을 받아오기 전 값에 굳어 버리므로 getter 다.)
String get _admin {
  final staff = staffList;
  if (staff.isEmpty) return me;
  return staff
      .firstWhere((s) => s.role == '대표', orElse: () => staff.first)
      .name;
}

/// 결재 문서 한 건
class _Doc {
  _Doc({
    required this.kind,
    required this.title,
    required this.amount,
    required this.body,
    required this.writer,
    required this.date,
    this.state = _State.pending,
    this.comment = '',
    this.decidedAt,
  });

  final _Kind kind;
  final String title;
  final int amount;
  final String body;
  final String writer;
  final DateTime date;

  /// 처리 상태 — 최고관리자가 승인·반려하면 바뀐다
  _State state;

  /// 처리하며 남긴 의견
  String comment;
  DateTime? decidedAt;
}

/// 올라온 결재 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _docs = <_Doc>[..._seed()];

List<_Doc> _seed() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  return [
    _Doc(
      kind: _Kind.purchase,
      title: 'PT룸 소도구 구매',
      amount: 1240000,
      body: '노후된 케틀벨·밴드 교체가 필요합니다.\n견적 3곳 비교 후 최저가 업체로 진행하려 합니다.',
      writer: '박준현',
      date: day(0),
    ),
    _Doc(
      kind: _Kind.supply,
      title: '수건·세제 정기 발주',
      amount: 380000,
      body: '월 정기 발주 건입니다. 수량은 지난달과 동일합니다.',
      writer: me,
      date: day(-1),
    ),
    _Doc(
      kind: _Kind.trip,
      title: '피트니스 박람회 참관',
      amount: 0,
      body: '8월 12일 코엑스 박람회 참관 요청드립니다.\n신규 기구 도입 검토를 위한 사전 조사 목적입니다.',
      writer: '유찬빈',
      date: day(-2),
    ),
    _Doc(
      kind: _Kind.expense,
      title: '7월 회식비 지출',
      amount: 460000,
      body: '7월 팀 회식 지출 건입니다. 영수증 첨부 예정입니다.',
      writer: '민중기',
      date: day(-5),
      state: _State.approved,
      comment: '고생 많았습니다. 승인합니다',
      decidedAt: day(-4),
    ),
    _Doc(
      kind: _Kind.shift,
      title: '8월 첫째 주 근무 변경',
      amount: 0,
      body: '개인 사정으로 8월 4일 오전 근무를 오후로 변경하고자 합니다.',
      writer: '전상현',
      date: day(-6),
      state: _State.rejected,
      comment: '해당 날짜는 인원이 부족합니다. 다른 날로 조정 부탁드려요',
      decidedAt: day(-5),
    ),
  ];
}

// ── 표시용 계산 ──

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';

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
