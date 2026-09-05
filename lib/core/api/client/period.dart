/// 서버 쿼리에 쓰는 기간 문자열
///
/// 서버가 한국 시간 기준으로 자르므로, 넘길 때도 기기 현지 시각을 그대로 쓴다.
library;

/// `2026-07` — 한 달 (`period` 쿼리)
String periodKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

/// `2026-07-31` — 하루 (`date` 쿼리)
String dateKey(DateTime date) =>
    '${periodKey(date)}-${date.day.toString().padLeft(2, '0')}';

/// `2026-07` → 그 달의 1일 — [periodKey] 의 반대다
///
/// 서버가 정해 준 기간을 달 이동 줄([MonthBar])에 태울 때 쓴다. 앱이 오늘
/// 날짜로 달을 세면 안 되는 자리가 있어서다 — 동료평가는 9월 1일에 써도
/// **8월** 평가라, 서버가 준 문자열을 되돌려야 한 달이 안 어긋난다.
///
/// 모양이 다르면 null 이다 (부르는 쪽이 오늘 달로 떨어뜨린다).
DateTime? periodMonth(String? period) {
  if (period == null) return null;
  final parts = period.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}
