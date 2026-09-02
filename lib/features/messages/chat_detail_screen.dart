import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/chat/chat_api.dart';
import '../../core/api/client/api_exception.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/top_frost.dart';
import '../../core/widgets/input/mode_switch.dart'
    show slideCurve, slideDuration;
import '../../core/widgets/input/pressable.dart';
import 'chat_screen.dart';
import 'chat_store.dart';
import 'new_message_screen.dart';

/// 채팅방 상세 화면 (이름/멤버/공유된 콘텐츠)
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

  /// 이 방에 있는 사람 — **방장 먼저, 그다음 이름순**
  ///
  /// 명단에서 못 찾은 id 는 뺀다 (지워진 계정 등). 목록이 비는 것보다
  /// 아는 사람만 세우는 게 낫다.
  List<Employee> get _people {
    final room = _room;
    if (room == null) return const [];
    final found = [
      for (final id in room.memberIds) ?StaffDirectory.instance.byId(id),
    ];
    found.sort((a, b) {
      // 방장이 먼저 — 그다음은 앱 공통 차례 (지점 → 직급 → 이름)
      final owner =
          (a.id == room.ownerId ? 0 : 1) - (b.id == room.ownerId ? 0 : 1);
      return owner != 0 ? owner : StaffDirectory.instance.compareStaff(a, b);
    });
    return found;
  }

  /// '사람' 줄에 적히는 이름들 — **나는 뺀다** (내가 있는 건 아니까)
  String get _peopleLine {
    final others = [
      for (final e in _people)
        if (e.id != currentUser?.id) e.name,
    ];
    if (others.isEmpty) return '나 혼자 있어요';
    if (others.length <= 2) return others.join(', ');
    return '${others.take(2).join(', ')} 외 ${others.length - 2}명';
  }

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
    super.dispose();
  }

  /// 방 이름 바꾸기 — **그룹만** (DM 은 상대 이름이 곧 방 이름이라 서버가 막는다)
  Future<void> _rename() async {
    if (_saving) return;
    final controller = TextEditingController(text: _name);
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('이름 변경'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: '채팅방 이름',
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('변경'),
          ),
        ],
      ),
    );
    controller.dispose();
    final next = value?.trim() ?? '';
    if (next.isEmpty || next == _name || !mounted) return;

    setState(() => _saving = true);
    try {
      await _store.rename(widget.roomId, next);
      if (mounted) AppToast.show(context, '방 이름을 바꿨어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
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
        // 이미 있는 사람은 체크된 채로 잠긴다 — 안 넘겨주면 다시 고를 수 있고
        // 그러면 서버가 400 으로 막는다
        builder: (_) => NewMessageScreen(
          inviteMode: true,
          already: _room?.memberIds ?? const [],
        ),
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

  void _openMembers() => Navigator.push<void>(
    context,
    CupertinoPageRoute(builder: (_) => _MembersScreen(roomId: widget.roomId)),
  );

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
    final muted = _room?.muted ?? false;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              // 좌우 여백을 여기서 안 준다 — 사진 격자가 화면 끝까지 붙어야 해서
              // 줄마다 따로 넣는다 (`_Pad`)
              padding: EdgeInsets.fromLTRB(0, 70, 0, 60),
              children: [
                // 아바타 + 이름
                Center(child: _head()),
                SizedBox(height: 14),
                Center(
                  child: _Pad(
                    child: Text(
                      _name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title2,
                    ),
                  ),
                ),
                // DM 은 상대 이름이 곧 방 이름이라 바꿀 수 없다 (서버가 400)
                if (_isGroup) ...[
                  SizedBox(height: 6),
                  Center(
                    child: Pressable(
                      onTap: _rename,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          '이름 변경',
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 26),
                // 자주 쓰는 것 두 개 — 나가기는 헤더 오른쪽에 있다
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionItem(
                      icon: CupertinoIcons.person_add,
                      label: '추가',
                      onTap: _invite,
                    ),
                    SizedBox(width: 44),
                    _ActionItem(
                      icon: muted
                          ? CupertinoIcons.bell_slash
                          : CupertinoIcons.bell,
                      label: muted ? '알림 켜기' : '알림 끄기',
                      onTap: _muting ? null : _toggleMute,
                    ),
                  ],
                ),
                SizedBox(height: 28),
                _Pad(
                  child: Pressable(
                    onTap: _openMembers,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.person_2,
                            size: 20,
                            color: AppColors.gray600,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '사람',
                                  style: AppTextStyles.body1.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _peopleLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, box) {
                    final cell = box.maxWidth / _shareTabs.length;
                    return Stack(
                      children: [
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
                        // 파란 줄 **하나**가 미끄러진다 (2026-08-21 대표 요청).
                        // 칸마다 테두리를 켰다 껐다 하면 툭 튄다 — 업무·랭킹
                        // 탭과 같은 빠르기를 쓴다 (`slideDuration`)
                        AnimatedPositioned(
                          duration: slideDuration,
                          curve: slideCurve,
                          left: cell * _shareTab,
                          width: cell,
                          bottom: 0,
                          child: Container(height: 2, color: AppColors.primary),
                        ),
                      ],
                    );
                  },
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
                ] else
                  // 인스타처럼 **한 줄에 3칸**. 칸 크기를 고정하지 않고 폭을
                  // 3등분하므로 기기 폭이 달라도 줄당 개수가 안 바뀐다.
                  //
                  // 화면 끝까지 붙이고 사이도 2px 만 띄운다 — 사진이 격자로
                  // 한 덩어리처럼 보여야 한 눈에 훑어진다
                  GridView.count(
                    // 바깥 ListView 안에 있으므로 자기 높이만 차지하고
                    // 따로 스크롤하지 않는다
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: [
                      for (final url in _shared[_shareTab])
                        _SharedThumb(url: url, photo: _shareTab == 0),
                    ],
                  ),
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

  /// 머리말 동그라미 — DM 은 상대 프로필 사진, 그룹은 말풍선
  Widget _head() {
    final room = _room;
    final peer = room == null ? null : chatRoomPeer(room);
    if (peer != null) return Avatar(name: peer.name, size: 84);
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (room == null ? AppColors.primary : staffOf(_name).color)
            .withValues(alpha: _isGroup ? 0.12 : 1),
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
    );
  }
}

/// 이 방에 있는 사람 목록
///
/// 방을 나가거나 초대하면 [ChatStore] 가 알려 주므로 열어 둔 채로도 갱신된다.
class _MembersScreen extends StatelessWidget {
  _MembersScreen({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListenableBuilder(
        listenable: ChatStore.instance,
        builder: (context, _) {
          final room = ChatStore.instance.roomOf(roomId);
          final people = [
            for (final id in room?.memberIds ?? const <String>[])
              ?StaffDirectory.instance.byId(id),
          ];
          people.sort((a, b) {
            // 방장이 먼저 — 그다음은 앱 공통 차례
            final owner =
                (a.id == room?.ownerId ? 0 : 1) -
                (b.id == room?.ownerId ? 0 : 1);
            return owner != 0
                ? owner
                : StaffDirectory.instance.compareStaff(a, b);
          });

          return Stack(
            children: [
              SafeArea(
                bottom: false,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 76, 20, 40),
                  children: [
                    for (final person in people)
                      _PersonTile(
                        person: person,
                        owner: person.id == room?.ownerId,
                        me: person.id == currentUser?.id,
                      ),
                  ],
                ),
              ),
              // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
              IgnorePointer(
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: Text('사람', style: AppTextStyles.title3),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, left: 16),
                  child: GlassIconButton(
                    symbol: 'chevron.backward',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  _PersonTile({required this.person, required this.owner, required this.me});

  final Employee person;

  /// 방을 만든 사람
  final bool owner;
  final bool me;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Avatar(name: person.name, size: 48),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1,
                      ),
                    ),
                    if (me) ...[SizedBox(width: 6), _Tag('나')],
                    if (owner) ...[SizedBox(width: 6), _Tag('방장')],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '${StaffDirectory.instance.branchName(person.branchId)} · '
                  '${person.rank.label}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: AppColors.gray600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 아이콘 + 라벨 세로 한 벌 — 이름 아래 가로로 선다
class _ActionItem extends StatelessWidget {
  _ActionItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? () {},
      child: SizedBox(
        // 라벨 길이가 바뀌어도('알림 끄기' ↔ '알림 켜기') 자리가 안 흔들리게
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.textPrimary),
            SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 좌우 여백 — 바깥 ListView 는 여백을 안 줘서(사진 격자가 끝까지 붙는다)
/// 글이 있는 줄만 이걸로 감싼다
class _Pad extends StatelessWidget {
  _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: child);
}

/// 공유된 콘텐츠 한 칸 — 사진은 미리보기, 그 외는 파일 이름
class _SharedThumb extends StatelessWidget {
  _SharedThumb({required this.url, required this.photo});

  final String url;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    if (photo) {
      // 말풍선과 **같은 길**로 그린다 — 한 번 받아 둔 사진은 파일에 남아 있어서
      // 여기서도 첫 프레임부터 뜬다 (`Image.network` 이던 때는 서명이 갈려
      // 매번 새로 받았다)
      return chatPhoto(
        url,
        // 한 칸이 폭의 1/3 이라 원본을 그대로 풀면 메모리가 금방 넘친다
        cacheWidth: 320,
        onError: (_, _, _) => _box(),
      );
    }
    return _box();
  }

  Widget _box() => Container(
    padding: EdgeInsets.all(8),
    alignment: Alignment.center,
    color: AppColors.gray50,
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
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  static String _nameOf(String url) {
    final path = url.split('?').first;
    return path.substring(path.lastIndexOf('/') + 1);
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
      // **파란 줄은 여기서 안 그린다** — 위에서 줄 하나가 미끄러져 온다.
      // 아래 여백 14 = 예전 여백 12 + 테두리 2 (자리는 그대로다)
      child: Padding(
        padding: EdgeInsets.only(top: 12, bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: selected ? AppColors.primary : AppColors.gray500,
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
