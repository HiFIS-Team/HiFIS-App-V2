import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 운동일지를 **펜으로 적는 모드**인가 (2026-09-02 대표 요청)
///
/// 트레이너가 수업하면서 일지를 적는데 들고 다니는 물건이 갈린다 — 폰은
/// 자판이고 **패드는 펜이 편하다.** 켜면 표 칸이 커지고 줄 사이가 벌어져서
/// 펜으로 쓸 자리가 생긴다.
///
/// **손글씨를 글자로 바꾸는 것은 우리가 안 한다.** OS 가 해 준다 —
/// 아이패드는 Scribble(iOS 14+ · 애플펜슬), 안드로이드는 Scribe(API 34+ ·
/// 액티브 스타일러스). 플러터가 `TextField` 에 그대로 붙여 두었고 기본이
/// 켜짐이라 앱에서 켤 것이 없다. 이 스위치는 **화면을 펴는 것**만 한다.
///
/// **사람이 아니라 기기에 기억한다.** 패드를 쓰는 사람은 늘 패드고 폰을 쓰는
/// 사람은 늘 폰이라, 기기마다 한 번 정해 두면 다시 안 건드린다. 서버에 두면
/// 폰과 패드를 같이 쓰는 사람이 기기를 옮길 때마다 어긋난다.
abstract final class PenMode {
  static const _key = 'workout_pen_mode';

  /// 켜져 있나 — 화면이 이걸 듣는다
  static final on = ValueNotifier<bool>(false);

  /// 저장해 둔 값을 되살린다 — 로그인 뒤 한 번
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    on.value = prefs.getBool(_key) ?? false;
  }

  static void toggle() => set(!on.value);

  static void set(bool next) {
    if (on.value == next) return;
    on.value = next;
    // 저장은 화면을 바꾼 뒤에 — 기다리면 켜고 끄는 손맛이 느려진다
    unawaited(_save(next));
  }

  static Future<void> _save(bool next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, next);
  }
}
