import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// 아직 구현되지 않은 탭의 임시 화면
///
/// 실제 화면이 준비되면 MainShell에서 교체한다.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.emoji,
    required this.title,
  });

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.title2),
            const SizedBox(height: 6),
            const Text('화면 준비 중이에요', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
