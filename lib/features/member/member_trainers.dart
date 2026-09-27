import 'package:flutter/material.dart';

import '../../core/api/work/lesson_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/input/pressable.dart';

/// 담당 트레이너 고르기 — 대표·관리자가 회원 정보·운동 일지에 들어오면
/// **먼저 뜨는 자리**다 (2026-09-27 대표 요청)
///
/// 예전에는 첫 화면에 전 지점 회원이 통째로 섰고, 헤더 필터로 사람을 골랐다.
/// 대표가 보는 일은 거의 늘 "이 트레이너가 누굴 맡았나" 라서 사람부터 고른다.
/// 카드는 동료평가 명단과 같은 결이다 (아바타 · 이름 · 직급).
///
/// 트레이너·점장만 세운다 — FC·팀장·마케터는 회원을 안 맡는다. 다만
/// **명단에 없는 담당자의 회원도** 카드로 세운다 (퇴사한 트레이너 등).
/// 안 세우면 그 회원들은 어디서도 못 연다.
class MemberTrainerList extends StatelessWidget {
  const MemberTrainerList({
    super.key,
    required this.members,
    required this.onPick,
  });

  /// 지점 범위 안의 회원 전부 — 사람마다 몇 명인지 센다
  final List<Member> members;

  final ValueChanged<String> onPick;

  static const _ownerRanks = {Rank.trainer, Rank.storeManager};

  @override
  Widget build(BuildContext context) {
    final directory = StaffDirectory.instance;
    final counts = <String, int>{};
    for (final m in members) {
      counts[m.ownerTrainerId] = (counts[m.ownerTrainerId] ?? 0) + 1;
    }
    final branch = rosterBranchId;
    final staff = [
      for (final e in directory.employees)
        if (_ownerRanks.contains(e.rank) &&
            e.status == EmployeeStatus.active &&
            (branch == null || e.branchId == branch))
          e,
    ]..sort(directory.compareStaff);
    final shown = {for (final e in staff) e.id};
    // 명단 밖 담당자 — 회원이 있는 사람만 뒤에 붙인다
    final others = [
      for (final id in counts.keys)
        if (!shown.contains(id)) id,
    ];

    if (staff.isEmpty && others.isEmpty) {
      return EmptyCard(
        icon: Icons.people_alt_rounded,
        text: '회원을 맡은 트레이너가 없어요',
      );
    }

    final cards = [
      for (final e in staff)
        _TrainerCard(
          name: e.name,
          subtitle: _subtitle(e.rank.label, directory.branchName(e.branchId)),
          count: counts[e.id] ?? 0,
          onTap: () => onPick(e.id),
        ),
      for (final id in others)
        _TrainerCard(
          name: directory.byId(id)?.name ?? '알 수 없음',
          subtitle: directory.byId(id)?.status == EmployeeStatus.resigned
              ? '퇴사'
              : '담당자 없음',
          count: counts[id] ?? 0,
          onTap: () => onPick(id),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  /// 대표는 전 지점을 보므로 지점을 같이 적는다 — 지점을 골랐으면 직급만
  static String _subtitle(String rank, String branch) =>
      rosterBranchId == null && branch.isNotEmpty ? '$rank · $branch' : rank;
}

/// 트레이너 한 명 — 동료평가 명단 카드(`_PersonCard`)와 같은 틀
class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
    required this.name,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Avatar(name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '회원 $count명',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: count > 0 ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}
