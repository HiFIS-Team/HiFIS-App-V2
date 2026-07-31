import 'package:flutter/material.dart';

import '../../core/widgets/app_dialog.dart';
import 'auth_session.dart';

/// 로그아웃 — 한 번 확인받고 로그인 화면으로 돌아간다
///
/// 내 프로필 카드와 데스크톱 사이드바 두 곳에서 부른다.
/// 세션을 끊으면 최상위 게이트가 로그인 화면으로 바꿔 끼운다.
Future<void> confirmLogout(BuildContext context) async {
  final ok = await showConfirmDialog(
    context,
    title: '로그아웃할까요?',
    message: '다음에 들어올 때 다시 로그인해야 해요.',
    confirmLabel: '로그아웃',
  );
  if (!ok || !context.mounted) return;

  // 프로필 같은 화면이 메인 위에 얹혀 있을 수 있다. 먼저 걷어내야
  // 그 화면이 남은 채로 로그인 화면이 갈아 끼워지는 일이 없다.
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  await AuthSession.instance.signOut();
}
