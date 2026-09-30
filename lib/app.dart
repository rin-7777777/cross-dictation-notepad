import 'package:flutter/material.dart';

import 'core/settings_store.dart';
import 'ui/home_page.dart';
import 'ui/setup_page.dart';
import 'ui/theme.dart';

/// 把 [SettingsStore] 挂到控件树上，页面用 `SettingsScope.of(context)` 取用，
/// 并在 store 变化（换主题、换文件夹）时自动重建。
class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({
    super.key,
    required SettingsStore store,
    required super.child,
  }) : super(notifier: store);

  static SettingsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope 没有挂在控件树上');
    return scope!.notifier!;
  }
}

class DictationApp extends StatelessWidget {
  const DictationApp({super.key, required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return MaterialApp(
            title: '听写记事本',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: store.themeMode,
            // 两个文件夹都选好之前停在初始设置页，选好后自动进首页。
            home: store.hasBothFolders ? const HomePage() : const SetupPage(),
          );
        },
      ),
    );
  }
}
