import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/main/main_shell.dart';

void main() {
  runApp(HiFISApp());
}

class HiFISApp extends StatelessWidget {
  HiFISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiFIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: MainShell(),
    );
  }
}
