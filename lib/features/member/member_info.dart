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
import '../../core/util/skeleton_delay.dart';
import '../../core/util/when.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/widgets/input/mode_switch.dart';
import 'member_edit.dart';

/// 회원 정보 — 업무 화면 헤더 **왼쪽 끝 사람 버튼**으로 들어온다
///
/// **운동일지 화면(`MemberScreen`)과 다른 자리다.** 저기는 수업 흐름이라
/// 회원을 고르면 일지가 열리는데, 여기는 **회원 자체를 보는 곳**이다 —
/// 남은 회차로 활성·만료를 갈라 보고, 눌러서 인적 사항을 고치거나 지운다.
class MemberInfoScreen extends StatefulWidget {
  const MemberInfoScreen({super.key});

  @override
  State<MemberInfoScreen> createState() => _MemberInfoScreenState();
}

/// 남은 회차가 있나 — 두 갈래뿐이다
enum _Bucket {
  active('활성'),
  expired('만료');

  const _Bucket(this.label);

  final String label;
}

class _MemberInfoScreenState extends State<MemberInfoScreen>
    with SkeletonDelay<MemberInfoScreen> {
  List<_Row> _rows = const [];
  _Bucket _bucket = _Bucket.active;

  /// 남의 회원까지 보는 사람인가 — 대표·관리자
  bool get _seesAll => myRole.boss;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = currentUser;
    if (me == null) return;
    setState(beginLoad);
    try {
      // 대표·관리자만 null — 나머지는 서버가 본인 담당으로 줄여 준다
      final members = MemberApi.list(
        branchId: branchScopeId,
        ownerTrainerId: _seesAll ? null : me.id,
      );
      // 회차는 회원 응답에 없다 — 등록권을 같이 받아 앱에서 id 로 맞춘다.
      // 판 사람으로 거르지 않는다 — 담당이 바뀌면 남은 회차가 사라진다
      final registrations = await RegistrationApi.list();
      final rows = await members;
      if (!mounted) return;
      // 한 회원에게 등록권이 여러 장이면 **최근 것**이 지금 상태다
      final latest = <String, Registration>{};
      for (final r in registrations) {
        final kept = latest[r.memberId];
        if (kept == null || r.purchasedAt.isAfter(kept.purchasedAt)) {
          latest[r.memberId] = r;
        }
      }
      setState(() {
        _rows = [
          for (final m in rows) _Row(source: m, registration: latest[m.id]),
        ]..sort((a, b) => a.source.name.compareTo(b.source.name));
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  List<_Row> get _visible => [
    for (final row in _rows)
      if (row.bucket == _bucket) row,
  ];

  /// 회원 하나를 연다 — 고치거나 지우면 목록을 다시 받는다
  Future<void> _open(_Row row) async {
    final changed = await showFullPage<bool>(
      context,
      (_) => _MemberInfoDetail(row: row),
    );
    if (changed == true && mounted) await _load();
  }

  int _count(_Bucket bucket) =>
      _rows.where((row) => row.bucket == bucket).length;

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return PhoneDetailScaffold(
      title: '회원 정보',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          SegmentedTabs(
            labels: [for (final b in _Bucket.values) '${b.label} ${_count(b)}'],
            selected: _Bucket.values.indexOf(_bucket),
            onSelect: (i) => setState(() => _bucket = _Bucket.values[i]),
          ),
          const SizedBox(height: 16),
          if (showSkeleton)
            const _ListSkeleton()
          else if (rows.isEmpty)
            EmptyCard(
              icon: Icons.people_alt_rounded,
              text: _bucket == _Bucket.active
                  ? '회차가 남은 회원이 없어요'
                  : '만료된 회원이 없어요',
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _MemberRowCard(
                row: rows[i],
                showTrainer: _seesAll,
                onTap: () => _open(rows[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 회원 한 명 + 지금 등록권
class _Row {
  const _Row({required this.source, required this.registration});

  final Member source;

  /// 등록권이 하나도 없으면 null — 아직 끊은 수업이 없다
  final Registration? registration;

  int get total => registration?.totalSessions ?? 0;

  int get used => registration?.usedSessions ?? 0;

  /// **등록권이 없으면 만료로 본다** — 남은 회차가 0인 것과 같은 자리다
  _Bucket get bucket => registration != null && !registration!.exhausted
      ? _Bucket.active
      : _Bucket.expired;

  String get trainerName =>
      StaffDirectory.instance.byId(source.ownerTrainerId)?.name ?? '';

  String get branchName => StaffDirectory.instance.branchName(source.branchId);
}

/// 목록 한 줄 — 운동일지 화면의 회원 카드와 같은 모양
class _MemberRowCard extends StatelessWidget {
  const _MemberRowCard({
    required this.row,
    required this.showTrainer,
    required this.onTap,
  });

  final _Row row;

  /// 담당 트레이너를 적을지 — 대표·관리자만 본다 (나머지는 다 본인이다)
  final bool showTrainer;

  final VoidCallback onTap;

  String get _caption {
    if (showTrainer) {
      final trainer = row.trainerName.isEmpty ? '담당 없음' : row.trainerName;
      return row.branchName.isEmpty ? trainer : '$trainer · ${row.branchName}';
    }
    return row.source.phone;
  }

  @override
  Widget build(BuildContext context) {
    final active = row.bucket == _Bucket.active;
    final color = row.registration == null
        ? AppColors.gray400
        : active
        ? AppColors.primary
        : AppColors.success;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Avatar(name: row.source.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.source.name} 회원님',
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

/// 회원 정보 한 장 — 인적 사항과 등록권, 그리고 수정·삭제
///
/// 일지는 안 그린다. 그건 운동일지 화면이 하는 일이다.
class _MemberInfoDetail extends StatefulWidget {
  const _MemberInfoDetail({required this.row});

  final _Row row;

  @override
  State<_MemberInfoDetail> createState() => _MemberInfoDetailState();
}

class _MemberInfoDetailState extends State<_MemberInfoDetail> {
  late Member _member = widget.row.source;

  /// 목록을 다시 받아야 하나 — 고쳤거나 지웠으면 true 로 닫는다
  bool _changed = false;

  /// 고치고 지울 수 있는 사람인가 — **담당 트레이너 본인과 대표·관리자**
  /// (서버 `_ensure_mine` 과 같은 규칙이다)
  bool get _canEdit => myRole.boss || currentUser?.id == _member.ownerTrainerId;

  Future<void> _edit() async {
    final result = await showMemberEdit(context, _member);
    if (!mounted || result == null) return;
    if (result == MemberEditResult.deleted) {
      Navigator.pop(context, true);
      return;
    }
    try {
      final fresh = await MemberApi.detail(_member.id);
      if (!mounted) return;
      setState(() {
        _member = fresh;
        _changed = true;
      });
      AppToast.show(context, '고쳤어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final trainer =
        StaffDirectory.instance.byId(_member.ownerTrainerId)?.name ?? '없음';
    final branch = StaffDirectory.instance.branchName(_member.branchId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: PhoneDetailScaffold(
        title: '${_member.name} 회원님',
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            bottomBarInset(context),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Avatar(name: _member.name, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _member.name,
                              style: AppTextStyles.title3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _member.phone,
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canEdit)
                        Pressable(
                          onTap: _edit,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: _EditLabel(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Field(label: '담당 트레이너', value: trainer),
                  if (branch.isNotEmpty) _Field(label: '지점', value: branch),
                  _Field(
                    label: '등록일',
                    value: fullDateLabel(_member.registeredAt),
                  ),
                  _Field(
                    label: '방문 경로',
                    value: _member.visitPath?.label ?? '기록 없음',
                  ),
                  _Field(
                    label: '남은 회차',
                    value: row.registration == null
                        ? '등록권 없음'
                        : '${row.total - row.used}회 (${row.used}/${row.total})',
                  ),
                  if (_member.memo case final memo? when memo.trim().isNotEmpty)
                    _Field(label: '메모', value: memo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel();

  @override
  Widget build(BuildContext context) => Text(
    '수정',
    style: AppTextStyles.caption.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// 카드 안 한 줄 — 왼쪽 이름표, 오른쪽 값
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

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
