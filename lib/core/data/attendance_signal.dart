/// 근태가 방금 바뀌었다는 신호 — 화면끼리 알려 주는 자리
///
/// 출퇴근은 **카운터 PC 의 스캐너**가 찍는다. 앱은 그 사실을 모르므로
/// 바코드를 띄운 화면이 서버에 물어보고 알아낸다. 그때 홈의 '오늘 근무'
/// 카드도 같이 바뀌어야 하는데, 서로 남남이라 알려 줄 길이 없었다
/// (찍고 홈으로 와도 한동안 '미출근' 그대로였다).
///
/// 값 자체는 뜻이 없다 — **바뀌었다는 것만** 알린다.
library;

import 'package:flutter/foundation.dart';

final attendanceChanged = ValueNotifier<int>(0);

/// 방금 출근·퇴근이 찍혔다고 알린다
void notifyAttendanceChanged() => attendanceChanged.value++;
