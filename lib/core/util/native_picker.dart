import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'sf_symbols.dart' show isApple;
import 'platform.dart' show isDesktop;

/// 날짜·시각 고르개 — **아이폰은 아래에서 올라오는 시트**로 띄운다
/// (2026-09-16 대표 요청)
///
/// Flutter 기본 고르개는 머티리얼 창이라 화면 한가운데 떠오른다. 아이폰 사람은
/// **아래에서 올라오는 판**을 기대한다 — 캘린더·시계 앱이 다 그 모양이다.
/// 유리 버튼·탭바를 네이티브로 그리는 것과 같은 이유다 (`NativePicker.swift`).
///
/// **못 띄우면 조용히 예전 고르개로 떨어진다.** 안드로이드·맥·윈도우가 그렇고,
/// iOS 15 아래(시트가 없다)와 채널이 답을 못 줄 때도 그렇다 — 고르는 일 자체가
/// 막히면 안 된다.
///
/// 맥은 **isApple 인데도 안 쓴다.** 창이 큰 화면에서 아래 절반이 판으로
/// 덮이면 어색하고, `UISheetPresentationController` 는 iOS 것이다.
const _channel = MethodChannel('com.hifis/picker');

/// 네이티브로 띄울 수 있나 — **한 번만 물어보고 기억한다**
bool? _usable;

Future<bool> _canUseNative() async {
  if (!isApple || isDesktop) return false;
  if (_usable case final known?) return known;
  try {
    final ok = await _channel.invokeMethod<bool>('available');
    return _usable = ok ?? false;
  } catch (_) {
    // 채널이 없다 — 옛 빌드이거나 플러그인이 안 붙었다
    return _usable = false;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 머티리얼 고르개 색을 앱 토큰에 맞춘다 (네이티브가 아닐 때 쓴다)
ThemeData _pickerTheme(BuildContext context) => Theme.of(context).copyWith(
  colorScheme:
      (AppColors.isDark
              ? ColorScheme.dark(surface: AppColors.surface)
              : ColorScheme.light(surface: AppColors.surface))
          .copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
);

/// 시각 고르기 — 취소하면 null
///
/// [title] 은 시트 머리에 뜬다 (`출근`·`퇴근`). 네이티브에서만 보인다.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
  String title = '시각',
}) async {
  if (await _canUseNative()) {
    try {
      final picked = await _channel.invokeMethod<String>('time', {
        'initial': '${_two(initial.hour)}:${_two(initial.minute)}',
        'title': title,
        'accent': _hex(AppColors.primary),
      });
      if (picked == null) return null;
      final parts = picked.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      // 아래 머티리얼 고르개로 떨어진다
    }
  }
  if (!context.mounted) return null;
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) =>
        Theme(data: _pickerTheme(context), child: child!),
  );
}

/// 날짜 고르기 — 취소하면 null
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = '날짜',
}) async {
  String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  if (await _canUseNative()) {
    try {
      final picked = await _channel.invokeMethod<String>('date', {
        'initial': ymd(initial),
        'min': ymd(first),
        'max': ymd(last),
        'title': title,
        'accent': _hex(AppColors.primary),
      });
      return picked == null ? null : DateTime.parse(picked);
    } catch (_) {
      // 아래 머티리얼 고르개로 떨어진다
    }
  }
  if (!context.mounted) return null;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    builder: (context, child) =>
        Theme(data: _pickerTheme(context), child: child!),
  );
}

/// `#RRGGBB` — 네이티브가 시트 강조색으로 쓴다
String _hex(Color color) {
  String part(double v) =>
      ((v * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#${part(color.r)}${part(color.g)}${part(color.b)}'.toUpperCase();
}
