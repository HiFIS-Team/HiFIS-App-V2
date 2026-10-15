import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/feedback/app_dialog.dart';

/// 쓰다 만 글을 기기에 맡겨 둔다 — **앱이 튕겨도** 다시 열면 이어 쓸지 묻는다
/// (2026-10-15 요청)
///
/// 운동일지 · 공지 · 회의록 편집이 쓴다. 서버에는 아무것도 안 올린다.
///
/// - 편집을 시작할 때 [startDraft] — 남은 것이 있으면 **화면당 한 번만** 묻는다
/// - 그 사이 [_every] 마다 [draftSnapshot] 을 떠서 바뀌었으면 맡긴다
/// - 완료를 눌렀으면 [pauseDraft] — **지우지 않는다.** 올리다 실패할 수 있다.
///   **올라간 뒤에** [clearDraft] 로 지운다 (저장 함수가 부른다)
/// - **스스로 나가면 지운다** (`dispose` 에서 [stopDraft]). 튕기거나 OS 가 앱을
///   죽이면 `dispose` 가 안 불려서 남는다 — 그것만 되살리려는 장치다
mixin AutoDraft<T extends StatefulWidget> on State<T> {
  /// 같은 글이면 같은 키 — 새 글은 `…new` 로 둔다
  String get draftKey;

  /// 지금 적힌 것 (jsonEncode 가 되는 값만)
  Map<String, dynamic> draftSnapshot();

  /// 맡겨 둔 것을 화면에 다시 채운다
  void applyDraft(Map<String, dynamic> data);

  // ponytail: 2초 간격이라 튕기기 직전 2초 안에 적은 것은 잃는다
  static const _every = Duration(seconds: 2);
  static const _prefix = 'draft.';

  Timer? _timer;
  String? _key;
  bool _asked = false;

  /// 편집을 연 그대로의 내용 — 이것과 같으면 맡길 것이 없다
  String? _base;
  String? _last;

  Future<void> startDraft() async {
    if (_timer != null) return;
    final key = _key ??= '$_prefix$draftKey';
    final prefs = await SharedPreferences.getInstance();
    if (!_asked) {
      _asked = true;
      _base = _last = jsonEncode(draftSnapshot());
      await _ask(prefs, key);
    }
    // 묻는 사이 나갔으면 그만둔다
    if (!mounted || _key != key || _timer != null) return;
    _timer = Timer.periodic(_every, (_) => _flush(prefs, key));
  }

  Future<void> _ask(SharedPreferences prefs, String key) async {
    final raw = prefs.getString(key);
    if (raw != null && _key == key && mounted) {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(saved['at'] as String? ?? '')?.toLocal();
      final yes = await showConfirmDialog(
        context,
        icon: Icons.history_rounded,
        title: '쓰던 내용이 있어요',
        message: '${at == null ? '' : '${_label(at)}에 '}적던 내용을 이어서 쓸까요?',
        confirmLabel: '이어쓰기',
        cancelLabel: '버리기',
      );
      if (yes && _key == key && mounted) {
        applyDraft((saved['data'] as Map).cast<String, dynamic>());
      }
    }
  }

  void _flush(SharedPreferences prefs, String key) {
    if (!mounted) return;
    final now = jsonEncode(draftSnapshot());
    if (now == _last) return;
    _last = now;
    if (now == _base) {
      prefs.remove(key);
    } else {
      prefs.setString(
        key,
        '{"at":"${DateTime.now().toUtc().toIso8601String()}","data":$now}',
      );
    }
  }

  /// 완료를 눌렀다 — 마지막으로 한 번 맡기고 멈춘다 (올라가면 저장 함수가 지운다)
  void pauseDraft() {
    final key = _key;
    _timer?.cancel();
    _timer = null;
    if (key != null) {
      SharedPreferences.getInstance().then((prefs) => _flush(prefs, key));
    }
  }

  /// 올라갔다 — 그 글의 맡긴 것을 지운다. [key] 는 [draftKey] 와 같은 값
  static Future<void> clearDraft(String key) async =>
      (await SharedPreferences.getInstance()).remove('$_prefix$key');

  /// 나갔다 — 맡긴 것을 지운다
  void stopDraft() {
    final key = _key;
    _timer?.cancel();
    _timer = _key = null;
    if (key != null) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(key));
    }
  }

  static String _label(DateTime at) {
    final now = DateTime.now();
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay ? '오늘 $hm' : '${at.month}월 ${at.day}일 $hm';
  }
}
