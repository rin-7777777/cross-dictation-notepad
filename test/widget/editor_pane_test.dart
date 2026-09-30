import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dictation_notepad/core/settings_store.dart';
import 'package:dictation_notepad/editor/editor_session.dart';
import 'package:dictation_notepad/ui/theme.dart';
import 'package:dictation_notepad/ui/widgets/app_sidebar.dart';
import 'package:dictation_notepad/ui/widgets/editor_pane.dart';

/// 在 windows 目标平台下跑测试体（见 app_pages_test.dart 的说明）。
/// 必须在测试体内部还原，框架会在测试体结束时检查调试变量。
Future<void> onWindowsPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// 编辑区与侧边栏的界面级验证。
///
/// 自动保存延时故意设成 1 小时：这样用例完全不碰磁盘，
/// 也不会在测试结束时留下未触发的 Timer。
/// 真正的保存 / 撤销 / 重做逻辑在 test/editor_session_test.dart 里用真实文件验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String editorHint = '在这里听写…停止输入后会自动保存到当前 TXT';

  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.hintText == hint,
        description: 'TextField(hintText: $hint)',
      );

  EditorSession newSession() => EditorSession(
        file: File(r'C:\nonexistent\dictation.txt'),
        autoSaveDelay: const Duration(hours: 1),
      );

  Future<void> pumpEditor(
    WidgetTester tester,
    EditorSession session, {
    bool findVisible = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: EditorPane(
            session: session,
            findVisible: findVisible,
            onCloseFind: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('输入后状态栏的字数、行数会更新', (tester) {
    return onWindowsPlatform(() async {
      final session = newSession();
      await pumpEditor(tester, session);
      session.load('');

      await tester.enterText(fieldWithHint(editorHint), '第一行\n第二行');
      await tester.pump();

      expect(session.controller.text, '第一行\n第二行');
      expect(session.charCount, 7);
      expect(session.lineCount, 2);
      expect(find.textContaining('字符 7'), findsOneWidget);
      expect(find.textContaining('行 2'), findsOneWidget);

      // 先卸掉控件树再销毁会话，避免 dispose 之后控件还被重建。
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  });

  testWidgets('查找替换：匹配计数、Aa 切换大小写、全部替换', (tester) {
    return onWindowsPlatform(() async {
      final session = newSession();
      await pumpEditor(tester, session, findVisible: true);
      session.load('abcABCabc');
      await tester.pump();

      // 默认忽略大小写 → 3 处
      await tester.enterText(fieldWithHint('查找'), 'abc');
      await tester.pump();
      expect(find.textContaining('/ 3'), findsOneWidget);

      // Aa 打开 → 区分大小写 → 2 处
      await tester.tap(find.text('Aa'));
      await tester.pump();
      expect(find.textContaining('/ 2'), findsOneWidget);

      // 再点一次回到忽略大小写 → 3 处
      await tester.tap(find.text('Aa'));
      await tester.pump();
      expect(find.textContaining('/ 3'), findsOneWidget);

      await tester.enterText(fieldWithHint('替换为'), 'X');
      await tester.pump();
      await tester.tap(find.text('全部替换'));
      await tester.pump();

      expect(session.controller.text, 'XXX');
      expect(find.text('已替换 3 处'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  });

  testWidgets('替换当前：已经选中的匹配直接替换，没选中的先跳过去', (tester) {
    return onWindowsPlatform(() async {
      final session = newSession();
      await pumpEditor(tester, session, findVisible: true);
      session.load('甲甲甲');
      await tester.pump();

      await tester.enterText(fieldWithHint('查找'), '甲');
      await tester.pump();
      // 输入查找内容时第一处匹配已经被自动选中
      expect(session.controller.selection.baseOffset, 0);
      expect(session.controller.selection.extentOffset, 1);

      await tester.enterText(fieldWithHint('替换为'), '乙');
      await tester.pump();

      // 匹配处于选中状态 → 这次点击直接替换它
      await tester.tap(find.text('替换'));
      await tester.pump();
      expect(session.controller.text, '乙甲甲');

      // 替换后光标停在被替换处的末尾，下一处匹配还没被选中 → 这次点击只是跳过去
      await tester.tap(find.text('替换'));
      await tester.pump();
      expect(session.controller.text, '乙甲甲');
      expect(session.controller.selection.baseOffset, 1);

      // 再点一次才替换第二处
      await tester.tap(find.text('替换'));
      await tester.pump();
      expect(session.controller.text, '乙乙甲');

      // 替换结果可撤销这件事由 test/editor_session_test.dart 覆盖
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  });

  testWidgets('侧边栏七项齐全，撤销/重做按可用状态置灰，点击会回调', (tester) {
    return onWindowsPlatform(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await SettingsStore.load();
      final session = newSession();

      var findTapped = 0;
      var settingsTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            drawer: AppSidebar(
              editor: session,
              store: store,
              videoPath: r'C:\video\a.mp4',
              textPath: r'C:\text\a.txt',
              onFindReplace: () => findTapped++,
              onOpenSettings: () => settingsTapped++,
              onChangeVideoFolder: () {},
              onChangeTextFolder: () {},
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // 打开抽屉
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      for (final label in <String>[
        '撤销',
        '重做',
        '查找替换',
        '保存',
        '设置',
        '视频文件夹',
        '文本文件夹',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '侧边栏应该有「$label」');
      }

      ListTile tileOf(String title) => tester.widget<ListTile>(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(ListTile),
            ),
          );

      expect(tileOf('撤销').enabled, isFalse);
      expect(tileOf('重做').enabled, isFalse);

      // 有了可撤销内容后「撤销」变为可用
      session.load('a');
      session.controller.text = 'ab';
      await tester.pump();
      expect(session.canUndo, isTrue);
      expect(tileOf('撤销').enabled, isTrue);

      // 点「查找替换」：先关抽屉，再触发回调
      await tester.tap(find.text('查找替换'));
      await tester.pumpAndSettle();
      expect(findTapped, 1);
      expect(settingsTapped, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  });
}
