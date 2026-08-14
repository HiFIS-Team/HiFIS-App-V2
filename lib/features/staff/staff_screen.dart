import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/attendance_api.dart';
import '../../core/api/staff/invite_key_api.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/placeholder_screen.dart';
import '../../core/widgets/display/section_header.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_menu.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../messages/chat_screen.dart';
import '../messages/chat_store.dart';
import '../../core/util/when.dart';
import '../../core/widgets/nav/pane_transition.dart';
import '../../core/widgets/feedback/failed_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/util/screen_refresh.dart';

part 'staff_manage.dart';
part 'staff_models.dart';
part 'staff_profile.dart';
part 'staff_filters.dart';
part 'staff_cards.dart';
part 'staff_detail.dart';

/// 직원 화면
///
/// 지점 구성원을 찾아보고 바로 연락하는 화면이다. 카드마다 지금 상태
/// (근무중·회의중·외출…)가 보이고, 카드를 누르면 연락처와 이번 달 근태
/// 요약이 뜬다. 폰은 아직 진입점이 없어 PC를 먼저 만든다.
///
/// 사람은 직군으로 나눈다 — 누구를 찾을 때 먼저 떠올리는 기준이다.
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

class _StaffScreenState extends State<StaffScreen>
    with ScreenRefresh<StaffScreen> {
  String _query = '';
  String _rank = _allRanks;

  /// 보고 있는 지점 — **헤더의 지점 아이콘이 정한다** (업무·랭킹과 같은 값)
  ///
  /// 예전에는 이 화면이 제 고르개를 들고 있었다. 화면마다 따로 고르는 게
  /// 번거로워서 헤더로 옮겼다 (core/data/branch_scope.dart).
  String get _branch => branchScopeName;

  /// 0 재직자 · 1 알바 · 2 퇴사자
  int _tab = 0;

  /// 카드 보기(true) · 목록 보기(false)
  bool _grid = true;

  bool _loading = !_staffLoaded;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    branchScope.addListener(_onBranchScope);
    _load();
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다
  ///
  /// 직군 필터를 같이 되돌린다 — 그 지점에 없는 직군이 걸린 채로 남으면
  /// 지점을 옮기자마자 빈 화면이 된다 (고르개가 이 화면에 있을 때와 같은 규칙).
  void _onBranchScope() {
    if (mounted) setState(() => _rank = _allRanks);
  }

  /// 못 받았다 — **목록이 비어 있을 때만** 실패 카드를 낸다.
  /// 받아 둔 목록이 있으면 그대로 보여준다 (공지와 같은 규칙).
  bool _failed = false;

  Future<void> _load() async {
    try {
      await _loadStaff();
      _failed = false;
    } catch (error) {
      _failed = true;
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  _Employment get _employment => _Employment.values[_tab];

  /// 지점 + 재직 상태까지만 걸러낸 명단 (직군 칩 인원 수의 기준)
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
      // 이름·직군·이메일 아무 데나 걸리면 보여준다
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

  /// 직군으로 나누지 않고 한 판에 쭉 나열한다.
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
      return SkeletonDesktopPage(
        children: [
          Skeleton(height: 40, radius: 12),
          SizedBox(height: 16),
          SkeletonCard(
            padding: EdgeInsets.all(20),
            children: [SkeletonRows(rows: 8, avatar: 40, trailing: 64)],
          ),
        ],
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
              // 지점 고르개는 헤더의 지점 아이콘으로 옮겼다 — 업무·랭킹과 같은
              // 값을 보므로 화면마다 두지 않는다 (core/data/branch_scope.dart)
              trailing: _canManageStaff
                  // 신규 입사자의 지점·직군은 초대키가 정한다 (staff_manage.dart)
                  ? _InviteButton(onTap: _openInvites)
                  : null,
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
            // 직군 필터와 검색·보기 전환을 한 줄에 — 고르는 일이 한자리에 모인다
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
            // 재직 상태 탭을 옮길 때 명단이 같이 갈린다
            PaneTransition(
              step: _tab,
              child: list.isEmpty
                  ? (_failed
                        ? FailedCard(onRetry: _retry)
                        : EmptyCard(
                            icon: CupertinoIcons.person_2,
                            text: switch (_employment) {
                              _Employment.partTime => '알바가 없어요',
                              _Employment.left => '퇴사한 사람이 없어요',
                              _ => '찾는 직원이 없어요',
                            },
                          ))
                  // **stretch 를 반드시 준다.** Column 의 가로 정렬 기본값은
                  // 가운데라, 카드를 담은 Wrap 이 제 내용만큼만 넓어지면서
                  // 통째로 가운데로 밀린다. 명단이 길 때는 카드가 폭을 다
                  // 채워서 티가 안 나다가, 대표·개발자처럼 **한두 명만 남으면
                  // 그 순간 가운데에서 시작한다** (실제로 그렇게 보였다).
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _body(list),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
