import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/top_frost.dart';
import 'new_message_screen.dart';

/// 채팅방 상세 화면 (이름/알림/멤버 초대/공유된 콘텐츠)
///
/// 설정 값은 목업이며, 기능 개발 시 실제 채팅방 데이터로 교체한다.
class ChatDetailScreen extends StatefulWidget {
  ChatDetailScreen({
    super.key,
    required this.name,
    required this.color,
    this.emoji,
    this.onInvite,
    this.onRename,
  });

  final String name;
  final Color color;
  final String? emoji;

  /// 멤버 초대가 확정되면 초대된 이름 목록과 함께 호출된다.
  final ValueChanged<List<String>>? onInvite;

  /// 채팅방 이름이 변경되면 새 이름과 함께 호출된다.
  final ValueChanged<String>? onRename;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤 시 상단 블러 정도.
  final _collapse = ScrollCollapse(start: 10);

  int _shareTab = 0;

  /// 채팅방 이름 (변경 시 갱신)
  late String _name = widget.name;

  /// 이름 칸 인라인 수정용 — 변경 버튼을 눌러야 적용된다
  late final _nameController = TextEditingController(text: widget.name);

  static const _shareTabs = ['사진', '영상', '파일'];

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
    _nameController.dispose();
    super.dispose();
  }

  /// 이름 칸에 입력된 값을 적용한다. 빈 값이면 원래 이름으로 되돌린다.
  void _applyRename() {
    FocusScope.of(context).unfocus();
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      _nameController.text = _name;
      return;
    }
    if (value == _name) return;
    setState(() => _name = value);
    widget.onRename?.call(value);
  }

  Future<void> _invite() async {
    final names = await Navigator.push<List<String>>(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewMessageScreen(inviteMode: true),
      ),
    );
    if (names == null || names.isEmpty) return;
    widget.onInvite?.call(names);
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
    // 상세 → 채팅방 순서로 닫아 사내톡 목록으로 돌아간다
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
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
                      color: widget.color.withValues(
                        alpha: widget.emoji != null ? 0.12 : 1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.emoji ?? _name.characters.first,
                      style: widget.emoji != null
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
                          count: 0,
                          selected: _shareTab == i,
                          onTap: () => setState(() => _shareTab = i),
                        ),
                      ),
                  ],
                ),
                Container(height: 1, color: AppColors.gray100),
                SizedBox(height: 56),
                Center(
                  child: Text(
                    '공유된 ${_shareTabs[_shareTab]}이 없어요',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
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
