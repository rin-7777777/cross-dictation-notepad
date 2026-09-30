import 'package:flutter/material.dart';

/// 日间 / 夜间两套配色的具体色值。
///
/// 这里刻意不往 `ThemeData` 里塞各种 `*Theme` 子主题（AppBarTheme、
/// DialogTheme、TabBarTheme、CardTheme…）：不同 Flutter 小版本之间这些类型
/// 改过名字（ThemeData → ThemeData 的 `xxxTheme` 字段被换成 `xxxThemeData`），
/// 只保留最稳的 `colorScheme` + `scaffoldBackgroundColor`，
/// 具体控件在各自用到的地方直接取色。
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.primary,
    required this.primaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.appBar,
    required this.appBarForeground,
    required this.videoBackground,
  });

  final bool isDark;
  final Color primary;
  final Color primaryContainer;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color appBar;
  final Color appBarForeground;
  final Color videoBackground;

  /// 日间：天蓝色主基调 + 浅色背景。
  static const AppPalette day = AppPalette(
    isDark: false,
    primary: Color(0xFF29B6F6),
    primaryContainer: Color(0xFFD8EEFB),
    background: Color(0xFFF1F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE7F2FA),
    border: Color(0xFFCBE1F1),
    textPrimary: Color(0xFF12222E),
    textSecondary: Color(0xFF4B6478),
    appBar: Color(0xFF29B6F6),
    appBarForeground: Color(0xFFFFFFFF),
    videoBackground: Color(0xFF0C1116),
  );

  /// 夜间：黑 / 深蓝背景 + 浅色文字。
  static const AppPalette night = AppPalette(
    isDark: true,
    primary: Color(0xFF4FC3F7),
    primaryContainer: Color(0xFF12314A),
    background: Color(0xFF05080F),
    surface: Color(0xFF0B1220),
    surfaceAlt: Color(0xFF101C2E),
    border: Color(0xFF1D2C45),
    textPrimary: Color(0xFFE4EDF7),
    textSecondary: Color(0xFF9FB3C8),
    appBar: Color(0xFF0A1526),
    appBarForeground: Color(0xFFE4EDF7),
    videoBackground: Color(0xFF000000),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppPalette.night
          : AppPalette.day;
}

/// 只依赖 `colorScheme` 的极简主题，跨 Flutter 小版本最不容易出问题。
ThemeData buildAppTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? AppPalette.night : AppPalette.day;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    surface: palette.surface,
    onSurface: palette.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
  );
}

/// 通用的小卡片容器，避免每个页面重复写 BoxDecoration。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}
