import 'package:flutter/material.dart';

import '../../core/widgets/feedback/skeleton.dart';

/// 업무 탭 안쪽 판(수업·기여도·평가)이 받아오는 동안 쓰는 뼈대
///
/// 셋 다 **요약 카드 한 장 + 목록 카드 한 장** 짜임이라 하나로 쓴다.
/// 환경정비만 칩 격자라 따로 그린다 ([_ChecklistSkeleton]).
class WorkSectionSkeleton extends StatelessWidget {
  WorkSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonCard(
          padding: EdgeInsets.all(20),
          children: [
            Skeleton(width: 96, height: 13),
            SizedBox(height: 16),
            Skeleton(width: 150, height: 26, radius: 8),
            SizedBox(height: 14),
            Skeleton(height: 8, radius: 4),
          ],
        ),
        SizedBox(height: 12),
        SkeletonCard(
          padding: EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Skeleton(width: 84, height: 13),
                Spacer(),
                Skeleton(width: 52, height: 13),
              ],
            ),
            SizedBox(height: 18),
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(height: 16),
              Row(
                children: [
                  SkeletonCircle(size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 120, height: 12),
                        SizedBox(height: 7),
                        Skeleton(width: 76, height: 10),
                      ],
                    ),
                  ),
                  Skeleton(width: 40, height: 12),
                ],
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
