import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../core/widgets/display/field_rows.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/widgets/input/mode_switch.dart';
import 'member_edit.dart';
import 'member_trainers.dart';

/// 회원 정보 — 업무 화면 헤더 **왼쪽 끝 사람 버튼**으로 들어온다
///
/// **운동일지 화면(`MemberScreen`)과 다른 자리다.** 저기는 수업 흐름이라
/// 회원을 고르면 일지가 열리는데, 여기는 **회원 자체를 보는 곳**이다 —
/// 남은 회차로 활성·만료를 갈라 보고, 눌러서 인적 사항을 고치거나 지운다.
class MemberInfoScreen extends StatefulWidget {
  const MemberInfoScreen({super.key, this.trainerId});

  /// 대표·관리자가 트레이너 목록에서 고른 사람 — 그 사람의 회원만 뜬다.
  /// null 이면 대표·관리자에게는 **트레이너 목록**부터 뜬다 ([MemberTrainerList])
  final String? trainerId;

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

  /// 트레이너부터 고르는 첫 화면인가 — 대표·관리자만 (2026-09-27 대표 요청)
  bool get _picking => _seesAll && widget.trainerId == null;

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
      // 대표·관리자는 고른 트레이너(첫 화면이면 null=전부) — 나머지는 본인 담당
      final members = MemberApi.list(
        branchId: branchScopeId,
        ownerTrainerId: _seesAll ? widget.trainerId : me.id,
      );
      // 회차는 회원 응답에 없다 — 등록권을 같이 받아 앱에서 id 로 맞춘다.
      // 판 사람으로 거르지 않는다 — 담당이 바뀌면 남은 회차가 사라진다
      final registrations = await RegistrationApi.list();
      final rows = await members;
      if (!mounted) return;
      // 한 회원에게 등록권이 여러 장이면 **남은 것을 합쳐** 본다 ([MemberPass]).
      // 예전에는 최근 것 한 장만 봐서 미리 재등록하면 남은 회차가 숨었다
      setState(() {
        _rows = [
          for (final m in rows)
            _Row(source: m, pass: MemberPass.of(registrations, m.id)),
        ]..sort(_byName);
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// **이름 가나다순** (2026-09-27 대표 요청)
  ///
  /// 한동안 최근 등록순이었는데(2026-09-16), 트레이너를 골라 들어오면서
  /// 한 사람 회원만 보게 되어 이름으로 찾는 쪽이 낫다고 바꿨다.
  /// 운동 일지 목록과 같은 순서다.
  static int _byName(_Row a, _Row b) => a.source.name.compareTo(b.source.name);

  List<_Row> get _visible => [
    for (final row in _rows)
      if (row.bucket == _bucket) row,
  ];

  /// 트레이너 하나를 연다 — 지금 화면이 그 사람 회원만으로 뜬다
  Future<void> _openTrainer(String id) async {
    await showFullPage<void>(context, (_) => MemberInfoScreen(trainerId: id));
    if (mounted) await _load();
  }

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
    final padding = EdgeInsets.fromLTRB(
      20,
      PhoneDetailScaffold.topPadding,
      20,
      bottomBarInset(context),
    );
    if (_picking) {
      return PhoneDetailScaffold(
        title: '회원 정보',
        child: ListView(
          padding: padding,
          children: [
            if (showSkeleton)
              const _ListSkeleton()
            else
              MemberTrainerList(
                members: [for (final row in _rows) row.source],
                isActive: {
                  for (final row in _rows)
                    if (row.bucket == _Bucket.active) row.source.id,
                }.contains,
                onPick: _openTrainer,
              ),
          ],
        ),
      );
    }
    final trainer = widget.trainerId == null
        ? null
        : StaffDirectory.instance.byId(widget.trainerId!)?.name;
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
          // 누구의 회원인지 — 트레이너 목록에서 들어왔을 때만
          if (trainer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                '$trainer 담당 회원',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
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
              // 걸러서 빈 것과 원래 없는 것을 가른다 — 안 가르면 필터를
              // 걸어 둔 걸 잊고 "회원이 사라졌다" 로 본다
              text: widget.trainerId != null
                  ? '그 트레이너의 회원이 없어요'
                  : _bucket == _Bucket.active
                  ? '회차가 남은 회원이 없어요'
                  : '만료된 회원이 없어요',
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _MemberRowCard(
                row: rows[i],
                // 트레이너를 골라 들어왔으니 줄마다 담당을 적을 필요가 없다
                showTrainer: false,
                onTap: () => _open(rows[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// `01012345678` → `010-1234-5678`
///
/// 자릿수가 안 맞으면 **적힌 그대로** 둔다 — 예전에 손으로 넣은 값이나
/// 검사용으로 아무 글자나 넣어 둔 것이 섞여 있다.
String _phoneLabel(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}'
        '-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}'
        '-${digits.substring(6)}';
  }
  return raw.trim().isEmpty ? '없음' : raw;
}

/// 회원 한 명 + 지금 등록권
class _Row {
  const _Row({required this.source, required this.pass});

  final Member source;

  /// 합친 등록권 — 남은 등록권을 다 더한 회차다 ([MemberPass])
  final MemberPass pass;

  /// 가장 최근 등록 — 없으면 null (아직 끊은 수업이 없다). 최근순 정렬에 쓴다
  Registration? get registration => pass.latest;

  int get total => pass.total;

  int get used => pass.used;

  /// **등록권이 없으면 만료로 본다** — 남은 회차가 0인 것과 같은 자리다
  _Bucket get bucket => pass.active ? _Bucket.active : _Bucket.expired;

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
    return _phoneLabel(row.source.phone);
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

  /// 여기서 바로 지운다 — **고치기 화면을 거치지 않는다**
  ///
  /// 지우려고 들어왔는데 수정 폼을 한 번 지나야 하면 한 단계가 헛돈다.
  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: '${_member.name} 회원님을 삭제할까요?',
      message: '등록권 · 세션 싸인 · 운동일지가 함께 지워지고 되돌릴 수 없어요',
      confirmLabel: '삭제',
      destructive: true,
      icon: CupertinoIcons.trash,
      iconColor: AppColors.error,
    );
    if (!ok || !mounted) return;
    try {
      await MemberApi.remove(_member.id);
      if (mounted) Navigator.pop(context, true);
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
    final active = row.bucket == _Bucket.active;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: PhoneDetailScaffold(
        // **이름을 안 적는다** — 아래 머리에 크게 서 있어서 두 번 나온다
        title: '회원 정보',
        // 지우기는 **우측 상단 휴지통** — 운동일지·공지·회의록과 같은 자리다.
        // 아래에 빨간 버튼으로 두면 '정보 수정' 옆에서 눈에 먼저 들어온다
        actions: [
          if (_canEdit)
            GlassIconButton(
              symbol: 'trash',
              stableId: 'member-info-delete',
              onPressed: _delete,
            ),
        ],
        // 고치기는 **하단 고정 글래스** — 스크롤 안에 두면 아래까지 내려야
        // 보이고, 애플에서 버튼이 리퀴드 글래스가 아니라 평평해진다
        bottomBar: _canEdit
            ? GlassBottomButton(label: '정보 수정', onPressed: _edit)
            : null,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            // 하단 고정 버튼에 마지막 카드가 가리지 않게
            _canEdit
                ? GlassBottomButton.inset(context)
                : bottomBarInset(context),
          ),
          children: [
            // ── 누구인가 ──
            //
            // **카드에 안 담는다.** 흰 판 셋이 나란히 서면 결이 똑같아서
            // 무엇부터 봐야 할지가 안 읽힌다. 머리를 회색 바탕에 그대로 앉히면
            // 아래 카드가 정보 칸으로 살아난다 (홈·프로필과 같은 결이다).
            //
            // **아바타를 안 그린다** (2026-09-02 대표 지적) — 회원은 사진을
            // 올릴 데가 없어서 이름 첫 글자로 만든 동그라미만 떴다.
            // 뜻이 없는 그림이라 이름과 상태만 남긴다.
            const SizedBox(height: 10),
            Text(
              _member.name,
              textAlign: TextAlign.center,
              style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Center(
              child: _StatusChip(
                active: active,
                hasPass: row.registration != null,
              ),
            ),
            const SizedBox(height: 26),
            // ── 남은 회차 ──
            if (row.registration != null) ...[
              _PassCard(row: row, active: active),
              const SizedBox(height: 12),
            ],
            // ── 인적 사항 ──
            // **줄을 목록으로 만든다** — 마지막 줄 아래에 선이 남아 있으면
            // 카드 아래가 열린 것처럼 보인다 (2026-09-02 대표 지적).
            // 메모가 있고 없고에 따라 마지막 줄이 바뀌어서, 손으로 `last` 를
            // 붙이면 반드시 어긋난다
            FieldCard(
              fields: [
                // **전화번호가 제일 위다** — 회원에게 연락하려고 여는 자리다
                (
                  label: '연락처',
                  value: _phoneLabel(_member.phone),
                  onCopy: _member.phone.trim().isEmpty
                      ? null
                      : () => _copy(_member.phone),
                ),
                (label: '담당', value: trainer, onCopy: null),
                if (branch.isNotEmpty)
                  (label: '지점', value: branch, onCopy: null),
                (
                  label: '등록일',
                  value: fullDateLabel(_member.registeredAt),
                  onCopy: null,
                ),
                (
                  label: '방문 경로',
                  value: _member.visitPath?.label ?? '기록 없음',
                  onCopy: null,
                ),
                if (_member.memo case final memo? when memo.trim().isNotEmpty)
                  (label: '메모', value: memo, onCopy: null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) AppToast.show(context, '전화번호를 복사했어요');
  }
}

/// 활성·만료 알약 — 목록 카드의 회차 알약과 같은 색을 쓴다
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active, required this.hasPass});

  final bool active;
  final bool hasPass;

  @override
  Widget build(BuildContext context) {
    final color = !hasPass
        ? AppColors.gray400
        : active
        ? AppColors.primary
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        !hasPass
            ? '등록권 없음'
            : active
            ? '활성'
            : '만료',
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 남은 회차 — **숫자가 주인공이다**
///
/// 예전에는 `남은 회차` 와 숫자가 한 줄 양 끝에 있었는데, 그러면 카드에서
/// 제일 큰 것이 **빈 진행바**가 된다 (0회 사용이면 회색 막대만 길게 남는다).
/// 숫자를 크게 왼쪽에 두고 막대를 얇게 깔면 눈이 숫자부터 잡는다.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.row, required this.active});

  final _Row row;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final left = row.total - row.used;
    final color = active ? AppColors.primary : AppColors.success;
    final progress = row.total == 0 ? 0.0 : row.used / row.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '남은 회차',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$left',
                style: AppTextStyles.display.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '회',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // 총 회차는 옆에 조용히 — 큰 숫자와 겨루면 안 된다
              Text(
                '전체 ${row.total}회',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              // 아직 한 번도 안 썼을 때 회색 막대가 튀지 않게 옅게 깐다
              backgroundColor: AppColors.gray50,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            row.used == 0 ? '아직 안 썼어요' : '${row.used}회 썼어요',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
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
