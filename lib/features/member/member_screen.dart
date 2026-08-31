import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/lesson_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/screen_refresh.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/glass/glass_search_bar.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../work/lesson/lesson_section.dart' show showMemberRegister;
import 'member_detail.dart';

/// 회원 관리 — 센터 회원 목록
///
/// ## 누가 무엇을 보나
///
/// | 권한 | 목록 | 담당 트레이너 |
/// |---|---|---|
/// | MASTER · ADMIN | 지점 스코프 안의 **모든 회원** | 줄마다 같이 적는다 |
/// | MANAGER · MEMBER | **본인이 담당하는 회원만** | 다 본인이라 안 적는다 |
///
/// 점장(MANAGER)을 관리자 쪽에 두지 않는다. 점장도 수업을 뛰어서 본인 담당이
/// 따로 있고, 남의 회원까지 섞이면 정작 제 회원을 못 찾는다.
///
/// **거르는 일은 서버가 한다** (`ownerTrainerId`). 앱에서 받아 놓고 숨기면
/// 목록에 없는 회원이 응답에는 실려 오게 된다.
///
/// ## 회원과 트레이너의 짝
///
/// `members.ownerTrainerId` 하나로 정해진다. 회원 등록 화면이 그 값을 등록한
/// 트레이너 본인으로 넣으므로 따로 매핑 테이블을 두지 않는다.
class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

/// 목록을 거르는 기준 — 남은 회차가 있나
enum _Filter {
  all('전체'),
  active('진행 중'),
  done('종료');

  const _Filter(this.label);

  final String label;
}

class _MemberScreenState extends State<MemberScreen>
    with ScreenRefresh<MemberScreen>, SkeletonDelay<MemberScreen> {
  final _search = TextEditingController();

  List<_MemberRow> _rows = const [];
  _Filter _filter = _Filter.all;

  /// 남의 회원까지 보는 사람인가 — 대표·관리자
  bool get _seesAll => myRole.boss;

  /// 회원을 등록하는 사람인가 — 직원·점장 (대표·관리자는 수업을 안 한다)
  bool get _canRegister => myRole.doesFieldWork;

  /// 검색칸을 세울 만큼 목록이 긴가 — 몇 명뿐인데 칸이 뜨면 자리만 먹는다
  bool get _searchable => _rows.length >= 6;

  @override
  void initState() {
    super.initState();
    // 글자를 지울 때까지 기다리지 않고 한 자마다 걸러 준다
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> onScreenRefresh() => _load();

  Future<void> _load() async {
    final me = currentUser;
    if (me == null) return;
    // 대표·관리자만 null — 나머지는 서버가 본인 담당으로 줄여 준다
    final owner = _seesAll ? null : me.id;
    try {
      // 회차는 회원 응답에 없다 — 등록권을 같이 받아 앱에서 id 로 맞춘다
      final memberRequest = MemberApi.list(
        branchId: branchScopeId,
        ownerTrainerId: owner,
      );
      // 판 사람으로 거르지 않는다 — 담당이 바뀌면 남은 회차가 사라진다
      final registrationRequest = RegistrationApi.list();
      final members = await memberRequest;
      final registrations = await registrationRequest;
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final member in members)
            _MemberRow(
              source: member,
              registration: _currentOf(registrations, member.id),
            ),
        ];
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 지금 쓰는 등록권 — 회차가 남은 것 중 먼저 산 것, 없으면 마지막 것
  ///
  /// 다 쓰기 전에 재등록하면 등록권이 잠깐 둘이 된다. 남은 회차를 흘리지
  /// 않으려면 먼저 산 것부터 쓴다 (수업 화면과 같은 규칙).
  static Registration? _currentOf(List<Registration> rows, String memberId) {
    Registration? active;
    Registration? latest;
    for (final row in rows) {
      if (row.memberId != memberId) continue;
      if (latest == null || row.purchasedAt.isAfter(latest.purchasedAt)) {
        latest = row;
      }
      if (row.exhausted) continue;
      if (active == null || row.purchasedAt.isBefore(active.purchasedAt)) {
        active = row;
      }
    }
    return active ?? latest;
  }

  /// 검색어·필터를 통과한 줄
  ///
  /// 서버 `?q=` 는 이름만 보는데, 대표는 '이 트레이너가 누굴 맡았나'로도
  /// 찾는다. 목록이 이미 손에 있으니 여기서 같이 거른다.
  List<_MemberRow> get _visible {
    final query = _search.text.trim();
    return [
      for (final row in _rows)
        if (_filter.matches(row) && row.matches(query)) row,
    ];
  }

  Future<void> _register() async {
    final added = await showMemberRegister(context);
    if (added == true && mounted) await _load();
  }

  Future<void> _open(_MemberRow row) async {
    final changed = await showFullPage<bool>(
      context,
      (_) => MemberDetailScreen(member: row.source),
    );
    if (changed == true && mounted) await _load();
  }

  /// 목록 위 한 줄 — 지금 무엇을 보고 있는지 (권한마다 범위가 다르다)
  String get _scopeLabel {
    final count = _visible.length;
    if (!_seesAll) return '내 담당 회원 $count명';
    final branch = branchScopeId == null ? '전 지점' : branchScopeName;
    return '$branch 회원 $count명';
  }

  Widget _body() {
    if (showSkeleton) return const _MemberSkeleton();
    final rows = _visible;
    if (rows.isEmpty) {
      return EmptyCard(
        icon: Icons.people_alt_rounded,
        text: _rows.isEmpty
            ? (_seesAll ? '등록된 회원이 없어요' : '담당하는 회원이 없어요')
            : '찾는 회원이 없어요',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _MemberCard(
            row: rows[i],
            showTrainer: _seesAll,
            onTap: () => _open(rows[i]),
          ),
        ],
      ],
    );
  }

  /// 제목 아래 공통 머리 — 범위 안내 + 필터
  List<Widget> _header() => [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        _scopeLabel,
        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
      ),
    ),
    SegmentedTabs(
      labels: [for (final f in _Filter.values) f.label],
      selected: _Filter.values.indexOf(_filter),
      onSelect: (index) => setState(() => _filter = _Filter.values[index]),
    ),
    const SizedBox(height: 16),
  ];

  @override
  Widget build(BuildContext context) {
    final search = _searchable
        ? GlassSearchBar(
            controller: _search,
            hint: _seesAll ? '회원 · 담당 트레이너' : '회원 이름',
          )
        : null;

    if (!isDesktop) {
      return PhoneDetailScaffold(
        title: '회원 관리',
        // **머리말에 회원 추가를 안 둔다** (2026-08-31 대표 요청) — 이 화면은
        // 업무 탭 '수업 개수' 의 `운동 일지` 로 들어오는데, 바로 옆에 `회원
        // 등록` 버튼이 이미 서 있어서 같은 일이 두 자리에 있었다.
        bottomBar: search,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            // 검색칸이 떠 있으면 마지막 카드가 그 아래로 숨는다
            bottomBarInset(context) + (search == null ? 0 : 64),
          ),
          children: [..._header(), _body()],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(28, 26, 28, search == null ? 26 : 90),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 18),
                child: Row(
                  children: [
                    Text('회원 관리', style: AppTextStyles.title3),
                    const Spacer(),
                    if (_canRegister)
                      AppButton(
                        label: '회원 등록',
                        onTap: _register,
                        filled: true,
                        shrinkWrap: true,
                      ),
                  ],
                ),
              ),
              ..._header(),
              _body(),
            ],
          ),
          ?search,
        ],
      ),
    );
  }
}

/// 목록 한 줄 — 회원에 지금 쓰는 등록권과 담당 트레이너 이름을 붙인 것
class _MemberRow {
  _MemberRow({required this.source, required this.registration});

  final Member source;

  /// 등록권이 하나도 없는 회원이면 null — 아직 끊은 수업이 없다
  final Registration? registration;

  String get name => source.name;

  /// 담당 트레이너 이름 — 서버는 id 만 주므로 명단에서 찾는다.
  /// 퇴사자라 명단에 없으면 빈 값이고, 그 줄은 이름을 안 그린다.
  String get trainerName =>
      StaffDirectory.instance.byId(source.ownerTrainerId)?.name ?? '';

  String get branchName => StaffDirectory.instance.branchName(source.branchId);

  int get total => registration?.totalSessions ?? 0;

  int get used => registration?.usedSessions ?? 0;

  /// 아직 남은 회차가 있나 — 등록권이 없으면 종료로 본다
  bool get active => registration != null && !registration!.exhausted;

  /// 이름·전화·담당 트레이너 중 하나라도 걸리면 통과
  bool matches(String query) {
    if (query.isEmpty) return true;
    return name.contains(query) ||
        source.phone.contains(query) ||
        trainerName.contains(query);
  }
}

extension on _Filter {
  bool matches(_MemberRow row) => switch (this) {
    _Filter.all => true,
    _Filter.active => row.active,
    _Filter.done => !row.active,
  };
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.row,
    required this.showTrainer,
    required this.onTap,
  });

  final _MemberRow row;

  /// 담당 트레이너를 적을지 — 대표·관리자만 본다 (나머지는 다 본인이다)
  final bool showTrainer;

  final VoidCallback onTap;

  /// 두 번째 줄 — 대표는 '누가 맡았나', 담당자는 '언제 왔나'가 궁금하다
  String get _caption {
    if (showTrainer) {
      final trainer = row.trainerName.isEmpty ? '담당 없음' : row.trainerName;
      final branch = row.branchName;
      return branch.isEmpty ? trainer : '$trainer · $branch';
    }
    final path = row.source.visitPath?.label;
    final registered =
        '${row.source.registeredAt.year % 100}.'
        '${row.source.registeredAt.month}.${row.source.registeredAt.day} 등록';
    return path == null ? registered : '$registered · $path';
  }

  @override
  Widget build(BuildContext context) {
    final color = row.registration == null
        ? AppColors.gray400
        : row.active
        ? AppColors.primary
        : AppColors.success;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Avatar(name: row.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.name} 회원님',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                row.registration == null
                    ? '등록권 없음'
                    : 'PT ${row.used}/${row.total}',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSkeleton extends StatelessWidget {
  const _MemberSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          SkeletonCard(
            children: [
              Row(
                children: [
                  SkeletonCircle(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 120, height: 14),
                        const SizedBox(height: 8),
                        Skeleton(width: 88, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Skeleton(width: 62, height: 22, radius: 10),
                ],
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
