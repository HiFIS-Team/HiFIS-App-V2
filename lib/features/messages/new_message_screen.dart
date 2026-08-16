import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/top_frost.dart';
import 'chat_screen.dart';
import 'chat_store.dart';
import '../../core/theme/app_decorations.dart';

/// 새 사내톡 만들기 화면 (아래에서 올라오는 모달)
///
/// 그룹 이름(선택)과 멤버를 고르면 대화가 시작된다.
/// [inviteMode]가 true면 기존 채팅방 멤버 초대 용도로 동작해,
/// 그룹 이름 없이 선택한 멤버 이름 목록을 pop 결과로 돌려준다.
/// 명단은 서버 직원 목록(`StaffDirectory`)에서 가져온다. **나는 빠진다.**
class NewMessageScreen extends StatefulWidget {
  NewMessageScreen({super.key, this.inviteMode = false});

  final bool inviteMode;

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _scrollController = ScrollController();
  final _groupNameController = TextEditingController();

  /// 0(펼침) ~ 1(접힘). 스크롤 시 상단 블러 정도.
  final _collapse = ScrollCollapse(start: 10);

  String _query = '';

  /// 고른 사람의 **uuid** — 이름으로 담으면 동명이인이 섞인다
  final Set<String> _selected = {};

  /// 방을 만드는 중 — 두 번 눌러 방이 두 개 생기지 않게 잠근다
  bool _creating = false;

  /// 고를 수 있는 사람 — **나는 뺀다** (나에게 말을 걸 수는 없다)
  List<_Member> get _members => [
    for (final e in StaffDirectory.instance.employees)
      if (e.id != currentUser?.id && e.status == EmployeeStatus.active)
        _Member(
          e.id,
          e.name,
          StaffDirectory.instance.branchName(e.branchId),
          e.rank.label,
          e.color ?? staffOf(e.name).color,
          e.avatarImageUrl,
        ),
  ];

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
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggle(_Member member) {
    setState(() {
      if (!_selected.remove(member.id)) _selected.add(member.id);
    });
  }

  /// 선택 인원에 따라 문구가 바뀐다: 미선택 → 1:1/초대 → 그룹
  String get _ctaLabel {
    final count = _selected.length;
    if (widget.inviteMode) {
      return count == 0 ? '멤버 선택' : '초대하기 ($count)';
    }
    return switch (count) {
      0 => '멤버 선택',
      1 => '대화하기',
      _ => '그룹 만들기 ($count)',
    };
  }

  /// 선택된 멤버로 대화를 시작한다
  ///
  /// **1:1 은 서버가 기존 방을 찾아 준다** — 같은 사람에게 두 번 말을 걸어도
  /// 방이 새로 생기지 않는다.
  Future<void> _confirm() async {
    final picked = _members.where((m) => _selected.contains(m.id)).toList();
    if (picked.isEmpty || _creating) return;

    // 초대 모드: 고른 사람의 id 만 돌려주고 닫는다 (방은 상세 화면이 만든다)
    if (widget.inviteMode) {
      Navigator.pop(context, [for (final m in picked) m.id]);
      return;
    }

    final groupName = _groupNameController.text.trim();
    setState(() => _creating = true);
    try {
      final room = await ChatStore.instance.createRoom([
        for (final m in picked) m.id,
      ], name: groupName.isEmpty ? null : groupName);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        CupertinoPageRoute(builder: (_) => ChatScreen(roomId: room.id)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _creating = false);
        AppToast.show(context, messageOf(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _members.where((m) {
      if (_query.isEmpty) return true;
      return m.name.contains(_query) ||
          m.team.contains(_query) ||
          m.role.contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 76, 20, 140),
              children: [
                if (!widget.inviteMode) ...[
                  _FieldLabel(title: '그룹 이름', hint: '(선택)'),
                  SizedBox(height: 8),
                  _InputBox(
                    child: TextField(
                      controller: _groupNameController,
                      style: AppTextStyles.body2,
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: '예) 마케팅 팀',
                        hintStyle: AppTextStyles.body2.copyWith(
                          color: AppColors.gray400,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
                _FieldLabel(title: '멤버 추가'),
                SizedBox(height: 8),
                _InputBox(
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        size: 20,
                        color: AppColors.gray500,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          style: AppTextStyles.body2,
                          cursorColor: AppColors.primary,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          decoration: InputDecoration(
                            hintText: '이름 · 팀 · 직책으로 검색',
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
                SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        '검색 결과가 없어요',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  for (final member in filtered)
                    _MemberTile(
                      member: member,
                      selected: _selected.contains(member.id),
                      onTap: () => _toggle(member),
                    ),
              ],
            ),
          ),
          // 스크롤 시 상단 프로그레시브 블러 — 콘텐츠가 헤더 뒤로 흐려진다
          TopFrost(collapse: _collapse, color: AppColors.surface),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    widget.inviteMode ? '멤버 초대' : '새 사내톡',
                    style: AppTextStyles.title3,
                  ),
                ),
              ),
            ),
          ),
          // 좌측 상단 닫기 (글래스 버튼 고정)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'xmark',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 하단 고정: 글래스 버튼 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                BottomActionButton(
                  id: 'nm-cancel',
                  label: '취소',
                  filled: false,
                  tinted: false,
                  shrinkWrap: true,
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: BottomActionButton(
                    id: 'nm-cta',
                    label: _ctaLabel,
                    // 아무도 안 골랐으면 비어 있는 상태로 두고,
                    // 동작은 _confirm에서 무시한다
                    filled: _selected.isNotEmpty,
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Member {
  _Member(this.id, this.name, this.team, this.role, this.color, this.avatarUrl);

  final String id;
  final String name;

  /// 소속 지점 — 검색에 걸리라고 들고 있다
  final String team;
  final String role;
  final Color color;
  final String? avatarUrl;
}

class _FieldLabel extends StatelessWidget {
  _FieldLabel({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: title,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (hint != null)
            TextSpan(
              text: ' $hint',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w400),
            ),
        ],
      ),
    );
  }
}

/// 회색 면 입력 박스 — 폼 요소는 글래스 없이 플랫하게 둔다
class _InputBox extends StatelessWidget {
  _InputBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: AppDecorations.field(),
      child: child,
    );
  }
}

class _MemberTile extends StatelessWidget {
  _MemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final _Member member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.name.characters.first,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: AppTextStyles.body1),
                  SizedBox(height: 2),
                  Text(
                    '${member.team} · ${member.role}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            // 선택 표시: 빈 링 → 파란 체크 원
            AnimatedContainer(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.gray200,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
