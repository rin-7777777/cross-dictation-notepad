import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dictation_notepad/editor/editor_session.dart';

/// EditorSession 的端到端验证：真开文件、真写盘、真撤销。
///
/// 这里刻意**不用 widget 测试**（不 pump 控件树）：纯逻辑 + 真实文件 I/O 更稳定，
/// 也不会被 IME/水波纹之类的界面细节干扰。
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dtn_editor_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  EditorSession newSession(String fileName, {int autoSaveMillis = 40}) {
    return EditorSession(
      file: File(p.join(tempDir.path, fileName)),
      autoSaveDelay: Duration(milliseconds: autoSaveMillis),
    );
  }

  test('打开文件 -> 输入 -> 自动保存真的写进磁盘', () async {
    final file = File(p.join(tempDir.path, '第01课.txt'));
    await file.writeAsString('原文第一行\n', flush: true);

    final session = newSession('第01课.txt');
    final loaded = await file.readAsString();
    session.load(loaded);
    expect(session.controller.text, '原文第一行\n');
    expect(session.isDirty, isFalse);

    session.controller.text = '原文第一行\n听写出来的第二行';
    expect(session.isDirty, isTrue, reason: '改过之后应该是「未保存」');

    // 等自动保存的定时器触发并完成写盘
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(session.isDirty, isFalse, reason: '自动保存之后应该不再是未保存');
    expect(session.saveError, isNull);
    expect(await file.readAsString(), '原文第一行\n听写出来的第二行');
    expect(session.lastSavedAt, isNotNull);

    session.dispose();
  });

  test('替换文本之后可以撤销、也可以重做', () async {
    final session = newSession('undo.txt');
    session.load('甲甲甲');
    expect(session.canUndo, isFalse);

    // 模拟「全部替换」：直接写回控制器，和 EditorPane 做的事一样
    session.controller.value = const TextEditingValue(
      text: '乙乙乙',
      selection: TextSelection.collapsed(offset: 3),
    );
    expect(session.controller.text, '乙乙乙');
    expect(session.canUndo, isTrue, reason: '替换应该产生一个撤销点');

    session.undo();
    expect(session.controller.text, '甲甲甲');

    session.redo();
    expect(session.controller.text, '乙乙乙');

    session.dispose();
  });

  test('连续输入被合并成一次撤销，撤销后光标也回到原位', () async {
    final session = newSession('batch.txt');
    // 显式给一个初始光标位置（默认是 0），这样才能验证「撤销把光标也带回去」
    session.load('hello', selectionBase: 5, selectionExtent: 5);
    expect(session.controller.selection.baseOffset, 5);

    // 模拟连续敲字（间隔小于 batchWindow）
    for (final text in <String>['hello1', 'hello12', 'hello123']) {
      session.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    expect(session.controller.text, 'hello123');

    session.undo();
    expect(session.controller.text, 'hello', reason: '整段连续输入应该一次撤销掉');
    expect(session.controller.selection.baseOffset, 5, reason: '光标回到输入前的位置');

    session.dispose();
  });

  test('保存到不存在的目录会自动建目录；保存失败会记录错误而不是崩', () async {
    final nested = File(p.join(tempDir.path, 'a', 'b', 'c.txt'));
    final session = EditorSession(
      file: nested,
      autoSaveDelay: const Duration(hours: 1),
    );
    session.load('');
    session.controller.text = '内容';
    await session.save(force: true);

    expect(session.saveError, isNull);
    expect(nested.existsSync(), isTrue);
    expect(await nested.readAsString(), '内容');
    session.dispose();
  });

  test('会话销毁前发出的最后一次保存仍会把内容写进文件', () async {
    final file = File(p.join(tempDir.path, 'last.txt'));
    final session = EditorSession(
      file: file,
      autoSaveDelay: const Duration(hours: 1),
    );
    session.load('');
    session.controller.text = '最后一段';
    expect(session.isDirty, isTrue);

    // 和 WorkspacePage.dispose() 一样的顺序：先 request 保存，再销毁会话
    final pending = session.save(force: true);
    session.dispose();
    await pending;

    expect(await file.readAsString(), '最后一段');
  });

  test('字数 / 行数 / 光标行列统计正确', () {
    final session = newSession('metrics.txt');
    session.load('第一行\n第二行');
    expect(session.charCount, 7);
    expect(session.lineCount, 2);

    session.controller.selection = const TextSelection.collapsed(offset: 5);
    // 触发一次监听，让统计刷新
    session.controller.text = '第一行\n第二行';
    session.controller.selection = const TextSelection.collapsed(offset: 5);
    expect(session.cursorLine, 2);
    expect(session.cursorColumn, 2);

    session.dispose();
  });
}
