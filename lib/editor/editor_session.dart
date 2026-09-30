import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/text_file_service.dart';
import '../core/time_format.dart';
import 'edit_history.dart';

/// 一个 TXT 的编辑会话：文本控制器 + 撤销栈 + 自动保存 + 光标/字数统计。
class EditorSession extends ChangeNotifier {
  EditorSession({
    required this.file,
    required Duration autoSaveDelay,
  }) : _autoSaveDelay = autoSaveDelay {
    controller.addListener(_handleControllerChanged);
  }

  final File file;
  final Duration _autoSaveDelay;

  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final EditHistory history = EditHistory(text: '');

  Timer? _saveTimer;
  bool _disposed = false;
  bool _suppressChangeHandling = false;
  bool _saving = false;
  bool _saveQueued = false;
  bool _dirty = false;
  String _lastText = '';
  String? _saveError;
  DateTime? _lastSavedAt;

  String _metricsText = '';
  int _charCount = 0;
  int _lineCount = 1;
  int _cursorLine = 1;
  int _cursorColumn = 1;

  bool get isDirty => _dirty;
  bool get isSaving => _saving;
  String? get saveError => _saveError;
  DateTime? get lastSavedAt => _lastSavedAt;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  int get charCount => _charCount;
  int get lineCount => _lineCount;
  int get cursorLine => _cursorLine;
  int get cursorColumn => _cursorColumn;
  int get selectionBase => controller.selection.baseOffset;
  int get selectionExtent => controller.selection.extentOffset;

  String get saveLabel {
    if (_saving) return '保存中…';
    if (_saveError != null) return '保存失败';
    if (_dirty) return '未保存';
    final at = _lastSavedAt;
    if (at == null) return '未修改';
    return '已保存 ${twoDigits(at.hour)}:${twoDigits(at.minute)}:${twoDigits(at.second)}';
  }

  /// 打开文件后载入内容；同时把历史重置到这份内容。
  void load(String text, {int selectionBase = 0, int selectionExtent = 0}) {
    _saveTimer?.cancel();
    final base = _clampOffset(selectionBase, text);
    final extent = _clampOffset(selectionExtent, text);
    _suppressChangeHandling = true;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
    _suppressChangeHandling = false;

    _lastText = text;
    _dirty = false;
    _saveError = null;
    history.reset(
      EditSnapshot(
        text: text,
        selectionBase: base,
        selectionExtent: extent,
      ),
    );
    _recomputeMetrics();
    _safeNotify();
  }

  void undo() {
    final snapshot = history.undo();
    if (snapshot == null) return;
    _applySnapshot(snapshot);
  }

  void redo() {
    final snapshot = history.redo();
    if (snapshot == null) return;
    _applySnapshot(snapshot);
  }

  /// 手动保存（侧边栏「保存」）。[force] 为 true 时即使没改动也写一次。
  ///
  /// 正在写盘时再调用不会丢内容：只会记一个「写完再写一次」的标记，
  /// 由 [_writeLoop] 在落盘之后把最新文本再写一遍。
  Future<void> save({bool force = false}) async {
    if (_disposed) return;
    if (_saving) {
      _saveQueued = true;
      return;
    }
    if (!force && !_dirty) return;
    await _writeLoop();
  }

  /// 反复写盘，直到落盘的内容和当前文本一致，最多 5 轮。
  ///
  /// 会话已经销毁时只读 [_lastText]，不再碰已销毁的 `TextEditingController`，
  /// 所以「点 Home / 被系统杀掉之前的那一次保存」也能把最后几个字写进去。
  Future<void> _writeLoop() async {
    _saving = true;
    _saveQueued = false;
    _safeNotify();
    try {
      for (var pass = 0; pass < 5; pass++) {
        final snapshot = _disposed ? _lastText : controller.text;
        await TextFileService.write(file, snapshot);
        _lastSavedAt = DateTime.now();
        _saveError = null;
        final current = _disposed ? _lastText : controller.text;
        if (current == snapshot) {
          _dirty = false;
          break;
        }
        // 落盘期间又改了内容：再写一轮（销毁后 _lastText 不再变化，最多多写一轮）。
        _dirty = true;
      }
    } catch (error) {
      _saveError = '$error';
      _dirty = true;
    } finally {
      _saving = false;
      final queued = _saveQueued;
      _saveQueued = false;
      _safeNotify();
      if (queued && _dirty) {
        await _writeLoop();
      } else if (_dirty && _saveError == null && !_disposed) {
        // 5 轮都没收敛（输入比写盘还快）：把自动保存再排上；写盘报错时不自动重试。
        _scheduleSave();
      }
    }
  }

  /// 供界面在替换文本后刷新统计（写入 controller 会自然触发监听）。
  void refreshMetrics() {
    _recomputeMetrics();
    _safeNotify();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _disposed = true;
    controller.removeListener(_handleControllerChanged);
    history.dispose();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- 内部实现

  void _handleControllerChanged() {
    final text = controller.text;
    if (text != _lastText) {
      _lastText = text;
      if (!_suppressChangeHandling) {
        final selection = controller.selection;
        history.record(
          EditSnapshot(
            text: text,
            selectionBase: _clampOffset(selection.baseOffset, text),
            selectionExtent: _clampOffset(selection.extentOffset, text),
          ),
        );
        _dirty = true;
        _saveError = null;
        _scheduleSave();
      }
      _recomputeMetrics();
      _safeNotify();
      return;
    }
    // 文本没变，只是光标 / 选区动了：状态栏的行列要跟着更新。
    _recomputeMetrics();
    _safeNotify();
  }

  void _applySnapshot(EditSnapshot snapshot) {
    _saveTimer?.cancel();
    final base = _clampOffset(snapshot.selectionBase, snapshot.text);
    final extent = _clampOffset(snapshot.selectionExtent, snapshot.text);
    _suppressChangeHandling = true;
    controller.value = TextEditingValue(
      text: snapshot.text,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
    _suppressChangeHandling = false;

    _lastText = snapshot.text;
    _dirty = true;
    _saveError = null;
    _recomputeMetrics();
    _scheduleSave();
    _safeNotify();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_autoSaveDelay, () {
      save();
    });
  }

  void _recomputeMetrics() {
    final text = controller.text;
    _charCount = text.length;
    if (text != _metricsText) {
      _metricsText = text;
      var lines = 1;
      for (var i = 0; i < text.length; i++) {
        if (text.codeUnitAt(i) == 0x0A) lines++;
      }
      _lineCount = lines;
    }
    var offset = controller.selection.baseOffset;
    if (offset < 0) offset = text.length;
    if (offset > text.length) offset = text.length;
    var line = 1;
    var column = 1;
    for (var i = 0; i < offset; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    _cursorLine = line;
    _cursorColumn = column;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  static int _clampOffset(int offset, String text) {
    if (offset < 0) return text.length;
    if (offset > text.length) return text.length;
    return offset;
  }
}
