import 'package:flutter/material.dart';

import '../../app.dart';

/// 顶栏上的日间 / 夜间切换按钮。
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SettingsScope.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? '切换到日间模式' : '切换到夜间模式',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: () => store.toggleBrightness(brightness),
    );
  }
}
