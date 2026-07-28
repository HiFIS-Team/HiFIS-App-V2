import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const HiFISApp());
}

class HiFISApp extends StatelessWidget {
  const HiFISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiFIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
