import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';

/// 사내톡 화면 (인스타그램 DM 스타일 목업)
///
/// 데이터는 하드코딩된 샘플이며, 기능 개발 시 실제 대화 데이터로 교체한다.
class MessageScreen extends StatefulWidget {
  MessageScreen({
    super.key,
    this.embedded = false,
    this.onExpand,
    this.onOpenChat,
    this.onNewMessage,
  });

  /// 데스크톱 플로팅 패널에 담길 때 true.
  /// 뒤로가기 버튼을 숨긴다 (닫기는 패널 밖 X 버튼이 담당).
  final bool embedded;

  /// 데스크톱 전체보기로 전환하는 버튼 콜백 (null이면 버튼을 숨긴다)
  final VoidCallback? onExpand;

  /// 대화를 눌렀을 때 화면 전환 대신 호출할 콜백
  /// (데스크톱 전체보기에서 오른쪽 영역에 채팅방을 띄우는 용도)
  final void Function(String name, Color color, String? emoji)? onOpenChat;

  /// 새 채팅(연필) 버튼을 눌렀을 때 화면 전환 대신 호출할 콜백
  ///
  /// 이 화면이 **다른 내비게이터 옆에 놓이는** 데스크톱 전체보기에서 필요하다.
  /// 거기서는 `Navigator.of(context)` 가 오른쪽 pane 이 아니라 전체보기를 띄운
  /// 바깥쪽을 가리켜서, 같은 화면의 '메시지 보내기' 버튼과 다른 데로 열렸다.
  final VoidCallback? onNewMessage;

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 큰 타이틀이 스크롤로 사라지는 정도.
  final _collapse = ScrollCollapse();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _scrollController.dispose();
    _collapse.dispose();
    super.dispose();
  }

  /// 새 채팅 — 호스트가 자리를 정해 줬으면 거기에, 아니면 이 화면 위로 띄운다
  void _newMessage() {
    final open = widget.onNewMessage;
    if (open != null) return open();

    Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewMessageScreen(),
      ),
    );
  }

  /// 안 읽은 대화만 볼지 — 헤더 필터 메뉴에서 켠다
  bool _unreadOnly = false;

  /// 필터 버튼 위치를 알아야 메뉴를 그 아래에 띄울 수 있다
  final _filterKey = GlobalKey();

  /// 헤더 필터 메뉴 — 아이폰 메시지의 그 메뉴와 같은 구성
  Future<void> _openFilterMenu() async {
    final button = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final picked = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gray100),
      ),
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + button.size.height + 6,
        overlay.size.width - origin.dx - button.size.width,
        0,
      ),
      items: [
        _menuItem('deleted', CupertinoIcons.trash, '최근 삭제된 항목'),
        _menuItem('left', CupertinoIcons.arrow_turn_up_left, '최근 나간 항목'),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(
            '필터 기준',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
        _menuItem(
          'unread',
          CupertinoIcons.chat_bubble,
          '읽지 않음',
          checked: _unreadOnly,
        ),
      ],
    );
    if (!mounted) return;

    switch (picked) {
      case 'unread':
        setState(() => _unreadOnly = !_unreadOnly);
      case 'deleted':
        _openArchive('최근 삭제된 항목', '최근 삭제한 대화가 없어요');
      case 'left':
        _openArchive('최근 나간 항목', '최근 나간 대화방이 없어요');
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool checked = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.body2)),
          if (checked)
            Icon(CupertinoIcons.checkmark, size: 15, color: AppColors.primary),
        ],
      ),
    );
  }

  /// 삭제·나간 대화 보관함
  ///
  /// 서버에 붙기 전이라 담을 게 없다. 화면 틀만 두고 비어 있음을 알린다.
  void _openArchive(String title, String emptyText) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _ArchiveScreen(title: title, emptyText: emptyText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _unreadOnly
        ? [
            for (final c in _conversations)
              if (c.unread) c,
          ]
        : _conversations;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(0, 68, 0, 100),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('받은 메시지', style: AppTextStyles.title3),
                      ),
                      Text(
                        '요청',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                if (shown.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 40, 20, 40),
                    child: Center(
                      child: Text(
                        '안 읽은 대화가 없어요',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  for (final conversation in shown)
                    _ConversationTile(
                      onOpen: widget.onOpenChat,
                      name: conversation.name,
                      preview: conversation.preview,
                      time: conversation.time,
                      color: conversation.color,
                      emoji: conversation.emoji,
                      online: conversation.online,
                      unread: conversation.unread,
                    ),
              ],
            ),
          ),
          // 스크롤 시 상단 프로그레시브 블러 — 콘텐츠가 헤더 뒤로 흐려진다
          TopFrost(collapse: _collapse, color: AppColors.surface),
          // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: Text('사내톡', style: AppTextStyles.title3)),
              ),
            ),
          ),
          // 좌측 상단 뒤로가기 / 우측 상단 새 메시지 (글래스 버튼 고정)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                children: [
                  if (widget.onExpand != null)
                    // 데스크톱 패널 → 전체보기 전환
                    GlassIconButton(
                      symbol: 'arrow.up.left.and.arrow.down.right',
                      onPressed: widget.onExpand,
                    )
                  else if (!widget.embedded)
                    GlassIconButton(
                      symbol: 'chevron.backward',
                      onPressed: () => Navigator.pop(context),
                    ),
                  Spacer(),
                  GlassIconButton(
                    key: _filterKey,
                    symbol: 'line.3.horizontal.decrease',
                    onPressed: _openFilterMenu,
                  ),
                ],
              ),
            ),
          ),
          // 하단 고정: 새 채팅 글래스 버튼 + 글래스 검색바 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    GlassIconButton(
                      symbol: 'square.and.pencil',
                      size: 52,
                      onPressed: _newMessage,
                    ),
                    SizedBox(width: 10),
                    Expanded(child: _FloatingSearchBar()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingSearchBar extends StatelessWidget {
  _FloatingSearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F101828),
            blurRadius: 32,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              // 네이티브 글래스의 림처럼 보이는 헤어라인 — 흰 배경에서도 구분되게
              border: Border.all(color: AppColors.gray100),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.search, size: 20, color: AppColors.gray500),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    style: AppTextStyles.body2,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: '검색',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 삭제·나간 대화 보관함 — 지금은 담기는 게 없어 안내만 띄운다
class _ArchiveScreen extends StatelessWidget {
  _ArchiveScreen({required this.title, required this.emptyText});

  final String title;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(child: Text(title, style: AppTextStyles.title3)),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: Align(
                alignment: Alignment.topLeft,
                child: GlassIconButton(
                  symbol: 'chevron.backward',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 대화 한 줄 (목업)
///
/// 필터를 걸려면 데이터가 있어야 해서 하드코딩된 타일을 모델로 옮겼다.
class _Conversation {
  const _Conversation({
    required this.name,
    required this.preview,
    required this.time,
    required this.color,
    this.emoji,
    this.online = false,
    this.unread = false,
  });

  final String name;
  final String preview;
  final String time;
  final Color color;
  final String? emoji;
  final bool online;
  final bool unread;
}

final _conversations = <_Conversation>[
  _Conversation(
    name: '민중기',
    preview: '네 알겠습니다!',
    time: '방금 전',
    color: AppColors.primary,
    online: true,
    unread: true,
  ),
  _Conversation(
    name: '이준경',
    preview: '휴가 신청서 올렸어요',
    time: '오전 10:12',
    color: AppColors.warning,
    unread: true,
  ),
  _Conversation(
    name: '트레이너 단톡방',
    preview: '오늘 PT 일정 공유합니다',
    time: '오전 9:30',
    color: Color(0xFF7C5CFC),
    emoji: '💪',
  ),
  _Conversation(
    name: '유찬빈',
    preview: '수고하셨습니다~',
    time: '어제',
    color: AppColors.success,
    online: true,
  ),
  _Conversation(
    name: '박준현',
    preview: '사진을 보냈습니다',
    time: '어제',
    color: AppColors.gray500,
  ),
  _Conversation(
    name: '전체 공지방',
    preview: '8월 근무표가 확정되었습니다',
    time: '월요일',
    color: AppColors.error,
    emoji: '📢',
  ),
];

class _ConversationTile extends StatelessWidget {
  _ConversationTile({
    required this.name,
    required this.preview,
    required this.time,
    required this.color,
    this.emoji,
    this.online = false,
    this.unread = false,
    this.onOpen,
  });

  final String name;
  final String preview;
  final String time;
  final Color color;
  final String? emoji;
  final bool online;
  final bool unread;

  /// 있으면 화면 전환 대신 이 콜백을 부른다 (데스크톱 전체보기)
  final void Function(String name, Color color, String? emoji)? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (onOpen != null) {
          onOpen!(name, color, emoji);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ChatScreen(name: name, color: color, emoji: emoji),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _Avatar(
              name: name,
              color: color,
              size: 54,
              online: online,
              emoji: emoji,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '$preview · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: unread ? AppColors.gray900 : AppColors.gray400,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            if (unread)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  _Avatar({
    required this.name,
    required this.color,
    required this.size,
    this.online = false,
    this.emoji,
  });

  final String name;
  final Color color;
  final double size;
  final bool online;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: emoji != null ? 0.12 : 1),
            shape: BoxShape.circle,
          ),
          child: Text(
            emoji ?? name.characters.first,
            style: emoji != null
                ? TextStyle(fontSize: size * 0.42)
                : TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}
