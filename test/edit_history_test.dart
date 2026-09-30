import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/editor/edit_history.dart';

void main() {
  group('EditHistory 基本撤销重做', () {
    test('初始状态既不能撤销也不能重做', () {
      final history = EditHistory(text: 'a');
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.undo(), isNull);
      expect(history.redo(), isNull);
      history.dispose();
    });

    test('撤销回到改动前，重做回到改动后', () {
      final history = EditHistory(
        text: 'a',
        batchWindow: const Duration(minutes: 1),
      );
      history.record(const EditSnapshot(text: 'ab', selectionBase: 2));
      expect(history.canUndo, isTrue);

      final undone = history.undo();
      expect(undone, isNotNull);
      expect(undone!.text, 'a');
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);

      final redone = history.redo();
      expect(redone, isNotNull);
      expect(redone!.text, 'ab');
      expect(history.current.selectionBase, 2);
      history.dispose();
    });
  });

  group('EditHistory 批次合并', () {
    test('连续输入合并成一次撤销点', () {
      final history = EditHistory(
        text: 'a',
        batchWindow: const Duration(minutes: 1),
      );
      history.record(const EditSnapshot(text: 'ab'));
      history.record(const EditSnapshot(text: 'abc'));
      history.record(const EditSnapshot(text: 'abcd'));
      expect(history.undoDepth, 1);

      expect(history.undo()!.text, 'a');
      expect(history.redo()!.text, 'abcd');
      history.dispose();
    });

    test('endBatch 之后另开一个撤销点', () {
      final history = EditHistory(
        text: 'a',
        batchWindow: const Duration(minutes: 1),
      );
      history.record(const EditSnapshot(text: 'ab'));
      history.endBatch();
      history.record(const EditSnapshot(text: 'abc'));
      expect(history.undoDepth, 2);

      expect(history.undo()!.text, 'ab');
      expect(history.undo()!.text, 'a');
      history.dispose();
    });

    test('batchWindow 为 0 时每次改动都是独立撤销点', () {
      final history = EditHistory(text: 'a', batchWindow: Duration.zero);
      history.record(const EditSnapshot(text: 'ab'));
      history.record(const EditSnapshot(text: 'abc'));
      expect(history.undoDepth, 2);
      history.dispose();
    });

    test('新的编辑会清空重做栈', () {
      final history = EditHistory(
        text: 'a',
        batchWindow: const Duration(minutes: 1),
      );
      history.record(const EditSnapshot(text: 'ab'));
      history.endBatch();
      history.undo();
      expect(history.canRedo, isTrue);

      history.record(const EditSnapshot(text: 'ax'));
      expect(history.canRedo, isFalse);
      expect(history.undo()!.text, 'a');
      history.dispose();
    });

    test('相同快照被忽略', () {
      final history = EditHistory(text: 'a', batchWindow: Duration.zero);
      history.record(const EditSnapshot(text: 'a'));
      expect(history.canUndo, isFalse);
      history.dispose();
    });
  });

  group('EditHistory 上限与重置', () {
    test('撤销栈不超过 limit', () {
      final history = EditHistory(text: '0', limit: 2, batchWindow: Duration.zero);
      history.record(const EditSnapshot(text: '1'));
      history.record(const EditSnapshot(text: '2'));
      history.record(const EditSnapshot(text: '3'));
      expect(history.undoDepth, 2);
      expect(history.undo()!.text, '2');
      expect(history.undo()!.text, '1');
      expect(history.canUndo, isFalse);
      history.dispose();
    });

    test('reset 清空两个栈', () {
      final history = EditHistory(
        text: 'a',
        batchWindow: const Duration(minutes: 1),
      );
      history.record(const EditSnapshot(text: 'ab'));
      history.undo();
      history.reset(const EditSnapshot(text: 'zzz', selectionBase: 1));
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.current.text, 'zzz');
      history.dispose();
    });
  });
}
