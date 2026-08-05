import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/chat/chat_api.dart';
import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/top_frost.dart';
import 'chat_screen.dart';
import 'chat_store.dart';
import 'new_message_screen.dart';

/// 사내톡 화면 (인스타그램 DM 스타일)
///
/// 방 목록은 [ChatStore] 가 들고 있다 — 이 화면과 채팅방·데스크톱 2단 화면이
/// 같은 목록을 본다. 새 메시지는 WebSocket 으로 들어와 화면을 다시 그린다.
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
  final void Function(ChatRoom room)? onOpenChat;

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

  final _store = ChatStore.instance;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _store.addListener(_onStore);
    _load();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  /// 방 목록 받아오기 — 한 번 받아 뒀으면 조용히 갱신만 한다
  Future<void> _load() async {
    try {
      await _store.loadRooms();
    } catch (error) {
      if (mounted && !_store.loaded) AppToast.show(context, messageOf(error));
    }
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _scrollController.dispose();
    _collapse.dispose();
    super.dispose();
  }

  /// 새 채팅 — 호스트가 자리를 정해 줬으면 거기에, 아니면 이 화면 위로 띄운다
  ///
  /// 사내톡 패널에서는 **패널 안에서 폰처럼 밀려 들어온다** (패널 전용
  /// 내비게이터). 패널 밖을 덮지 않는 게 이 화면의 설계다.
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

  /// 메뉴가 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다 (실제 발생)
  bool _filterOpen = false;

  /// 헤더 필터 메뉴 — 아이폰 메시지의 그 메뉴와 같은 구성
  Future<void> _openFilterMenu() async {
    if (_filterOpen) return;
    final button = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    // **최상위 오버레이 기준으로 띄운다.** 사내톡 패널 안의 오버레이를 쓰면
    // 메뉴가 그 상자에 갇히고, 바깥을 눌러도 안 닫혀서 누를 때마다 쌓인다.
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (button == null || overlay == null) return;
    _filterOpen = true;

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
      useRootNavigator: true,
    );
    _filterOpen = false;
    if (!mounted) return;

    switch (picked) {
      case 'unread':
        setState(() => _unreadOnly = !_unreadOnly);
      case 'left':
        _openArchive('최근 나간 항목', '최근 나간 대화방이 없어요', load: _store.leftRooms);
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

  /// 나간 대화 보관함 — 새 채팅과 같은 자리에서 열린다
  void _openArchive(
    String title,
    String emptyText, {
    Future<List<ChatRoom>> Function()? load,
  }) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            _ArchiveScreen(title: title, emptyText: emptyText, load: load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _store.rooms;
    final shown = _unreadOnly
        ? [
            for (final room in rooms)
              if (room.unreadCount > 0) room,
          ]
        : rooms;

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
                  for (final room in shown)
                    _ConversationTile(room: room, onOpen: widget.onOpenChat),
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
          //
          // **연필과 검색바를 한 Row 에 두면 안 된다.** 검색바가 `BackdropFilter`
          // 라서 애플에서는 네이티브 버튼(CNButton)이 그 블러 레이어에 묻히고
          // **탭이 `onPressed` 까지 오지 않는다** (실제 발생 — 눌러도 아무 일도
          // 안 일어나고 에러도 안 났다). 그래서 자리는 그대로 두고 레이어만
          // 나눈다 — 검색바가 먼저 그려지고 연필이 그 위에 올라간다.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    // 연필이 앉을 자리만 비워 둔다 (52 + 간격 10)
                    SizedBox(width: 62),
                    Expanded(child: _FloatingSearchBar()),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(left: 20, bottom: 10),
                child: GlassIconButton(
                  symbol: 'square.and.pencil',
                  size: 52,
                  onPressed: _newMessage,
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

/// 나간 대화 보관함 — [load] 가 있으면 그 목록을, 없으면 안내만 띄운다
class _ArchiveScreen extends StatefulWidget {
  _ArchiveScreen({required this.title, required this.emptyText, this.load});

  final String title;
  final String emptyText;

  /// 담긴 방을 받아오는 함수 — null 이면 늘 비어 있는 보관함이다
  final Future<List<ChatRoom>> Function()? load;

  @override
  State<_ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<_ArchiveScreen> {
  List<ChatRoom> _rooms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final load = widget.load;
    if (load == null) return;
    try {
      final rooms = await load();
      if (mounted) setState(() => _rooms = rooms);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          if (_rooms.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.emptyText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            // 목록 화면과 같은 타일을 그대로 쓴다 — 새로 만든 모양이 아니다
            ListView(
              padding: EdgeInsets.fromLTRB(0, 68, 0, 40),
              children: [
                for (final room in _rooms) _ConversationTile(room: room),
              ],
            ),
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(widget.title, style: AppTextStyles.title3),
                ),
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

/// 목록의 시각 — 오늘이면 시:분, 어제면 '어제', 그 전이면 날짜
String chatListTime(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final gap = today.difference(day).inDays;

  if (gap == 0) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '${at.hour < 12 ? '오전' : '오후'} $hour:$minute';
  }
  if (gap == 1) return '어제';
  if (gap < 7) return const ['월', '화', '수', '목', '금', '토', '일'][at.weekday - 1];
  return '${at.month}월 ${at.day}일';
}

/// 목록에 적을 마지막 메시지 한 줄
String chatPreview(ChatMessage? last) {
  if (last == null) return '아직 대화가 없어요';
  if (last.body.isNotEmpty) return last.body;
  return last.attachments.isEmpty ? '' : '파일을 보냈어요';
}

/// 지금 나와 있는 사람인가 — 조직도와 같은 기준을 쓴다
///
/// 사내톡에만 따로 접속 상태를 두지 않는다. 출근해서 아직 퇴근을 안 찍었으면
/// 초록 점이 붙는다 (`todayAttendanceStatus`).
bool chatRoomOnline(ChatRoom room) {
  final peer = chatRoomPeer(room);
  return peer?.todayStatus?.working ?? false;
}

class _ConversationTile extends StatelessWidget {
  _ConversationTile({required this.room, this.onOpen});

  final ChatRoom room;

  /// 있으면 화면 전환 대신 이 콜백을 부른다 (데스크톱 전체보기)
  final void Function(ChatRoom room)? onOpen;

  @override
  Widget build(BuildContext context) {
    final name = chatRoomTitle(room);
    final unread = room.unreadCount > 0;
    // 상대가 치고 있으면 미리보기 자리를 잠깐 내준다 (새로 그리는 건 없다)
    final typing = ChatStore.instance.typingIn(room.id).isNotEmpty;
    // 그룹방은 사람 하나로 표현할 수 없어서 브랜드 색으로 둔다
    final color = chatRoomPeer(room)?.color ?? staffOf(name).color;

    return InkWell(
      onTap: () {
        if (onOpen != null) {
          onOpen!(room);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => ChatScreen(roomId: room.id)),
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
              online: chatRoomOnline(room),
              emoji: null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    typing
                        ? '입력 중…'
                        : '${chatPreview(room.lastMessage)} · '
                              '${chatListTime(room.sortAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: typing
                          ? AppColors.primary
                          : (unread ? AppColors.gray900 : AppColors.gray400),
                      fontWeight: unread || typing
                          ? FontWeight.w600
                          : FontWeight.w400,
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
