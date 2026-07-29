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
  MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 큰 타이틀이 스크롤로 사라지는 정도.
  double _collapse = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final t = ((_scrollController.offset - 30) / 30).clamp(0.0, 1.0);
    if (t != _collapse) setState(() => _collapse = t);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                _ConversationTile(
                  name: '김민수',
                  preview: '네 알겠습니다!',
                  time: '방금 전',
                  color: AppColors.primary,
                  online: true,
                  unread: true,
                ),
                _ConversationTile(
                  name: '박지현',
                  preview: '휴가 신청서 올렸어요',
                  time: '오전 10:12',
                  color: AppColors.warning,
                  unread: true,
                ),
                _ConversationTile(
                  name: '트레이너 단톡방',
                  preview: '오늘 PT 일정 공유합니다',
                  time: '오전 9:30',
                  color: Color(0xFF7C5CFC),
                  emoji: '💪',
                ),
                _ConversationTile(
                  name: '이서연',
                  preview: '수고하셨습니다~',
                  time: '어제',
                  color: AppColors.success,
                  online: true,
                ),
                _ConversationTile(
                  name: '정우진',
                  preview: '사진을 보냈습니다',
                  time: '어제',
                  color: AppColors.gray500,
                ),
                _ConversationTile(
                  name: '전체 공지방',
                  preview: '8월 근무표가 확정되었습니다',
                  time: '월요일',
                  color: AppColors.error,
                  emoji: '📢',
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
                  GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                  Spacer(),
                  GlassIconButton(symbol: 'line.3.horizontal.decrease'),
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
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => NewMessageScreen(),
                        ),
                      ),
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
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
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

class _ConversationTile extends StatelessWidget {
  _ConversationTile({
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ChatScreen(name: name, color: color, emoji: emoji),
        ),
      ),
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
