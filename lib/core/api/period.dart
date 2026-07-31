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
