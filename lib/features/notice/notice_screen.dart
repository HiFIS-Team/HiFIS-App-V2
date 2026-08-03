import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/notice_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/block_editor.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';

part 'notice_phone.dart';

/// 공지 화면
///
/// 데스크톱은 좌측 목록 + 우측 본문 2단 구조. 본문은 회의록과 같은
/// 블록 편집기로 적고, 평소에는 렌더링된 모습으로 읽는다.
/// 폰은 같은 내용을 목록 화면 + 본문 화면 두 장으로 나눠 보여준다.
/// 열어보면 서버에 읽음이 찍히고, 누가 확인했는지 아래에서 볼 수 있다.
///
/// 새 글은 '공지 작성'을 누르면 **빈 글로 시작**해서 편집을 마칠 때 올라간다.
/// 누를 때마다 올리면 쓰다 말고 나갈 때마다 서버에 빈 공지가 쌓인다.
class NoticeScreen extends StatefulWidget {
  NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  /// true면 안 읽은 공지만
  bool _unreadOnly = false;

  _Notice? _selected;

  /// 새로 쓴 공지는 바로 편집 모드로 연다
  bool _startEditing = false;

  /// 첫 진입에만 스피너를 돌린다 — 탭을 다시 열 때는 받아둔 목록을 바로 그린다
  bool _loading = !_noticesLoaded;

  @override
  void initState() {
    super.initState();
    // 홈에서 넘어오며 걸어둔 요청은 첫 빌드 전에 반영한다 (setState 필요 없음)
    _consumeRequest();
    requestedNotice.addListener(_onRequest);
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadNotices();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    requestedNotice.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    if (_consumeRequest()) setState(() {});
  }

  /// 대기 중인 요청이 있으면 선택에 반영한다.
  /// 비우면서 리스너가 한 번 더 돌지만 값이 null이라 바로 빠져나온다.
  bool _consumeRequest() {
    final brief = requestedNotice.value;
    if (brief == null) return false;
    requestedNotice.value = null;
    final notice = brief._notice;
    // 홈에서 열었으니 읽음 처리도 같이 한다
    _markRead(notice);
    _unreadOnly = false;
    _startEditing = false;
    _selected = notice;
    return true;
  }

  List<_Notice> get _visible {
    final list = _notices.where((n) => !_unreadOnly || !n.read).toList();
    // 고정 공지가 위, 그다음 최신순
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return list;
  }

  _Notice? _syncSelection(List<_Notice> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  /// 공지를 열면 읽은 것으로 표시한다
  void _open(_Notice notice) {
    setState(() {
      _selected = notice;
      _startEditing = false;
      _markRead(notice);
    });
  }

  /// 빈 글로 시작한다 — 서버에는 편집을 마칠 때 올린다
  void _create() {
    final notice = _Notice(
      title: '',
      body: '',
      author: me,
      date: DateTime.now(),
    );
    setState(() {
      _notices.add(notice);
      _unreadOnly = false;
      _selected = notice;
      _startEditing = true;
    });
  }

  /// 편집을 마쳤다 — 여기서 서버에 올리거나 고친다
  Future<void> _finishEditing(_Notice notice) async {
    setState(() => _startEditing = false);
    final isNew = notice.id == null;
    try {
      await _saveNotice(notice);
      if (!mounted) return;
      // 아무것도 안 적고 끝낸 새 글은 목록에 남기지 않는다
      if (notice.id == null) {
        setState(() {
          _notices.remove(notice);
          _selected = null;
        });
        return;
      }
      setState(() {});
      if (isNew) AppToast.show(context, '공지를 올렸어요');
    } catch (error) {
      if (!mounted) return;
      // 실패하면 적던 내용을 지키기 위해 편집 상태로 되돌린다
      setState(() => _startEditing = true);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete(_Notice notice) async {
    try {
      await _deleteNotice(notice);
      if (!mounted) return;
      setState(() => _selected = null);
      AppToast.show(context, '공지를 삭제했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: isDesktop ? null : AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final list = _visible;
    final unread = _notices.where((n) => !n.read).length;

    if (!isDesktop) {
      return _NoticePhone(
        notices: list,
        unreadOnly: _unreadOnly,
        unread: unread,
        onFilter: (v) => setState(() => _unreadOnly = v),
        onChanged: () => setState(() {}),
      );
    }

    final selected = _syncSelection(list);
    // 목록을 처음 그릴 때 자동으로 고른 공지도 읽음 처리한다
    if (selected != null && !selected.read) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _markRead(selected));
      });
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _NoticeList(
                notices: list,
                selected: selected,
                unreadOnly: _unreadOnly,
                unread: unread,
                onFilter: (v) => setState(() {
                  _unreadOnly = v;
                  _selected = null;
                }),
                onSelect: _open,
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyNotice(unreadOnly: _unreadOnly, onCreate: _create)
                : _NoticeView(
                    // 공지를 바꾸면 편집 상태를 새로 시작한다
                    key: ValueKey(selected),
                    notice: selected,
                    editing: _startEditing,
                    onChanged: () => setState(() {}),
                    onDelete: () => _delete(selected),
                    onToggleEdit: () => _startEditing
                        ? _finishEditing(selected)
                        : setState(() => _startEditing = true),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 목록 ──

class _NoticeList extends StatelessWidget {
  _NoticeList({
    required this.notices,
    required this.selected,
    required this.unreadOnly,
    required this.unread,
    required this.onFilter,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Notice> notices;
  final _Notice? selected;
  final bool unreadOnly;

  /// 안 읽은 공지 수 (필터 라벨에 쓴다)
  final int unread;
  final ValueChanged<bool> onFilter;
  final ValueChanged<_Notice> onSelect;
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
              Text('공지', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notices.length}',
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
                      '공지 작성',
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
          child: ModeSwitch(
            left: '전체',
            right: unread > 0 ? '안읽음 $unread' : '안읽음',
            value: unreadOnly,
            onChanged: onFilter,
          ),
        ),
        Expanded(
          child: notices.isEmpty
              // Expanded 안에서 카드가 세로로 늘어나지 않게 위에 붙인다
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: EmptyCard(
                      icon: Icons.campaign_rounded,
                      text: unreadOnly ? '안 읽은 공지가 없어요' : '올라온 공지가 없어요',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _NoticeTile(
                    notice: notices[i],
                    selected: notices[i] == selected,
                    onTap: () => onSelect(notices[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoticeTile extends StatefulWidget {
  _NoticeTile({
    required this.notice,
    required this.selected,
    required this.onTap,
  });

  final _Notice notice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final unread = !notice.read;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
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
                  if (notice.pinned) ...[
                    Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      notice.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (unread) ...[
                    SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 3),
              Text(
                notice.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Avatar(name: notice.author, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '${notice.author} · ${_date(notice.date)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  Text(
                    '${notice.readCount}명 확인',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
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

class _EmptyNotice extends StatelessWidget {
  _EmptyNotice({required this.unreadOnly, required this.onCreate});

  final bool unreadOnly;
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
                Icons.campaign_rounded,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('공지', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            unreadOnly ? '안 읽은 공지가 없어요' : '지점에 알릴 내용을 적어보세요',
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
                '공지 작성',
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

// ── 우측 본문 ──

class _NoticeView extends StatefulWidget {
  _NoticeView({
    super.key,
    required this.notice,
    required this.editing,
    required this.onChanged,
    required this.onDelete,
    required this.onToggleEdit,
    this.phone = false,
  });

  final _Notice notice;

  /// 편집 상태 — 편집/완료 버튼을 어디에 두든 화면 쪽이 들고 있다
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleEdit;

  /// 폰은 편집·삭제를 헤더 글래스 버튼으로 올려서 본문에는 그리지 않는다
  final bool phone;

  @override
  State<_NoticeView> createState() => _NoticeViewState();
}

class _NoticeViewState extends State<_NoticeView> {
  late final _title = TextEditingController(text: widget.notice.title);
  final _titleFocus = FocusNode();

  bool get _editing => widget.editing;
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_editing) _titleFocus.requestFocus();
  }

  @override
  void didUpdateWidget(_NoticeView old) {
    super.didUpdateWidget(old);
    // 헤더 버튼으로 편집을 켰을 때도 제목부터 입력할 수 있게 한다
    if (_editing && !old.editing) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _sync() {
    widget.notice.title = _title.text.trim();
    widget.onChanged();
  }

  void _toggleEdit() {
    if (_editing) _sync();
    widget.onToggleEdit();
  }

  /// 본문의 체크박스를 눌렀을 때 그 줄만 바꿔 쓴다
  void _toggleCheckbox(int line, bool checked) {
    final lines = widget.notice.body.split('\n');
    if (line >= lines.length) return;
    lines[line] = checked
        ? lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[x]')
        : lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[ ]');
    widget.notice.body = lines.join('\n');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final phone = widget.phone;

    final title = _editing
        ? TextField(
            controller: _title,
            focusNode: _titleFocus,
            style: AppTextStyles.title1,
            cursorColor: AppColors.primary,
            onChanged: (_) => _sync(),
            decoration: InputDecoration(
              hintText: '제목 없는 공지',
              hintStyle: AppTextStyles.title1.copyWith(
                color: AppColors.gray300,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          )
        : Text(notice.displayTitle, style: AppTextStyles.title1);

    final pin = notice.pinned && !_editing
        ? Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(
              Icons.push_pin_rounded,
              size: 20,
              color: AppColors.error,
            ),
          )
        : null;

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_canEdit(notice))
          // 권한이 없으면 버튼을 감추되, 왜 없는지는 알려 준다
          Text(
            '관리자·점장만 고칠 수 있어요',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
          ),
        if (_editing) ...[
          Pressable(
            onTap: widget.onDelete,
            scale: 0.95,
            pressedColor: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '삭제',
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 6),
        ],
        if (_canEdit(notice))
          Pressable(
            onTap: _toggleEdit,
            scale: 0.95,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                color: _editing ? AppColors.primary : AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _editing ? Icons.check_rounded : Icons.edit_rounded,
                    size: 15,
                    color: _editing ? Colors.white : AppColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _editing ? '완료' : '편집',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 14,
                      color: _editing ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return ListView(
      padding: phone
          // 폰 본문은 헤더 뒤로 스크롤되고, 하단바가 없어 화면 아래 여백만 남긴다
          ? EdgeInsets.fromLTRB(
              20,
              PhoneDetailScaffold.topPadding,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            )
          : EdgeInsets.fromLTRB(32, 64, 32, bottomBarInset(context)),
      children: [
        // 폰은 편집·삭제가 헤더 글래스 버튼으로 올라가 제목만 남는다
        if (phone)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?pin,
              Expanded(child: title),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?pin,
              Expanded(child: title),
              SizedBox(width: 16),
              actions,
            ],
          ),
        SizedBox(height: 10),
        if (_editing) ...[
          Row(
            children: [
              // 중요 공지는 목록 맨 위에 고정된다
              Pressable(
                onTap: () {
                  setState(() => notice.pinned = !notice.pinned);
                  widget.onChanged();
                },
                scale: 0.96,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: notice.pinned
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: notice.pinned
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        '상단 고정',
                        style: AppTextStyles.body2.copyWith(
                          fontSize: 14,
                          color: notice.pinned
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6),
              // 마크다운 문법 도움말 (펼침)
              Pressable(
                onTap: () => setState(() => _help = !_help),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '마크다운 문법',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      _help
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_help) ...[SizedBox(height: 10), MarkdownHelpPanel()],
        ] else
          Row(
            children: [
              Avatar(name: notice.author, size: 24),
              SizedBox(width: 8),
              Text(
                '${notice.author} ${staffOf(notice.author).role} · ${_date(notice.date)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        SizedBox(height: 14),
        Container(height: 1, color: AppColors.gray100),
        SizedBox(height: 14),
        if (_editing)
          BlockEditor(
            source: notice.body,
            onChanged: (markdown) {
              notice.body = markdown;
              widget.onChanged();
            },
          )
        else ...[
          if (notice.body.trim().isEmpty)
            Text(
              '아직 내용이 없어요. 편집을 눌러 적어보세요',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          else
            MarkdownView(source: notice.body, onCheckbox: _toggleCheckbox),
          SizedBox(height: 24),
          _ReadCard(notice: notice),
        ],
      ],
    );
  }
}

/// 읽음 현황 — 누가 확인했고 누가 안 봤는지
class _ReadCard extends StatelessWidget {
  _ReadCard({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: FutureBuilder<NoticeReaders>(
        // 본문을 볼 때만 따로 받는다 — 목록에는 인원수(readCount)만 있으면 된다
        future: _readersOf(notice),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final people = data?.people ?? const <NoticeReader>[];
          final total = data?.total ?? 0;
          final readCount = data?.readCount ?? notice.readCount;
          final allRead = data != null && readCount >= total && total > 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('확인 현황', style: AppTextStyles.label),
                  SizedBox(width: 6),
                  Text(
                    data == null ? '$readCount' : '$readCount/$total',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Spacer(),
                  if (allRead)
                    Text(
                      '모두 확인했어요',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (people.isNotEmpty) ...[
                SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // 서버가 읽은 사람을 앞에 놓아 준다
                    for (final person in people)
                      _ReaderChip(name: person.name, read: person.read),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 확인 현황 — 같은 공지를 다시 열 때 또 받지 않도록 들고 있는다
final _readersCache = <String, Future<NoticeReaders>>{};

Future<NoticeReaders> _readersOf(_Notice notice) {
  final id = notice.id;
  if (id == null) {
    return Future.value(
      NoticeReaders(total: 0, readCount: 0, people: const []),
    );
  }
  return _readersCache[id] ??= NoticeApi.readers(id);
}

/// 확인 여부 알약 — 안 본 사람은 흐리게
class _ReaderChip extends StatelessWidget {
  _ReaderChip({required this.name, required this.read});

  final String name;
  final bool read;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: read ? AppColors.gray50 : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: read ? Colors.transparent : AppColors.gray200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: read ? 1 : 0.4,
            child: Avatar(name: name, size: 22),
          ),
          SizedBox(width: 6),
          Text(
            name == me ? '나' : name,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: read ? AppColors.textPrimary : AppColors.gray400,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (read) ...[
            SizedBox(width: 4),
            Icon(Icons.check_rounded, size: 13, color: AppColors.success),
          ],
        ],
      ),
    );
  }
}

// ── 데이터 (목업) ──

/// 공지 한 건 — 본문은 마크다운 원문 그대로 담는다
class _Notice {
  _Notice({
    required this.title,
    required this.body,
    required this.author,
    required this.date,
    this.id,
    this.authorId,
    this.pinned = false,
    this.read = false,
    this.readCount = 0,
  });

  /// 서버가 준 uuid — **null 이면 아직 안 올린 새 글이다.**
  /// '공지 작성'을 누르면 빈 글로 시작해서, 편집을 마칠 때 서버에 올린다.
  String? id;

  /// 작성자 uuid — 수정·삭제 권한이 이 값으로 갈린다 ([_canEdit])
  String? authorId;

  String title;
  String body;
  final String author;
  final DateTime date;

  /// 상단 고정 (중요 공지)
  bool pinned;

  /// 내가 열어 봤는지 (서버 `readByMe`)
  bool read;

  /// 확인한 사람 수 (서버 `readCount`).
  /// 전체 인원과 사람별 목록은 `/notices/{id}/readers` 로 따로 받는다.
  int readCount;

  String get displayTitle => title.isEmpty ? '제목 없는 공지' : title;

  /// 목록에 보여줄 첫 줄 (마크다운 기호는 떼고)
  String get preview {
    for (final line in body.split('\n')) {
      final text = line
          .replaceAll(RegExp(r'^(#{1,3} |[-*] \[[ xX]\] |[-*] |> |\d+\. )'), '')
          .replaceAll(RegExp(r'[*`~]'), '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '내용 없음';
  }
}

/// 올라온 공지 — 서버에서 받아 온다.
/// 탭을 오가도 다시 받지 않도록 모듈 전역으로 둔다.
final _notices = <_Notice>[];

/// 한 번이라도 받아왔는지 — 탭을 다시 열 때 빈 목록을 깜빡이지 않게 한다
bool _noticesLoaded = false;

Future<void> _loadNotices() async {
  final rows = await NoticeApi.list();
  _notices
    ..clear()
    ..addAll([for (final row in rows) _fromServer(row)]);
  _noticesLoaded = true;
}

/// 서버 공지 → 화면 모델
///
/// 서버는 작성자를 uuid 로 주는데 화면은 이름으로 아바타·직급을 찾는다.
/// 명단에 없으면(퇴사자 등) uuid 대신 빈 이름을 두어 아바타만 회색으로 뜬다.
_Notice _fromServer(Notice row) {
  final author = StaffDirectory.instance.byId(row.authorId);
  return _Notice(
    id: row.id,
    authorId: row.authorId,
    title: row.title,
    body: row.body,
    author: author?.name ?? '',
    date: row.createdAt,
    pinned: row.pinned,
    read: row.readByMe,
    readCount: row.readCount,
  );
}

/// 편집을 마쳤을 때 — 새 글이면 올리고, 있던 글이면 고친다
///
/// 제목·본문이 모두 비었으면 아무것도 안 한다. 빈 글로 시작하는 구조라
/// 작성을 눌렀다가 그냥 나가는 일이 흔한데, 그때마다 서버에 빈 공지가 쌓인다.
Future<void> _saveNotice(_Notice notice) async {
  if (notice.title.trim().isEmpty && notice.body.trim().isEmpty) return;

  final id = notice.id;
  if (id == null) {
    final created = await NoticeApi.create(
      title: notice.title,
      body: notice.body,
      pinned: notice.pinned,
    );
    notice.id = created.id;
    notice.authorId = created.authorId;
    // 내가 쓴 글은 이미 본 것이다 — 서버도 작성자를 읽음으로 잡아 준다
    notice.read = created.readByMe;
    notice.readCount = created.readCount;
    return;
  }

  await NoticeApi.update(
    id,
    title: notice.title,
    body: notice.body,
    pinned: notice.pinned,
  );
}

/// 지우기 — 아직 안 올린 새 글은 서버를 부르지 않는다
Future<void> _deleteNotice(_Notice notice) async {
  final id = notice.id;
  if (id != null) await NoticeApi.delete(id);
  _notices.remove(notice);
  _readersCache.remove(id);
}

/// 열어 봤다고 찍는다
///
/// 화면을 먼저 바꾸고 서버에 알린다. 실패해도 되돌리지 않는다 — 읽음은
/// 다시 열면 또 찍히는 값이라, 여기서 에러를 띄우면 성가시기만 하다.
void _markRead(_Notice notice) {
  final id = notice.id;
  if (id == null || notice.read) return;
  notice.read = true;
  notice.readCount++;
  // 확인 현황에 내가 더해졌으니 받아 둔 목록은 버린다
  _readersCache.remove(id);
  NoticeApi.markRead(id).catchError((_) {});
}

/// 이 공지를 고치거나 지울 수 있는가
///
/// 서버 기준과 같다 — **작성자 본인 또는 관리자·점장·대표**.
/// 남이 쓴 글을 일반 직원이 건드리면 403 이라 버튼을 감춘다.
///
/// 아직 안 올린 새 글([_Notice.id]가 null)도 열어 둔다. 작성은 누구나 되는데
/// 여기서 막으면 쓰다 말고 저장도 못 하는 상태가 된다.
bool _canEdit(_Notice notice) =>
    notice.id == null || notice.authorId == currentUser?.id || myRole.strong;

// ── 표시용 계산 ──

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';

// ── 홈 카드 연결 ──

/// 홈 카드에서 열어달라고 요청한 공지
///
/// 폰은 홈에서 바로 본문을 밀어 올리지만, 데스크톱은 2단 구조라
/// 공지 화면으로 옮긴 뒤 이걸 보고 선택을 맞춘다.
final requestedNotice = ValueNotifier<NoticeBrief?>(null);

/// 홈 카드에 내보내는 공지 요약
///
/// 내부 모델(`_Notice`)은 이 라이브러리 밖으로 나가지 않는다.
class NoticeBrief {
  NoticeBrief._(this._notice);

  final _Notice _notice;

  String get title => _notice.displayTitle;
  String get author => _notice.author;
  bool get pinned => _notice.pinned;
  bool get unread => !_notice.read;

  /// '오늘' · '어제' · '3일 전' · '7.12'
  String get time {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(
          DateTime(_notice.date.year, _notice.date.month, _notice.date.day),
        )
        .inDays;
    if (days <= 0) return '오늘';
    if (days == 1) return '어제';
    if (days < 7) return '$days일 전';
    return _date(_notice.date);
  }

  /// 폰: 읽음 처리하고 본문을 옆에서 밀어 연다
  Future<void> open(BuildContext context) {
    _markRead(_notice);
    return Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _NoticePage(notice: _notice, editing: false),
      ),
    );
  }
}

/// 홈 카드용 — 고정 공지가 위, 그다음 최신순으로 [count]개까지
List<NoticeBrief> noticeBriefs(int count) {
  final list = [..._notices]
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.date.compareTo(a.date);
    });
  return list.take(count).map(NoticeBrief._).toList();
}

/// 올라온 공지 수 (홈 카드 머리말)
int get noticeCount => _notices.length;
