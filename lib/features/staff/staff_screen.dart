import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/attendance_api.dart';
import '../../core/api/invite_key_api.dart';
import '../../core/api/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/desktop_header.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';
import '../messages/chat_screen.dart';
import '../messages/chat_store.dart';

part 'staff_manage.dart';
part 'staff_models.dart';

/// 직원 화면
///
/// 지점 구성원을 찾아보고 바로 연락하는 화면이다. 카드마다 지금 상태
/// (근무중·회의중·외출…)가 보이고, 카드를 누르면 연락처와 이번 달 근태
/// 요약이 뜬다. 폰은 아직 진입점이 없어 PC를 먼저 만든다.
///
/// 사람은 직급으로 나눈다 — 누구를 찾을 때 먼저 떠올리는 기준이다.
/// 시스템 권한(MASTER·ADMIN·MEMBER)은 찾는 기준이 아니라서 배지로만 붙인다.
///
/// 명단은 `/employees`, 지점 이름은 `/branches` 로 채운다 ([_loadStaff]).
/// 지금 나와 있는 사람은 명단에 같이 실려 온다 (`todayAttendanceStatus`).
///
/// 지점 필터에 **본사(HQ)는 세우지 않는다** — 지점이 아니라 전사다.
/// MASTER·ADMIN 은 전 지점 소속이라 어느 지점을 골라도 명단에 있다.
class StaffScreen extends StatefulWidget {
  StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _query = '';
  String _rank = _allRanks;

  /// 지점은 전체로 시작한다 (내 지점만 보려면 직접 고른다)
  String _branch = _allBranches;

  /// 0 재직자 · 1 알바 · 2 퇴사자
  int _tab = 0;

  /// 카드 보기(true) · 목록 보기(false)
  bool _grid = true;

  bool _loading = !_staffLoaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadStaff();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  _Employment get _employment => _Employment.values[_tab];

  /// 지점 + 재직 상태까지만 걸러낸 명단 (직급 칩 인원 수의 기준)
  List<_Member> get _scoped => _members
      .where((m) => _inBranch(m, _branch) && m.employment == _employment)
      .toList();

  List<_Member> get _visible {
    final query = _query.trim();
    return _scoped.where((m) {
      // 칩이 '관리자'면 점장·팀장이 같이 걸린다
      final group = _rankGroupOf(_rank);
      if (group != null && !group.has(m.rank)) return false;
      if (query.isEmpty) return true;
      // 이름·직급·이메일 아무 데나 걸리면 보여준다
      return m.name.contains(query) ||
          m.role.contains(query) ||
          m.email.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<void> _open(_Member member) async {
    await showFullPage<void>(context, (_) => _MemberDetail(member: member));
    // 상세에서 인사 정보를 바꿨을 수 있다 — 명단은 `_replaceMember` 가 이미
    // 갈아끼웠으므로 다시 그리기만 하면 된다
    if (mounted) setState(() {});
  }

  void _openInvites() {
    showFullPage<void>(context, (_) => _InviteKeyScreen());
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.show(context, '$label을 복사했어요');
  }

  /// 직급으로 나누지 않고 한 판에 쭉 나열한다.
  /// 머리말은 지금 무엇을 보고 있는지 알려주므로 전체일 때도 붙인다.
  List<Widget> _body(List<_Member> list) => [
    _SectionHeader(title: _rank, count: list.length),
    SizedBox(height: 12),
    if (_grid) _cards(list) else _rows(list),
  ];

  Widget _cards(List<_Member> list) => LayoutBuilder(
    builder: (context, constraints) {
      // 카드가 너무 넓어지지 않게 최소 폭 기준으로 열 수를 잡는다
      const min = 240.0;
      const gap = 16.0;
      final columns = ((constraints.maxWidth + gap) / (min + gap))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final member in list)
            SizedBox(
              width: width,
              child: _MemberCard(
                showBranch: _branch == _allBranches,
                member: member,
                onTap: () => _open(member),
                onChat: () => _openChat(context, member),
                onCopy: () => _copy('이메일', member.email),
              ),
            ),
        ],
      );
    },
  );

  Widget _rows(List<_Member> list) => Column(
    children: [
      for (final member in list)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _MemberRow(
            showBranch: _branch == _allBranches,
            member: member,
            onTap: () => _open(member),
            onChat: () => _openChat(context, member),
            onCopy: () => _copy('이메일', member.email),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '👥', title: '직원');

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    final list = _visible;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(
              title: '직원',
              subtitle: '지점 구성원을 찾아보고 바로 연락해요',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 신규 입사자의 지점·직급은 초대키가 정한다 (staff_manage.dart)
                  if (_canManageStaff) ...[
                    _InviteButton(onTap: _openInvites),
                    SizedBox(width: 8),
                  ],
                  // 지점은 한 번에 한 곳만 보므로 목록에서 골라 바꾼다
                  _BranchPicker(
                    selected: _branch,
                    onSelect: (branch) => setState(() {
                      _branch = branch;
                      _rank = _allRanks;
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),
            _MyCard(branch: _branch),
            SizedBox(height: 16),
            // 재직 상태를 오른쪽 끝에 맞춰 아래 검색+보기 전환과 한 기둥으로 세운다.
            // 폭 340 = 검색 240 + 간격 8 + 보기 전환 92 (오른쪽 선이 정확히 맞는다)
            Row(
              children: [
                Spacer(),
                SizedBox(
                  width: 340,
                  child: SegmentedTabs(
                    labels: [
                      for (final e in _Employment.values)
                        '${e.label} ${_members.where((m) => _inBranch(m, _branch) && m.employment == e).length}',
                    ],
                    selected: _tab,
                    onSelect: (i) => setState(() {
                      _tab = i;
                      _rank = _allRanks;
                    }),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // 직급 필터와 검색·보기 전환을 한 줄에 — 고르는 일이 한자리에 모인다
            Row(
              children: [
                Expanded(
                  child: _RankChips(
                    scope: _scoped,
                    selected: _rank,
                    onSelect: (rank) => setState(() => _rank = rank),
                  ),
                ),
                SizedBox(width: 12),
                _SearchBar(onChanged: (q) => setState(() => _query = q)),
                SizedBox(width: 8),
                _ViewToggle(
                  grid: _grid,
                  onChanged: (value) => setState(() => _grid = value),
                ),
              ],
            ),
            SizedBox(height: 22),
            if (list.isEmpty)
              EmptyCard(
                icon: CupertinoIcons.person_2,
                text: switch (_employment) {
                  _Employment.partTime => '알바가 없어요',
                  _Employment.left => '퇴사한 사람이 없어요',
                  _ => '찾는 직원이 없어요',
                },
              )
            else
              ..._body(list),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 내 프로필 요약
// ---------------------------------------------------------------------------

/// 맨 위 내 카드 — 내가 누구인지와 지점 규모를 같이 보여준다
class _MyCard extends StatelessWidget {
  _MyCard({required this.branch});

  /// 보고 있는 지점 — 동료·직급 수를 이 지점 기준으로 센다
  final String branch;

  @override
  Widget build(BuildContext context) {
    final mine = _meOrSelf;
    // '전체'를 보고 있으면 전사를 센다 — 지점을 고르면 그 지점만
    final here = _members
        .where((m) => m.active && _inBranch(m, branch))
        .toList();
    final ranks = {for (final m in here) m.rank}.length;
    final working = here.where((m) => m.status.present).length;

    return Container(
      decoration: AppDecorations.card(radius: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // 내 카드임을 알리는 브랜드 띠
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Row(
                children: [
                  _StatusAvatar(member: mine, size: 62),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '내 프로필',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 6),
                            _PermissionTag(permission: mine.permission),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(mine.name, style: AppTextStyles.title2),
                        // 목업에 없는 계정으로 로그인하면 지점을 모른다.
                        // 빈 값을 그대로 이으면 ' · 대표' 처럼 앞이 비어 보인다
                        if (_subtitle(mine).isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            _subtitle(mine),
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: 2),
                        Text(mine.email, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  _count('동료', here.where((m) => !m.isMe).length),
                  _divider(),
                  _count('직급', ranks),
                  _divider(),
                  _count('근무중', working, color: AppColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// '강남점 · 대표' — 모르는 값은 빼고 잇는다
  String _subtitle(_Member member) =>
      [member.branchLabel, member.role].where((s) => s.isNotEmpty).join(' · ');

  Widget _count(String label, int value, {Color? color}) => SizedBox(
    width: 74,
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.title1.copyWith(
            fontSize: 26,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 34, color: AppColors.gray100);
}

// ---------------------------------------------------------------------------
// 검색 · 필터 · 보기 전환
// ---------------------------------------------------------------------------

/// 지점 고르기 — 지점이 하나뿐이면 글자만 보여준다
class _BranchPicker extends StatelessWidget {
  _BranchPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.location_solid, size: 14, color: AppColors.gray500),
        SizedBox(width: 6),
        Text(
          selected == _allBranches ? '전체 지점' : selected,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (_branches.length > 1) ...[
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.gray500,
          ),
        ],
      ],
    );

    final box = Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(widthFactor: 1, child: label),
    );

    if (_branches.length < 2) return box;

    return PopupMenuButton<String>(
      onSelected: onSelect,
      tooltip: '',
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gray100),
      ),
      itemBuilder: (context) => [
        for (final branch in _branches)
          PopupMenuItem(
            value: branch,
            height: 42,
            child: Row(
              children: [
                Text(
                  branch,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: branch == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: branch == selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                Text(
                  '${_members.where((m) => _inBranch(m, branch) && m.active).length}명',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
      child: box,
    );
  }
}

class _SearchBar extends StatefulWidget {
  _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // 흰 카드와 겹쳐 보이지 않게 배경 위에 눕히는 회색 면
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 15, color: AppColors.gray500),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.body2.copyWith(fontSize: 14),
              cursorColor: AppColors.primary,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: '이름·이메일 검색',
                hintStyle: AppTextStyles.body2.copyWith(
                  fontSize: 14,
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 필터 — 팀 이름 옆에 인원 수를 같이 보여준다
class _RankChips extends StatelessWidget {
  _RankChips({
    required this.scope,
    required this.selected,
    required this.onSelect,
  });

  /// 지금 보고 있는 지점·재직 상태의 명단
  final List<_Member> scope;
  final String selected;
  final ValueChanged<String> onSelect;

  int _countOf(String rank) {
    final group = _rankGroupOf(rank);
    if (group == null) return scope.length; // '전체'
    return scope.where((m) => group.has(m.rank)).length;
  }

  @override
  Widget build(BuildContext context) {
    // 탭을 옮길 때마다 칩이 늘었다 줄었다 하면 자리를 못 외운다.
    // 직급은 항상 같은 자리에 두고, 아무도 없으면 0으로 알린다.
    //
    // **접지 않고 가로로 민다.** 사이드바에 마우스를 올리면 폭이 160 줄어드는데,
    // 접히게 두면 마지막 칩만 아랫줄로 내려가고 옆 검색창 밑에 구멍이 남는다.
    // 폭이 넉넉하면 지금과 똑같이 한 줄로 보이고, 좁을 때만 밀어서 본다.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 칩이 눌릴 때 살짝 커지는데(Pressable) 잘리지 않게 위아래를 조금 띄운다
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final rank in _ranks) ...[
            if (rank != _ranks.first) SizedBox(width: 8),
            Builder(
              builder: (context) {
                final count = _countOf(rank);
                final on = rank == selected;
                // 비어 있는 직급은 눌러도 볼 게 없어 한 톤 흐리게 둔다
                final empty = count == 0 && !on;

                return Pressable(
                  onTap: () => onSelect(rank),
                  scale: 0.96,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 140),
                    height: 38,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // 칸이 남는 폭을 다 먹지 않게 내용만큼만 잡는다
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rank,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? Colors.white
                                : empty
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '$count',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? Colors.white.withValues(alpha: 0.8)
                                : empty
                                ? AppColors.gray300
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 보기 · 목록 보기 전환
class _ViewToggle extends StatelessWidget {
  _ViewToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        children: [
          _button(Icons.grid_view_rounded, true),
          _button(Icons.format_list_bulleted_rounded, false),
        ],
      ),
    );
  }

  Widget _button(IconData icon, bool value) {
    final selected = grid == value;
    return Pressable(
      onTap: () => onChanged(value),
      scale: 0.94,
      child: Container(
        width: 42,
        alignment: Alignment.center,
        decoration: segmentFill(selected: selected),
        child: Icon(
          icon,
          size: 17,
          color: selected ? AppColors.textPrimary : AppColors.gray500,
        ),
      ),
    );
  }
}

/// 팀 머리말 — 이름 + 인원 + 나머지 폭을 채우는 헤어라인
class _SectionHeader extends StatelessWidget {
  _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(width: 8),
        Text('$count명', style: AppTextStyles.caption),
        SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: AppColors.gray200)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 명단 카드 · 줄
// ---------------------------------------------------------------------------

/// 아바타 우하단에 상태 점을 붙인 아바타
class _StatusAvatar extends StatelessWidget {
  _StatusAvatar({required this.member, this.size = 44});

  final _Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.29;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Avatar(name: member.name, size: size, imageUrl: member.avatarUrl),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: member.status.color,
                shape: BoxShape.circle,
                // 아바타 색과 붙어 보이지 않게 배경색으로 테를 두른다
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatefulWidget {
  _MemberCard({
    required this.showBranch,
    required this.member,
    required this.onTap,
    required this.onChat,
    required this.onCopy,
  });

  /// 전체 지점을 보고 있을 때만 어느 지점 사람인지 같이 보여준다
  final bool showBranch;

  final _Member member;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onCopy;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _hovered = false;

  /// 상태마다 할 수 있는 일이 다르다 — 퇴사자는 연락처만, 나머지는 대화.
  ///
  /// **알바도 재직자와 같다.** 일하는 사람이라 대화를 걸 수 있어야 한다.
  /// 퇴사 처리는 인사 정보 변경 화면에 있다 (staff_manage.dart).
  List<Widget> _actions() {
    final member = widget.member;
    final copy = _IconAction(
      icon: CupertinoIcons.doc_on_doc,
      onTap: widget.onCopy,
    );

    if (member.employment == _Employment.left) {
      return [
        Expanded(
          child: _SmallButton(label: '연락처 보기', onTap: widget.onTap),
        ),
        SizedBox(width: 8),
        copy,
      ];
    }

    return [
      Expanded(child: _ChatButton(onTap: widget.onChat)),
      SizedBox(width: 8),
      copy,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            // 커서를 올린 카드만 테두리에 색을 준다
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.gray100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusAvatar(member: member),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title3,
                              ),
                            ),
                            if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.showBranch
                              ? '${member.branchLabel} · ${member.role}'
                              : member.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  // 직급은 머리말에 이미 있으니 여기는 권한을 보여준다
                  _PermissionTag(permission: member.permission),
                ],
              ),
              SizedBox(height: 14),
              Text(
                member.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              _StatusLine(member: member),
              SizedBox(height: 14),
              Row(children: _actions()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 목록 보기 한 줄 — 카드와 같은 정보를 가로로 편다
class _MemberRow extends StatefulWidget {
  _MemberRow({
    required this.showBranch,
    required this.member,
    required this.onTap,
    required this.onChat,
    required this.onCopy,
  });

  /// 전체 지점을 보고 있을 때만 어느 지점 사람인지 같이 보여준다
  final bool showBranch;

  final _Member member;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onCopy;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.995,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.gray100,
            ),
          ),
          child: Row(
            children: [
              _StatusAvatar(member: member, size: 40),
              SizedBox(width: 14),
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title3.copyWith(fontSize: 16),
                      ),
                    ),
                    if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                  ],
                ),
              ),
              SizedBox(
                width: widget.showBranch ? 148 : 96,
                child: Text(
                  widget.showBranch
                      ? '${member.branchLabel} · ${member.role}'
                      : member.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              _PermissionTag(permission: member.permission),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(width: 160, child: _StatusBadge(member: member)),
              SizedBox(width: 12),
              _ChatButton(onTap: widget.onChat),
              SizedBox(width: 8),
              _IconAction(
                icon: CupertinoIcons.doc_on_doc,
                onTap: widget.onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사내톡 열기 버튼
class _ChatButton extends StatelessWidget {
  _ChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        // 카드마다 있는 버튼이라 진한 파랑이면 화면이 파랗게 도배된다.
        // 연한 파랑 면에 파란 글씨로 눌러 둔다.
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_fill,
              size: 14,
              color: AppColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              '메시지',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 글자만 있는 작은 버튼
class _SmallButton extends StatelessWidget {
  _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 정사각 아이콘 버튼 (이메일 복사 등)
class _IconAction extends StatelessWidget {
  _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 15, color: AppColors.gray600),
      ),
    );
  }
}

/// 권한 꼬리표 — 관리 권한이 있는 사람만 파랗게
class _PermissionTag extends StatelessWidget {
  _PermissionTag({required this.permission});

  final Role permission;

  @override
  Widget build(BuildContext context) {
    final strong = permission.strong;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: strong ? Colors.transparent : AppColors.gray100,
        ),
      ),
      child: Text(
        permission.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: strong ? AppColors.primary : AppColors.gray500,
        ),
      ),
    );
  }
}

/// 로그인한 사람 표시
class _MeTag extends StatelessWidget {
  _MeTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '나',
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 카드 한 줄짜리 상태 표시
///
/// 재직자는 지금 무엇을 하는지, 대기자는 무엇을 기다리는지,
/// 퇴사자는 언제 나갔는지를 같은 자리에 보여준다.
class _StatusLine extends StatelessWidget {
  _StatusLine({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    if (member.employment == _Employment.left) {
      final at = member.resigned;
      // 서버가 퇴사일을 주기 전에 나간 사람은 날짜가 비어 있다
      return _line(
        AppColors.gray400,
        '퇴사',
        at == null ? '기록은 남아 있어요' : '${_date(at)}에 나갔어요',
      );
    }
    return _StatusBadge(member: member);
  }

  Widget _line(Color color, String label, String note) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 7),
      Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          '· $note',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ),
    ],
  );
}

/// 상태 점 + 이름 (+ 상태 메시지)
class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final status = member.status;

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 7),
        Text(
          status.label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: status.color,
          ),
        ),
        if (member.note != null) ...[
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '· ${member.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 상세
// ---------------------------------------------------------------------------

/// 직원 한 명 상세 — 연락처와 이번 달 근태 요약
///
/// 근태 요약은 열 때 따로 받는다. 명단과 같이 받으면 인원수만큼 요청이 나간다.
class _MemberDetail extends StatefulWidget {
  _MemberDetail({required this.member});

  final _Member member;

  @override
  State<_MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<_MemberDetail> {
  _MonthSummary? _month;
  bool _loading = false;

  /// 인사 정보를 바꿨으면 갈아끼운 사람 — 닫을 때 명단으로 돌려준다
  _Member? _edited;

  _Member get member => _edited ?? widget.member;

  /// 남의 근태를 볼 수 있는지
  ///
  /// 서버가 `/attendance/calendar`·`/leaves/balance` 를 **점장 이상**에게만 연다
  /// (일반 직원이 부르면 403). 지각 횟수는 원래 남이 볼 것도 아니라
  /// 앱도 같은 기준으로 카드를 감춘다.
  bool get _canSeeMonth => member.isMe || myRole.strong;

  @override
  void initState() {
    super.initState();
    if (member.active && _canSeeMonth) _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    try {
      final days = AttendanceApi.calendar(
        month: month,
        employeeId: member.isMe ? null : member.id,
      );
      final balance = AttendanceApi.balance(
        employeeId: member.isMe ? null : member.id,
      );
      final summary = _MonthSummary.of(await days, await balance);
      if (mounted) setState(() => _month = summary);
    } catch (_) {
      // 권한이 없거나 서버가 못 주면 카드를 안 그린다
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.show(context, '$label을 복사했어요');
  }

  /// 지점·직급·권한 바꾸기 (MASTER·ADMIN 만)
  Future<void> _manage() async {
    final saved = await showFullPage<Employee>(
      context,
      (_) => _ManageSheet(member: member),
    );
    if (saved == null || !mounted) return;
    _replaceMember(saved);
    setState(() => _edited = _Member(saved));
    AppToast.show(context, '${saved.name}님의 인사 정보를 바꿨어요');
  }

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: member.name,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          _ProfileCard(member: member),
          SizedBox(height: 12),
          Row(
            children: [
              // 아직 합류 전이거나 이미 나간 사람에게는 사내톡을 걸지 않는다
              if (member.active) ...[
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.chat_bubble_fill,
                    label: '사내톡',
                    primary: true,
                    onTap: () => _openChat(context, member),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.phone_fill,
                  label: '번호 복사',
                  onTap: () => _copy(context, '전화번호', member.phone),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.mail_solid,
                  label: '메일 복사',
                  onTap: () => _copy(context, '이메일', member.email),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: '기본 정보',
            // 지점·직급·권한은 남이 정해 주는 값이라 여기서 바꾼다
            // (본인이 바꾸는 이름·전화번호는 프로필 화면이다)
            action: _canManage(member) ? ('인사 정보 변경', _manage) : null,
            rows: [
              ('사번', member.code),
              ('지점', member.branchLabel),
              ('직급', member.role),
              ('권한', member.permission.label),
              ('상태', member.employment.label),
              if (member.joined case final at?) ('입사일', _date(at)),
              if (member.resigned case final at?) ('퇴사일', _date(at)),
              if (member.active && member.joined != null) ('근속', member.career),
              // 서버가 전화번호를 안 채워 주는 사람이 많다 (backend-gap.md 2·46번)
              ('전화번호', member.phone.isEmpty ? '없음' : member.phone),
              ('이메일', member.email),
            ],
          ),
          // 비활성·퇴사자는 이번 달 기록이 없다.
          // 남의 근태는 점장 이상만 본다 ([_canSeeMonth])
          if (member.active && _canSeeMonth) ...[
            SizedBox(height: 12),
            if (_month case final summary?)
              _MonthCard(summary: summary)
            else if (_loading)
              _MonthPlaceholder(),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  _ProfileCard({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          _StatusAvatar(member: member, size: 62),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name, style: AppTextStyles.title2),
                    if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  member.role,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10),
                _StatusLine(member: member),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 가장 자주 쓰는 동작 하나만 파란 면으로
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? Colors.white : AppColors.textPrimary;

    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? AppColors.primary : AppColors.gray200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  _InfoCard({required this.title, required this.rows, this.action});

  final String title;
  final List<(String, String)> rows;

  /// 머리말 오른쪽에 붙는 글자 버튼 — (이름, 누르면 할 일)
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.label),
              if (action case (final label, final onTap)) ...[
                Spacer(),
                Pressable(
                  onTap: onTap,
                  scale: 0.96,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 6),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(label, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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

/// 근태를 받아오는 동안 자리만 잡아 둔다 — 카드가 뒤늦게 끼어들면 화면이 튄다
class _MonthPlaceholder extends StatelessWidget {
  _MonthPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 106,
      alignment: Alignment.center,
      decoration: AppDecorations.card(),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.gray300),
        ),
      ),
    );
  }
}

/// 이번 달 근태 요약 값 — `/attendance/calendar` 와 `/leaves/balance` 로 만든다
///
/// 판정(정상·지각·결근…)은 **서버가 한 것을 그대로 센다.** 급여·평가가 같은
/// 기준을 쓰므로 앱이 다시 계산하지 않는다.
class _MonthSummary {
  _MonthSummary({
    required this.workedDays,
    required this.workedHours,
    required this.lateCount,
    required this.leaveUsed,
  });

  factory _MonthSummary.of(List<AttendanceDay> days, LeaveBalance balance) {
    var worked = 0;
    var minutes = 0;
    var late = 0;
    for (final day in days) {
      // 출근한 날만 센다 — 휴무·휴가·결근은 근무일이 아니다
      if (day.checkIn != null) worked++;
      minutes += day.workMinutes ?? 0;
      if (day.status == AttendanceStatus.late ||
          day.status == AttendanceStatus.lateAndEarly) {
        late++;
      }
    }
    return _MonthSummary(
      workedDays: worked,
      workedHours: minutes ~/ 60,
      lateCount: late,
      leaveUsed: balance.used,
    );
  }

  final int workedDays;
  final int workedHours;
  final int lateCount;
  final double leaveUsed;
}

/// 이번 달 근태 요약 — 근태·월차 화면의 요약 카드와 같은 눈금
class _MonthCard extends StatelessWidget {
  _MonthCard({required this.summary});

  final _MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 근무',
                  style: AppTextStyles.label,
                ),
              ),
              Text('오늘까지', style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '${summary.workedDays}일', AppColors.textPrimary),
              _divider(),
              _stat('총 근무', '${summary.workedHours}시간', AppColors.primary),
              _divider(),
              _stat(
                '지각',
                '${summary.lateCount}회',
                summary.lateCount > 0
                    ? AppColors.warning
                    : AppColors.textPrimary,
              ),
              _divider(),
              _stat(
                '월차',
                '${_count(summary.leaveUsed)}일',
                AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

/// '2023년 3월 2일'
String _date(DateTime value) => '${value.year}년 ${value.month}월 ${value.day}일';

/// 소수점이 있을 때만 .5를 보여준다
String _count(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toString();
