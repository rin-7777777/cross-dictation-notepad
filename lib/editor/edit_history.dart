import 'dart:async';

/// 一次编辑快照：文本 + 选区。
///
/// 选区用裸整数保存（而不是 Flutter 的 `TextSelection`），
/// 这样撤销/重做逻辑可以脱离 Flutter 直接做单元测试。
class EditSnapshot {
  const EditSnapshot({
    required this.text,
    this.selectionBase = 0,
    this.selectionExtent = 0,
  });

  final String text;
  final int selectionBase;
  final int selectionExtent;

  @override
  bool operator ==(Object other) =>
      other is EditSnapshot &&
      other.text == text &&
      other.selectionBase == selectionBase &&
      other.selectionExtent == selectionExtent;

  @override
  int get hashCode => Object.hash(text, selectionBase, selectionExtent);

  @override
  String toString() =>
      'EditSnapshot(len=${text.length}, base=$selectionBase, extent=$selectionExtent)';
}

/// 手写的撤销 / 重做历史。
///
/// 为了像记事本那样“连续输入算一步”，这里做了批次合并：
/// 一个编辑批次开始时，把上一份稳定状态压进撤销栈；批次在
/// [batchWindow] 内没有新输入就自动结束。撤销/重做本身也会结束批次。
class EditHistory {
  EditHistory({
    required String text,
    int selectionBase = 0,
    int selectionExtent = 0,
    this.limit = 200,
    this.batchWindow = const Duration(milliseconds: 600),
  }) : _current = EditSnapshot(
          text: text,
          selectionBase: selectionBase,
          selectionExtent: selectionExtent,
        );

  /// 撤销栈上限，超出后丢弃最旧的记录。
  final int limit;

  /// 同一批次的最大间隔。
  final Duration batchWindow;

  final List<EditSnapshot> _undoStack = <EditSnapshot>[];
  final List<EditSnapshot> _redoStack = <EditSnapshot>[];

  EditSnapshot _current;
  Timer? _batchTimer;
  bool _batchOpen = false;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  EditSnapshot get current => _current;
  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;

  /// 记录一次新状态。用户每次改动输入框后调用。
  void record(EditSnapshot next) {
    if (next == _current) return;
    if (!_batchOpen) {
      _undoStack.add(_current);
      _trim();
      _redoStack.clear();
      _batchOpen = true;
    }
    _current = next;
    _restartBatchTimer();
  }

  /// 立即结束当前批次；下一次 [record] 会另开一个撤销点。
  void endBatch() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _batchOpen = false;
  }

  /// 撤销，返回需要写回编辑框的快照；没有可撤销内容时返回 null。
  EditSnapshot? undo() {
    if (_undoStack.isEmpty) return null;
    endBatch();
    _redoStack.add(_current);
    _current = _undoStack.removeLast();
    return _current;
  }

  /// 重做，返回需要写回编辑框的快照；没有可重做内容时返回 null。
  EditSnapshot? redo() {
    if (_redoStack.isEmpty) return null;
    endBatch();
    _undoStack.add(_current);
    _trim();
    _current = _redoStack.removeLast();
    return _current;
  }

  /// 用外部内容（例如刚打开的 TXT）重置历史。
  void reset(EditSnapshot snapshot) {
    endBatch();
    _undoStack.clear();
    _redoStack.clear();
    _current = snapshot;
  }

  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  void _trim() {
    while (_undoStack.length > limit) {
      _undoStack.removeAt(0);
    }
  }

  void _restartBatchTimer() {
    _batchTimer?.cancel();
    if (batchWindow <= Duration.zero) {
      endBatch();
      return;
    }
    _batchTimer = Timer(batchWindow, endBatch);
  }
}
