import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/ot_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart' show myRole;
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/native_picker.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/mini_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';

/// OT 신청 — 배정·수락·확정 (2026-09-28 대표 요청)
///
/// 손님이 네이버 플레이스·전단지 QR 로 `hifis.app/ot/{지점}` 에서 신청한다.
///
/// | 누가 | 무엇을 |
/// |---|---|
/// | MASTER·ADMIN | 전 지점 · 그 지점 MANAGER·MEMBER 에게 배정 (본인은 안 한다) |
/// | MANAGER | 자기 지점 · **본인 포함** MEMBER 까지 배정 |
/// | MEMBER | 자기가 맡은 것만 — FC 는 자기 지점 **미배정**도 같이 본다 |
///
/// 배정받은 사람이 시간을 고쳐 수락하면 공통 일정에 `000님 OT` 가 서고
/// 신청자에게 문자가 간다. 거절하면 다시 미배정으로 돌아간다.
class OtScreen extends StatefulWidget {
  const OtScreen({super.key, this.branchId});

  /// 대표·관리자가 고른 지점 — null 이면 전 지점
  final String? branchId;

  @override
  State<OtScreen> createState() => _OtScreenState();
}

class _OtScreenState extends State<OtScreen> with SkeletonDelay<OtScreen> {
  List<OtRequest> _rows = const [];
  int _tab = 0;

  /// 처리 중인 신청 — 버튼을 잠근다
  final _busy = <String>{};

  /// 미배정 칸을 보나 — 배정하는 사람과 FC 만 (트레이너는 자기 것만 본다)
  bool get _seesPending => myRole.strong || currentUser?.rank == Rank.fc;

  List<OtStatus> get _tabs => [
    if (_seesPending) OtStatus.pending,
    OtStatus.assigned,
    OtStatus.accepted,
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(beginLoad);
    try {
      final rows = await OtApi.list();
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final r in rows)
            if (widget.branchId == null || r.branchId == widget.branchId) r,
        ];
        endLoad();
      });
    } catch (e) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(e));
    }
  }

  void _put(OtRequest ot) => setState(() {
    _rows = [for (final r in _rows) r.id == ot.id ? ot : r];
  });

  Future<void> _run(
    OtRequest ot,
    Future<OtRequest> Function() call,
    String done,
  ) async {
    setState(() => _busy.add(ot.id));
    try {
      final next = await call();
      if (!mounted) return;
      _put(next);
      AppToast.show(context, done);
    } catch (e) {
      if (mounted) AppToast.show(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy.remove(ot.id));
    }
  }

  /// 배정할 수 있나 — 서버 `can_assign` 과 같다
  bool _canAssign(OtRequest ot) =>
      myRole.boss ||
      (myRole == Role.manager && ot.branchId == currentUser?.branchId);

  /// 맡길 수 있는 사람 — 서버 `can_take` 와 같다
  List<Employee> _candidates(OtRequest ot) {
    final me = currentUser;
    final directory = StaffDirectory.instance;
    return [
      for (final e in directory.employees)
        if (e.status == EmployeeStatus.active &&
            e.branchId == ot.branchId &&
            (myRole.boss
                ? (e.role == Role.manager || e.role == Role.member)
                : (e.id == me?.id || e.role == Role.member)))
          e,
    ]..sort(directory.compareStaff);
  }

  Future<void> _assign(OtRequest ot) async {
    final picked = await showAppDialog<Employee>(
      context,
      (_) => _StaffPicker(people: _candidates(ot), title: '${ot.name}님 OT 담당'),
    );
    if (picked == null || !mounted) return;
    await _run(
      ot,
      () => OtApi.assign(ot.id, picked.id),
      picked.id == currentUser?.id
          ? '내가 맡았어요 · 수락해 주세요'
          : '${picked.name}님에게 배정했어요',
    );
  }

  Future<void> _accept(OtRequest ot) async {
    final time = await showAppDialog<_OtTime>(
      context,
      (_) => _AcceptCard(ot: ot),
    );
    if (time == null || !mounted) return;
    await _run(
      ot,
      () => OtApi.accept(
        ot.id,
        date: time.date,
        start: time.start,
        end: time.end,
      ),
      '확정했어요 · 공통 일정에 올렸어요',
    );
  }

  Future<void> _reject(OtRequest ot) async {
    final ok = await showConfirmDialog(
      context,
      title: '${ot.name}님 OT 를 거절할까요?',
      message: '다시 미배정으로 돌아가요',
      confirmLabel: '거절',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(ot, () => OtApi.reject(ot.id), '거절했어요');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final tab = _tab.clamp(0, tabs.length - 1);
    final status = tabs[tab];
    final shown = [
      for (final r in _rows)
        if (r.status == status) r,
    ];
    return PhoneDetailScaffold(
      title: 'OT 신청',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          bottomBarInset(context),
        ),
        children: [
          SegmentedTabs(
            labels: [
              for (final s in tabs)
                '${s.label} ${_rows.where((r) => r.status == s).length}',
            ],
            selected: tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          if (showSkeleton)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(),
              child: SkeletonRows(rows: 3, avatar: 0),
            )
          else if (shown.isEmpty)
            EmptyCard(
              icon: Icons.event_available_rounded,
              text: switch (status) {
                OtStatus.pending => '배정을 기다리는 OT 가 없어요',
                OtStatus.assigned => '수락을 기다리는 OT 가 없어요',
                OtStatus.accepted => '확정된 OT 가 없어요',
              },
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _OtCard(
                ot: shown[i],
                busy: _busy.contains(shown[i].id),
                showBranch: myRole.boss && widget.branchId == null,
                actions: _actions(shown[i]),
              ),
            ],
        ],
      ),
    );
  }

  /// 카드 아래 버튼 — 단계와 사람에 따라 갈린다
  List<Widget> _actions(OtRequest ot) {
    final busy = _busy.contains(ot.id);
    final mine = ot.assigneeId == currentUser?.id;
    return switch (ot.status) {
      OtStatus.pending => [
        if (_canAssign(ot))
          MiniButton(
            label: '배정하기',
            filled: true,
            busy: busy,
            onTap: () => _assign(ot),
          ),
      ],
      OtStatus.assigned => [
        if (mine) ...[
          MiniButton(
            label: '거절',
            filled: false,
            busy: busy,
            onTap: () => _reject(ot),
          ),
          MiniButton(
            label: '수락',
            filled: true,
            busy: busy,
            onTap: () => _accept(ot),
          ),
        ] else if (_canAssign(ot))
          MiniButton(
            label: '다시 배정',
            filled: true,
            busy: busy,
            onTap: () => _assign(ot),
          ),
      ],
      OtStatus.accepted => const [],
    };
  }
}

/// 신청 한 건
class _OtCard extends StatelessWidget {
  const _OtCard({
    required this.ot,
    required this.busy,
    required this.showBranch,
    required this.actions,
  });

  final OtRequest ot;
  final bool busy;
  final bool showBranch;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${ot.name}님',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ot.male ? '남' : '여'} · ${ot.age}세',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              if (ot.convertedAt != null)
                _Pill(label: 'PT 전환', color: AppColors.success)
              else
                _Pill(
                  label: ot.status.label,
                  color: switch (ot.status) {
                    OtStatus.pending => AppColors.warning,
                    OtStatus.assigned => AppColors.primary,
                    OtStatus.accepted => AppColors.success,
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Line(label: '방문', value: ot.when),
          _Line(label: '목적', value: ot.purpose),
          _Line(label: '연락처', value: ot.phoneLabel),
          if (showBranch && (ot.branchName ?? '').isNotEmpty)
            _Line(label: '지점', value: ot.branchName!),
          if (ot.assigneeName case final name?) _Line(label: '담당', value: name),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 52, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.body2)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// 담당 고르기 — 사람을 누르면 그 사람으로 돌려준다
class _StaffPicker extends StatelessWidget {
  const _StaffPicker({required this.people, required this.title});

  final List<Employee> people;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 340),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.title3),
          const SizedBox(height: 12),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '이 지점에 맡길 사람이 없어요',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in people)
                    Pressable(
                      onTap: () => Navigator.pop(context, e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Avatar(name: e.name, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.id == currentUser?.id
                                    ? '${e.name} (나)'
                                    : e.name,
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(e.rank.label, style: AppTextStyles.caption),
                          ],
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

/// 수락하면서 고른 날짜·시간
class _OtTime {
  const _OtTime(this.date, this.start, this.end);

  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;
}

/// 수락 — 신청한 시간을 보여주고, 안 맞으면 고쳐서 확정한다
class _AcceptCard extends StatefulWidget {
  const _AcceptCard({required this.ot});

  final OtRequest ot;

  @override
  State<_AcceptCard> createState() => _AcceptCardState();
}

class _AcceptCardState extends State<_AcceptCard> {
  late DateTime _date = widget.ot.visitDate;
  late TimeOfDay _start = widget.ot.start;
  late TimeOfDay _end = widget.ot.end;

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _valid => _minutes(_end) > _minutes(_start);

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await pickDate(
      context,
      initial: _date.isBefore(today) ? today : _date,
      first: today,
      last: today.add(const Duration(days: 180)),
      title: 'OT 날짜',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await pickTime(
      context,
      initial: start ? _start : _end,
      title: start ? '시작' : '끝',
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    const days = '월화수목금토일';
    return Container(
      width: dialogWidth(context, 340),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.ot.name}님 OT 수락', style: AppTextStyles.title3),
          const SizedBox(height: 6),
          Text(
            '시간이 안 맞으면 눌러서 고쳐 주세요.\n수락하면 공통 일정에 올라가고 신청자에게 문자가 가요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          _PickRow(
            label: '날짜',
            value: '${_date.month}월 ${_date.day}일 (${days[_date.weekday - 1]})',
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickRow(
                  label: '시작',
                  value: hhmm(_start),
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickRow(
                  label: '끝',
                  value: hhmm(_end),
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          if (!_valid) ...[
            const SizedBox(height: 8),
            Text(
              '끝나는 시간이 시작보다 늦어야 해요',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              AppButton(
                label: '취소',
                shrinkWrap: true,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '수락',
                  filled: _valid,
                  onTap: () {
                    if (!_valid) return;
                    Navigator.pop(context, _OtTime(_date, _start, _end));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.caption),
            const Spacer(),
            Text(
              value,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
