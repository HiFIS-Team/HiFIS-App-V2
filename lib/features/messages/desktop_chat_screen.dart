import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../notifications/notification_screen.dart' show requestedRoomId;
import 'chat_screen.dart';
import 'message_screen.dart';
import 'new_message_screen.dart';

/// 데스크톱 사내톡 전체보기 (인스타그램 DM 데스크톱 패턴)
///
/// 왼쪽에는 대화 목록, 오른쪽에는 선택한 채팅방을 나란히 보여준다.
/// 아무 대화도 고르지 않았으면 오른쪽에 안내 상태를 띄운다.
class DesktopChatScreen extends StatefulWidget {
  DesktopChatScreen({super.key});

  @override
  State<DesktopChatScreen> createState() => _DesktopChatScreenState();
}

class _DesktopChatScreenState extends State<DesktopChatScreen> {
  /// 오른쪽 채팅 영역 전용 내비게이터
  final _rightNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 푸시를 눌러 들어왔으면 그 방을 오른쪽에 띄운다 (2026-08-19).
    // **왼쪽 목록은 이 값을 안 집는다** (`embedded`) — 거기서 밀어 올리면
    // 목록 칸 안에 방이 겹쳐 뜬다
    final id = requestedRoomId.value;
    if (id == null) return;
    requestedRoomId.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openRoom(id);
    });
  }

  void _openRoom(String roomId) {
    _rightNavKey.currentState?.pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => ChatScreen(roomId: roomId)),
      (route) => route.isFirst,
    );
  }

  // 이전에 보던 채팅방은 스택에 쌓지 않고 갈아끼운다
  void _openChat(ChatRoom room) => _openRoom(room.id);

  /// 새 사내톡 — **오른쪽 메시지 칸**에 띄운다 (채팅방이 뜨는 그 자리)
  void _newMessage() {
    _rightNavKey.currentState?.push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewMessageScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Row(
            children: [
              // 왼쪽: 대화 목록 (대화를 누르면 오른쪽에 채팅방이 뜬다)
              SizedBox(
                width: 360,
                child: MessageScreen(
                  embedded: true,
                  onOpenChat: _openChat,
                  // 연필도 가운데 '메시지 보내기' 와 같은 자리에 연다
                  onNewMessage: _newMessage,
                ),
              ),
              Container(width: 1, color: AppColors.gray100),
              // 오른쪽: 선택한 채팅방 / 안내 상태
              Expanded(
                child: ClipRect(
                  child: Navigator(
                    key: _rightNavKey,
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (_) =>
                          _EmptyChatState(onNewMessage: _newMessage),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 좌측 상단 뒤로가기 (전체보기 닫기)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 16),
            child: GlassIconButton(
              symbol: 'chevron.backward',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 채팅방을 고르기 전의 오른쪽 안내 상태
class _EmptyChatState extends StatelessWidget {
  _EmptyChatState({required this.onNewMessage});

  final VoidCallback onNewMessage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
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
                  Icons.chat_bubble_outline_rounded,
                  size: 38,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text('내 메시지', style: AppTextStyles.title2),
            SizedBox(height: 6),
            Text(
              '동료나 그룹에 메시지를 보내보세요',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            Pressable(
              scale: 0.97,
              onTap: onNewMessage,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '메시지 보내기',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
