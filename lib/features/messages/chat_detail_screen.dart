import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/client/api_client.dart' show fileUrl;
import '../../core/api/client/api_exception.dart';
import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/top_frost.dart';
import '../../core/widgets/input/pressable.dart';
import 'chat_store.dart';
import 'new_message_screen.dart';

/// 채팅방 상세 화면 (이름/멤버 초대/공유된 콘텐츠)
///
/// 이름 변경·초대·나가기는 전부 서버로 간다. 서버가 그 사실을 대화에
/// 회색 안내 한 줄로 남기므로 방에 있는 사람 모두가 바로 본다.
///
/// **나가면 `true` 로 닫힌다** — 채팅방 화면이 그걸 보고 같이 닫는다.
class ChatDetailScreen extends StatefulWidget {
  ChatDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤 시 상단 블러 정도.
  final _collapse = ScrollCollapse(start: 10);

  int _shareTab = 0;

  final _store = ChatStore.instance;

  ChatRoom? get _room => _store.roomOf(widget.roomId);

  /// 채팅방 이름 — DM 은 상대 이름이라 바꿀 수 없다
  String get _name {
    final room = _room;
    return room == null ? '대화' : chatRoomTitle(room);
  }

  bool get _isGroup => _room?.isGroup ?? false;

  Color get _headColor {
    final room = _room;
    if (room == null) return AppColors.primary;
    return chatRoomPeer(room)?.color ?? staffOf(_name).color;
  }

  /// 이름 칸 인라인 수정용 — 변경 버튼을 눌러야 적용된다
  late final _nameController = TextEditingController(text: _name);

  bool _saving = false;
  bool _muting = false;

  static const _shareTabs = ['사진', '영상', '파일'];

  /// 이 방에서 오간 첨부를 종류별로 모은다 — 대화에서 뽑으므로 따로 안 받아온다
  List<List<String>> get _shared {
    const image = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'};
    const video = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};
    final photos = <String>[], videos = <String>[], files = <String>[];
    for (final message in _store.messagesOf(widget.roomId)) {
      for (final url in message.attachments) {
        final path = url.split('?').first;
        final dot = path.lastIndexOf('.');
        final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
        if (image.contains(ext)) {
          photos.add(url);
        } else if (video.contains(ext)) {
          videos.add(url);
        } else {
          files.add(url);
        }
      }
    }
    return [photos, videos, files];
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _store.addListener(_onStore);
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _scrollController.dispose();
    _collapse.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 이름 칸에 입력된 값을 적용한다. 빈 값이면 원래 이름으로 되돌린다.
  Future<void> _applyRename() async {
    FocusScope.of(context).unfocus();
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      _nameController.text = _name;
      return;
    }
    if (value == _name || _saving) return;
    setState(() => _saving = true);
    try {
      await _store.rename(widget.roomId, value);
      if (mounted) AppToast.show(context, '방 이름을 바꿨어요');
    } catch (error) {
      if (mounted) {
        _nameController.text = _name;
        AppToast.show(context, messageOf(error));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  /// 이 방 알림 끄기/켜기 — 나에게만 적용된다
  Future<void> _toggleMute() async {
    final room = _room;
    if (room == null || _muting) return;
    setState(() => _muting = true);
    try {
      await _store.setMuted(widget.roomId, !room.muted);
      if (mounted) {
        AppToast.show(context, room.muted ? '알림을 다시 받아요' : '이 방 알림을 껐어요');
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _muting = false);
  }

  Future<void> _invite() async {
    final picked = await Navigator.push<List<String>>(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewMessageScreen(inviteMode: true),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    try {
      await _store.addMembers(widget.roomId, picked);
      // 초대 안내는 서버가 대화에 남긴다 — 여기서 따로 만들지 않는다
      if (mounted) AppToast.show(context, '초대했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _leave() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('채팅방 나가기'),
        content: Text('나가면 대화 목록에서 사라져요.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('나가기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _store.leave(widget.roomId);
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
      return;
    }
    if (!mounted) return;
    // 화면이 닫히기 전에 띄운다 — 토스트는 최상위 Overlay 에 뜨므로 남아 있는다
    AppToast.show(context, '채팅방에서 나왔어요');
    // `true` 로 닫으면 채팅방 화면이 자기도 닫는다 → 사내톡 목록으로 돌아간다
    Navigator.pop(context, true);
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
              padding: EdgeInsets.fromLTRB(20, 70, 20, 60),
              children: [
                // 아바타 + 이름
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _headColor.withValues(alpha: _isGroup ? 0.12 : 1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _isGroup ? '💬' : _name.characters.first,
                      style: _isGroup
                          ? TextStyle(fontSize: 36)
                          : TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Center(child: Text(_name, style: AppTextStyles.title2)),
                SizedBox(height: 32),
                _SectionLabel('이름 변경'),
                SizedBox(height: 8),
                _SettingBox(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: AppColors.primary,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _applyRename(),
                          decoration: InputDecoration(
                            hintText: '채팅방 이름',
                            hintStyle: AppTextStyles.body1.copyWith(
                              color: AppColors.gray400,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      Pressable(
                        onTap: _applyRename,
                        scale: 0.9,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray100),
                          ),
                          child: Text(
                            '변경',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                _SectionLabel('알림'),
                SizedBox(height: 8),
                _SettingBox(
                  onTap: _toggleMute,
                  child: Row(
                    children: [
                      Icon(
                        (_room?.muted ?? false)
                            ? CupertinoIcons.bell_slash
                            : CupertinoIcons.bell,
                        size: 20,
                        color: AppColors.gray600,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '알림 받기',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 끄면 대화는 그대로 오고 푸시만 안 온다
                      CupertinoSwitch(
                        value: !(_room?.muted ?? false),
                        activeTrackColor: AppColors.primary,
                        onChanged: _muting ? null : (_) => _toggleMute(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                _SectionLabel('멤버'),
                SizedBox(height: 8),
                _SettingBox(
                  onTap: _invite,
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.person_add,
                        size: 20,
                        color: AppColors.gray600,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '멤버 초대',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: AppColors.gray400,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                _SectionLabel('공유된 콘텐츠'),
                SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 0; i < _shareTabs.length; i++)
                      Expanded(
                        child: _ShareTab(
                          label: _shareTabs[i],
                          count: _shared[i].length,
                          selected: _shareTab == i,
                          onTap: () => setState(() => _shareTab = i),
                        ),
                      ),
                  ],
                ),
                Container(height: 1, color: AppColors.gray100),
                if (_shared[_shareTab].isEmpty) ...[
                  SizedBox(height: 56),
                  Center(
                    child: Text(
                      '공유된 ${_shareTabs[_shareTab]}이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 16),
                  // 있을 때만 그린다 — 빈 상태 문구는 원래 자리 그대로다
                  //
                  // 인스타처럼 **한 줄에 3칸**. 칸 크기를 고정하지 않고 폭을
                  // 3등분하므로 기기 폭이 달라도 줄당 개수가 안 바뀐다
                  // (`Wrap` + 고정 88 이던 때는 폭에 따라 3개도 4개도 됐다).
                  GridView.count(
                    // 바깥 ListView 안에 있으므로 자기 높이만 차지하고
                    // 따로 스크롤하지 않는다
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final url in _shared[_shareTab])
                        _SharedThumb(url: url, photo: _shareTab == 0),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 스크롤 시 상단 프로그레시브 블러
          TopFrost(collapse: _collapse, color: AppColors.surface),
          // 좌측 뒤로가기 / 우측 나가기
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
                  GlassIconButton(
                    // 좌우 무게가 균형 잡힌 문 심볼 — 사각+화살표 심볼은
                    // 잉크가 왼쪽으로 쏠려 보인다
                    symbol: 'door.right.hand.open',
                    symbolColor: AppColors.error,
                    onPressed: _leave,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공유된 콘텐츠 한 칸 — 사진은 미리보기, 그 외는 파일 이름
class _SharedThumb extends StatelessWidget {
  _SharedThumb({required this.url, required this.photo});

  final String url;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    if (photo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        // 크기를 안 준다 — 격자 칸이 정해 주는 대로 채운다
        child: Image.network(
          fileUrl(url),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _box(),
        ),
      );
    }
    return _box();
  }

  Widget _box() => Container(
    padding: EdgeInsets.all(8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.doc, size: 20, color: AppColors.gray500),
        SizedBox(height: 6),
        Text(
          _nameOf(url),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    ),
  );

  static String _nameOf(String url) {
    final path = url.split('?').first;
    return path.substring(path.lastIndexOf('/') + 1);
  }
}

class _SectionLabel extends StatelessWidget {
  _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label.copyWith(color: AppColors.gray500),
    );
  }
}

/// 회색 면 설정 박스 — onTap이 있으면 통째로 눌린다.
/// 내용과 무관하게 높이를 고정해 박스끼리 크기가 같게 유지한다.
class _SettingBox extends StatelessWidget {
  _SettingBox({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap!, scale: 0.98, child: box);
  }
}

class _ShareTab extends StatelessWidget {
  _ShareTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.gray500,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
