import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/monitoring/monitoring_api.dart';
import '../data/current_user.dart';
import '../data/employee.dart';
import '../data/staff.dart';

/// 앱 사용 기록 — **어느 화면을 열었고 무엇을 봤는지** (2026-08-18 대표 결정)
///
/// 서버에 이미 두 가지 기록이 있는데 셋째 자리가 비어 있었다.
///
/// | | 무엇을 남기나 |
/// |---|---|
/// | 접속 로그 | 들어왔다 / 못 들어왔다 |
/// | 활동 로그 | **한 일** — 등록·수정·삭제 |
/// | **여기** | **본 것** — 화면 이동·열람 |
///
/// 화면을 옮기는 것은 **서버를 안 거친다.** 탭을 눌러 옮기거나 이미 받아 둔
/// 목록을 훑는 동안에는 요청이 한 건도 안 나가서, 서버 미들웨어로는 잡을
/// 방법이 없다. 그래서 앱이 알려 주는 수밖에 없다.
///
/// **줄마다 보내지 않는다.** 메모리에 쌓아 두었다가 [_flushEvery] 마다 한 번,
/// 또는 [_maxQueue] 가 차면 묶어서 올린다. 한 줄에 한 번씩 부르면 요청이
/// 수십 배가 된다 — 서버가 응답 지표를 분당 한 번 내려쓰는 것과 같은 판단이다.
///
/// **대표는 안 남긴다.** 지켜보는 쪽이지 기록되는 쪽이 아니다 (화면 캡처
/// 방지와 같은 기준). 서버도 한 번 더 막는다.
class AppTrail {
  AppTrail._();

  /// 이 간격마다 모아서 올린다
  static const _flushEvery = Duration(seconds: 10);

  /// 이만큼 차면 기다리지 않고 바로 올린다 (서버가 한 번에 받는 최대치)
  static const _maxQueue = 200;

  /// 못 보낸 것이 이보다 많이 쌓이면 **오래된 것부터 버린다**
  ///
  /// 서버가 오래 꺼져 있으면 무한정 쌓여 메모리를 먹는다. 기록이 조금 비는
  /// 것이 앱이 무거워지는 것보다 낫다.
  static const _maxHold = 2000;

  static final _queue = <Map<String, dynamic>>[];
  static Timer? _timer;
  static bool _sending = false;

  /// 남길 대상인가 — 대표는 빼고, 로그인 전에는 보낼 토큰이 없다
  static bool get _wanted => myRole != Role.master && currentUser != null;

  /// 화면을 열었다 — `AppTrail.screen('급여')`
  static void screen(String name) => _add('SCREEN', name);

  /// 무엇을 열어 봤다 — `AppTrail.view('문서 열람', target: '계약서.pdf', id: ...)`
  ///
  /// **이름을 같이 남긴다.** id 만 남기면 그 문서가 지워진 뒤에 무엇을 봤는지
  /// 영영 알 수 없다.
  static void view(String name, {required String target, String? id}) =>
      _add('VIEW', name, target: target, targetId: id);

  static void _add(
    String kind,
    String screen, {
    String? target,
    String? targetId,
  }) {
    if (!_wanted) return;
    _queue.add({
      'kind': kind,
      'screen': screen,
      'target': ?target,
      'targetId': ?targetId,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length > _maxHold) {
      _queue.removeRange(0, _queue.length - _maxHold);
    }
    if (_queue.length >= _maxQueue) {
      unawaited(flush());
      return;
    }
    _timer ??= Timer(_flushEvery, () => unawaited(flush()));
  }

  /// 지금 쌓인 것을 올린다 — 앱이 뒤로 갈 때와 로그아웃 직전에도 부른다
  ///
  /// **실패하면 되돌려 놓는다.** 서버가 잠깐 꺼져 있어도 다음 번에 같이 간다.
  static Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    // 보내는 중에 또 부르면 같은 줄이 두 번 간다
    if (_sending || _queue.isEmpty || !_wanted) return;
    final batch = _queue.take(_maxQueue).toList();
    _queue.removeRange(0, batch.length);
    _sending = true;
    try {
      await MonitoringApi.sendTrails(batch);
    } catch (error) {
      // 앞쪽에 도로 넣는다 — 순서를 지켜야 되짚을 때 흐름이 보인다
      _queue.insertAll(0, batch);
      debugPrint('앱 사용 기록 전송 실패: $error');
    } finally {
      _sending = false;
      // 남은 게 있으면 다음 차례를 잡아 둔다
      if (_queue.isNotEmpty) {
        _timer ??= Timer(_flushEvery, () => unawaited(flush()));
      }
    }
  }

  /// 로그아웃 — **보내고 비운다.** 다음 사람 기록에 앞사람 줄이 섞이면 안 된다
  static Future<void> reset() async {
    await flush();
    _timer?.cancel();
    _timer = null;
    _queue.clear();
  }
}
