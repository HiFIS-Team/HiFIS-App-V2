import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/chat_audit_api.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/delayed_spinner.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/pressable.dart';

/// 사내톡 열람 — 방 목록(왼쪽) + 그 방 대화(오른쪽) (모니터링 셋째 탭)
///
/// 사내톡 화면(`features/messages`)과 **다른 길을 쓴다** — 그쪽은 방 멤버만
/// 통과하는 `/chat/*` 이고 여기는 관리자 전용 `/audit/chat/*` 이다.
/// 읽음 처리를 안 하므로 방 사람들의 안읽음 수가 안 엉킨다.
class ChatAuditPanel extends StatefulWidget {
  ChatAuditPanel({super.key, required this.height});

  /// 2단이라 스스로 높이를 못 정한다 — 화면이 정해서 내려준다
  final double height;

  @override
  State<ChatAuditPanel> createState() => _ChatAuditPanelState();
}

class _ChatAuditPanelState extends State<ChatAuditPanel> {
  List<ChatAuditRoom> _rooms = const [];
  bool _loading = true;

  String? _selected;
  List<ChatAuditMessage> _messages = const [];
  bool _loadingMessages = false;

  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ChatAuditApi.rooms();
      if (!mounted) return;
      setState(() {
        _rooms = rows;
        _loading = false;
        _selected ??= rows.isEmpty ? null : rows.first.id;
      });
      if (_selected != null) await _open(_selected!);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _open(String roomId) async {
    setState(() {
      _selected = roomId;
      _loadingMessages = true;
    });
    try {
      final rows = await ChatAuditApi.messages(roomId, limit: 200);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loadingMessages = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMessages = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 방 이름 — 그룹은 붙인 이름, DM 은 참여자 이름으로 만든다
  String _roomName(ChatAuditRoom room) {
    final name = room.name;
    if (name != null && name.isNotEmpty) return name;
    final names = [
      for (final id in room.everyone)
        if (StaffDirectory.instance.byId(id)?.name case final who?
            when who.isNotEmpty)
          who,
    ];
    return names.isEmpty ? '대화방' : names.join(', ');
  }

  /// 검색어로 방을 거른다 — 이름에 든 말로 찾는다
  List<ChatAuditRoom> get _shownRooms {
    if (_query.isEmpty) return _rooms;
    return [
      for (final room in _rooms)
        if (_roomName(room).contains(_query)) room,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return DelayedSpinner(height: widget.height);
    }
    if (_rooms.isEmpty) {
      return EmptyCard(icon: CupertinoIcons.chat_bubble_2, text: '아직 대화방이 없어요');
    }

    final room = _rooms.where((r) => r.id == _selected).firstOrNull;
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 280, child: _roomList()),
          SizedBox(width: 16),
          Expanded(child: _thread(room)),
        ],
      ),
    );
  }

  Widget _roomList() {
    final rooms = _shownRooms;
    return Container(
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 15,
                    color: AppColors.gray400,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      style: AppTextStyles.body2,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '방 찾기',
                        hintStyle: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: rooms.isEmpty
                ? Center(
                    child: Text(
                      '찾는 방이 없어요',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
                    itemCount: rooms.length,
                    itemBuilder: (context, i) => _RoomRow(
                      name: _roomName(rooms[i]),
                      room: rooms[i],
                      selected: rooms[i].id == _selected,
                      onTap: () => _open(rooms[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _thread(ChatAuditRoom? room) {
    return Container(
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (room != null)
            Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _roomName(room),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label,
                        ),
                        SizedBox(height: 3),
                        Text(
                          _roomMeta(room),
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(height: 1, color: AppColors.divider),
          Expanded(
            child: _loadingMessages
                ? DelayedSpinner.bare()
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      '주고받은 말이 없어요',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(22, 16, 22, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _MessageRow(
                      message: _messages[i],
                      // 같은 사람이 이어 말하면 이름줄을 안 되풀이한다
                      grouped:
                          i > 0 &&
                          _messages[i - 1].senderId == _messages[i].senderId &&
                          !_messages[i - 1].isSystem &&
                          !_messages[i].isSystem,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// `멤버 3명 · 나간 사람 1명 · 15개`
  String _roomMeta(ChatAuditRoom room) {
    final parts = ['멤버 ${room.memberIds.length}명'];
    if (room.leftMemberIds.isNotEmpty) {
      parts.add('나간 사람 ${room.leftMemberIds.length}명');
    }
    parts.add('${room.messageCount}개');
    return parts.join(' · ');
  }
}

class _RoomRow extends StatelessWidget {
  _RoomRow({
    required this.name,
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final ChatAuditRoom room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Avatar(name: name, size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${room.messageCount}개'
                      '${room.lastMessageAt == null ? '' : ' · ${_day(room.lastMessageAt!)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  _MessageRow({required this.message, required this.grouped});

  final ChatAuditMessage message;

  /// 바로 위가 같은 사람이면 이름·아바타를 안 되풀이한다
  final bool grouped;

  String get _name =>
      StaffDirectory.instance.byId(message.senderId)?.name ?? '알 수 없음';

  @override
  Widget build(BuildContext context) {
    // 서버가 남긴 안내(초대·나가기·이름 변경)는 가운데 회색 한 줄
    if (message.isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
      );
    }

    final canceled = message.canceled;
    return Padding(
      padding: EdgeInsets.only(top: grouped ? 2 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: grouped ? null : Avatar(name: _name, size: 34),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!grouped) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _name,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _stamp(message.createdAt),
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        message.body.isEmpty && message.attachments.isNotEmpty
                            ? '파일 ${message.attachments.length}개'
                            : message.body,
                        style: AppTextStyles.body2.copyWith(
                          height: 1.5,
                          color: canceled
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          decoration: canceled
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    // 보낸 사람은 지운 셈이지만 기록에는 남는다 — 그 사실을 밝힌다
                    if (canceled) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '전송 취소',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// '8.4.' — 방 목록의 마지막 대화 날짜
String _day(DateTime time) => '${time.month}.${time.day}.';

/// '8.4. 14:02' — 대화 한 줄의 시각
String _stamp(DateTime time) =>
    '${time.month}.${time.day}. '
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
