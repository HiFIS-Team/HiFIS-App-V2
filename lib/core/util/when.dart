/// 시각을 사람이 읽는 말로 — **앱 전체가 여기만 쓴다**
///
/// 예전에는 화면마다 제 함수를 들고 있었다. 우연히 같은 것도 있고 아닌 것도
/// 있어서, 같은 `3일 전` 이 어디서는 `8.5` 로, 어디서는 `8.5.` 로 떨어졌다.
/// 랭킹은 상한이 없어 `120일 전` 까지 갈 수 있었다.
///
/// 새 화면에서 시각을 적을 일이 생기면 **여기 있는 것 중에서 고른다.**
/// 없으면 여기에 더한다 — 화면 안에 새로 만들지 않는다.
library;

/// `8.5` — 연도 없는 날짜. 목록 오른쪽 끝에 붙는 기본형
///
/// **끝에 점을 찍지 않는다.** 모니터링만 `8.5.` 였다.
String dateLabel(DateTime time) => '${time.month}.${time.day}';

/// `2026년 8월 5일` — 한 건을 자세히 볼 때
String fullDateLabel(DateTime time) =>
    '${time.year}년 ${time.month}월 ${time.day}일';

/// `8월 5일` — 연도가 뻔한 자리 (이번 달 급여 · 이번 달 기여도)
String monthDayLabel(DateTime time) => '${time.month}월 ${time.day}일';

/// `09:14` — 24시간
String clockLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// `오늘` · `어제` · `8.5`
///
/// 하루 단위로만 갈리는 목록에 쓴다 (칭찬·설문·수업 기록).
/// 몇 시에 있었는지가 중요하지 않은 자리다.
String dayLabel(DateTime time, {DateTime? now}) {
  final today = _midnight(now ?? DateTime.now());
  final days = today.difference(_midnight(time)).inDays;
  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  return dateLabel(time);
}

/// `방금` · `12분 전` · `3시간 전` · `2일 전` · `8.5`
///
/// 방금 올라온 것이 섞이는 목록에 쓴다 (프로젝트 활동·모니터링·랭킹 변동).
///
/// **일주일이 넘으면 날짜로 넘어간다.** `120일 전` 은 세어 보기 전에는
/// 언제인지 알 수 없어서 날짜만 못하다.
String agoLabel(DateTime time, {DateTime? now}) {
  final gap = (now ?? DateTime.now()).difference(time);
  if (gap.inMinutes < 1) return '방금';
  if (gap.inMinutes < 60) return '${gap.inMinutes}분 전';
  if (gap.inHours < 24) return '${gap.inHours}시간 전';
  if (gap.inDays < 7) return '${gap.inDays}일 전';
  return dateLabel(time);
}

DateTime _midnight(DateTime time) => DateTime(time.year, time.month, time.day);
