import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dictation_notepad/app.dart';
import 'package:dictation_notepad/core/settings_store.dart';
import 'package:dictation_notepad/ui/home_page.dart';
import 'package:dictation_notepad/ui/setup_page.dart';

/// 在 windows 目标平台下跑测试体。
///
/// M3 在 Android 目标下用 InkSparkle 水波纹，它要读 `shaders/ink_sparkle.frag`
/// 这个资源；跑单测时该资源不一定被打包进去，一点按钮就会抛
/// "Asset 'shaders/ink_sparkle.frag' not found"。换成非 Android 目标即可绕开。
///
/// 注意：必须在**测试体内部**还原这个调试变量 —— 框架会在测试体结束时检查
/// 「foundation 调试变量有没有被改动」，`tearDown` 已经太晚了。
Future<void> onWindowsPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// 首页 / 初始设置页 / 日夜切换的界面级验证。
///
/// 这些用例故意不碰真实文件：store 里没有「上次工作」记录时，
/// [SettingsStore.resumeData] 会同步返回 null，不会触发 dart:io。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsStore> newStore() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SettingsStore.load();
  }

  testWidgets('两个文件夹都没选时，停在初始设置页', (tester) {
    return onWindowsPlatform(() async {
      final store = await newStore();
      await tester.pumpWidget(DictationApp(store: store));
      await tester.pump();

      expect(find.byType(SetupPage), findsOneWidget);
      expect(find.text('选择两个文件夹'), findsOneWidget);
      expect(find.text('视频文件夹'), findsOneWidget);
      expect(find.text('文本文件夹'), findsOneWidget);
      // 还没选文件夹，不该出现首页的「开始工作」
      expect(find.text('开始工作'), findsNothing);
    });
  });

  testWidgets('两个文件夹都选好后自动进首页', (tester) {
    return onWindowsPlatform(() async {
      final store = await newStore();
      await store.setVideoFolder(r'C:\video');
      await store.setTextFolder(r'C:\text');

      await tester.pumpWidget(DictationApp(store: store));
      await tester.pump();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SetupPage), findsNothing);
      expect(find.text('播放本地视频，同时把原文听写下来'), findsOneWidget);
      expect(find.text('开始工作'), findsOneWidget);
      expect(find.text(r'C:\video'), findsOneWidget);
      expect(find.text(r'C:\text'), findsOneWidget);
    });
  });

  testWidgets('首页顶栏的日夜切换会改变 ThemeMode，并且真的换掉配色', (tester) {
    return onWindowsPlatform(() async {
      final store = await newStore();
      await store.setVideoFolder(r'C:\video');
      await store.setTextFolder(r'C:\text');
      await store.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(DictationApp(store: store));
      await tester.pump();

      // 日间：天蓝顶栏
      AppBar appBar() => tester.widget<AppBar>(find.byType(AppBar).first);
      expect(appBar().backgroundColor, const Color(0xFF29B6F6));

      // 顶栏上那个日夜切换按钮（tooltip 随当前模式变化）
      await tester.tap(find.byTooltip('切换到夜间模式'));
      await tester.pumpAndSettle();

      expect(store.themeMode, ThemeMode.dark);
      expect(appBar().backgroundColor, const Color(0xFF0A1526));
      expect(
        Theme.of(tester.element(find.byType(HomePage))).brightness,
        Brightness.dark,
      );

      // 再切回日间
      await tester.tap(find.byTooltip('切换到日间模式'));
      await tester.pumpAndSettle();
      expect(store.themeMode, ThemeMode.light);
      expect(appBar().backgroundColor, const Color(0xFF29B6F6));
    });
  });
}
