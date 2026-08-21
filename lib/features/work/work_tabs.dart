part of 'work_screen.dart';

/// 업무 탭의 항목 하나 — 내용은 항목마다 전용 섹션 위젯이 그린다
class _WorkItem {
  const _WorkItem({required this.label, this.checklist = false});

  final String label;

  /// 2열 점검 체크리스트를 쓰는 항목인지 (환경정비만)
  final bool checklist;
}

// 밑줄 탭 위젯(`_WorkTab`)은 [UnderlineTabs] 로 옮겼다 (2026-08-21).
//
// 칸마다 아래 테두리를 켰다 껐다 해서 옮길 때 툭 튀었다. 지금은 파란 줄
// 하나가 미끄러진다 — 내역 탭도 같은 것을 쓰므로 둘이 갈릴 수 없다.
