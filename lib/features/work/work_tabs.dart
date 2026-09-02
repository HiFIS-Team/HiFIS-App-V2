part of 'work_screen.dart';

/// 업무 탭의 항목 하나 — 내용은 항목마다 전용 섹션 위젯이 그린다
class _WorkItem {
  const _WorkItem({
    required this.label,
    this.checklist = false,
    this.members = false,
    this.draw = false,
  });

  final String label;

  /// 2열 점검 체크리스트를 쓰는 항목인지 (환경정비만)
  final bool checklist;

  /// 헤더 왼쪽 끝에 **회원 목록으로 가는 사람 버튼**을 세우는 항목인지
  /// (수업 개수만 — 2026-08-31 대표 요청)
  ///
  /// 탭 번호를 손으로 적지 않으려고 항목에 표시를 둔다. 항목이 하나 늘면
  /// 번호가 밀리는데 그건 눈에 안 띈다 ([checklist] 와 같은 방식).
  final bool members;

  /// 헤더 **왼쪽 끝**에 **이번 달 추첨 영상으로 가는 필름 버튼**을 세우는 항목인지
  /// (회원 친절도만 — 2026-09-01 대표 요청)
  ///
  /// 추첨 대상이 그 탭에 서 있는 **설문 응답자**라 문맥이 같고, 지점 고르개도
  /// 여기 것을 그대로 쓴다. 자리를 [members] 와 같은 방식으로 표시한다.
  final bool draw;
}

// 밑줄 탭 위젯(`_WorkTab`)은 [UnderlineTabs] 로 옮겼다 (2026-08-21).
//
// 칸마다 아래 테두리를 켰다 껐다 해서 옮길 때 툭 튀었다. 지금은 파란 줄
// 하나가 미끄러진다 — 내역 탭도 같은 것을 쓰므로 둘이 갈릴 수 없다.
