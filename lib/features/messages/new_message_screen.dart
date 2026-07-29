import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';
import 'chat_screen.dart';

/// 새 사내톡 만들기 화면 (아래에서 올라오는 모달)
///
/// 그룹 이름(선택)과 멤버를 고르면 대화가 시작된다.
/// [inviteMode]가 true면 기존 채팅방 멤버 초대 용도로 동작해,
/// 그룹 이름 없이 선택한 멤버 이름 목록을 pop 결과로 돌려준다.
/// 멤버 데이터는 하드코딩된 샘플이며, 기능 개발 시 실제 직원 목록으로 교체한다.
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
  double _collapse = 0;

  String _query = '';
  final Set<String> _selected = {};

  static final List<_Member> _members = [
    _Member('이앨리스', '디자인팀', '리드', AppColors.success),
    _Member('한이브', '운영팀', '팀장', Color(0xFF7C5CFC)),
    _Member('박그레이스', '개발팀', '팀장', Color(0xFFE0447C)),
    _Member('최마틴', '마케팅팀', '팀장', AppColors.warning),
    _Member('강레오', '영업팀', '팀장', AppColors.primary),
    _Member('윤소피아', '인사팀', '팀장', AppColors.error),
    _Member('임도훈', '재무팀', '이사', Color(0xFF00A8B5)),
    _Member('오민준', '개발팀', '대리', AppColors.success),
    _Member('신유나', '디자인팀', '대리', Color(0xFF7C5CFC)),
    _Member('권지호', '영업팀', '사원', Color(0xFFE0447C)),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final t = ((_scrollController.offset - 10) / 30).clamp(0.0, 1.0);
    if (t != _collapse) setState(() => _collapse = t);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggle(_Member member) {
    setState(() {
      if (!_selected.remove(member.name)) _selected.add(member.name);
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

  /// 선택된 멤버로 대화를 시작한다. TODO: 실제 대화방 생성 API 연동
  void _confirm() {
    final picked = _members.where((m) => _selected.contains(m.name)).toList();
    if (picked.isEmpty) return;

    // 초대 모드: 선택한 이름 목록만 돌려주고 닫는다
    if (widget.inviteMode) {
      Navigator.pop(context, picked.map((m) => m.name).toList());
      return;
    }

    final groupName = _groupNameController.text.trim();
    final isGroup = picked.length > 1;
    final title = groupName.isNotEmpty
        ? groupName
        : isGroup
        ? '${picked.first.name} 외 ${picked.length - 1}명'
        : picked.first.name;

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          name: title,
          color: picked.first.color,
          emoji: isGroup ? '👥' : null,
        ),
      ),
    );
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
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                  )
                else
                  for (final member in filtered)
                    _MemberTile(
                      member: member,
                      selected: _selected.contains(member.name),
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
          // 하단 고정: 네이티브 리퀴드 글래스 버튼 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    CNButton(
                      // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                      key: ValueKey('nm-cancel-${AppColors.isDark}'),
                      label: '취소',
                      style: CNButtonStyle.glass,
                      height: 56,
                      shrinkWrap: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: CNButton(
                        key: ValueKey('nm-cta-${AppColors.isDark}'),
                        label: _ctaLabel,
                        // 선택 전에는 글래스, 선택되면 파란 프로미넌트 글래스.
                        // 비활성화하면 iOS가 글래스 재질을 빼버려서 항상 활성으로
                        // 두고, 미선택 시 동작은 _confirm에서 무시한다.
                        style: _selected.isEmpty
                            ? CNButtonStyle.glass
                            : CNButtonStyle.prominentGlass,
                        tint: AppColors.primary,
                        height: 56,
                        onPressed: _confirm,
                      ),
                    ),
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

class _Member {
  _Member(this.name, this.team, this.role, this.color);

  final String name;
  final String team;
  final String role;
  final Color color;
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
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
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
