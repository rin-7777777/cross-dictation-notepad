import 'package:flutter/material.dart';

import '../../editor/editor_session.dart';
import '../../editor/text_search.dart';
import '../theme.dart';

/// 下方的纯文本编辑区：查找替换条 + 输入框 + 底部状态栏。
class EditorPane extends StatefulWidget {
  const EditorPane({
    super.key,
    required this.session,
    required this.findVisible,
    required this.onCloseFind,
  });

  final EditorSession session;
  final bool findVisible;
  final VoidCallback onCloseFind;

  @override
  State<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<EditorPane> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  late final Listenable _statusListenable = Listenable.merge(<Listenable>[
    widget.session,
    widget.session.controller,
  ]);

  List<MatchRange> _matches = const <MatchRange>[];
  int _matchIndex = -1;
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    // 查找条开着的时候，撤销/重做、替换都会改文本；跟着重算一下匹配数量，
    // 免得「第 x / y 项」显示的是过期数字。
    widget.session.controller.addListener(_handleEditorTextChanged);
  }

  @override
  void didUpdateWidget(covariant EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.findVisible && !oldWidget.findVisible) {
      _prefillQueryFromSelection();
      _recomputeMatches();
    }
  }

  @override
  void dispose() {
    widget.session.controller.removeListener(_handleEditorTextChanged);
    _queryController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _handleEditorTextChanged() {
    if (!mounted || !widget.findVisible) return;
    _recomputeMatches();
  }

  void _prefillQueryFromSelection() {
    final controller = widget.session.controller;
    final selection = controller.selection;
    if (selection.isCollapsed) return;
    if (selection.start < 0 || selection.end > controller.text.length) return;
    final selected = controller.text.substring(selection.start, selection.end);
    if (selected.isEmpty || selected.contains('\n') || selected.length > 100) {
      return;
    }
    _queryController.text = selected;
  }

  void _recomputeMatches({bool selectNearest = false}) {
    final text = widget.session.controller.text;
    final matches = findAllMatches(
      text,
      _queryController.text,
      caseSensitive: _caseSensitive,
    );
    var index = -1;
    if (matches.isNotEmpty) {
      final cursor = widget.session.controller.selection.baseOffset;
      index = indexAtOrAfter(matches, cursor < 0 ? 0 : cursor);
    }
    setState(() {
      _matches = matches;
      _matchIndex = index;
    });
    if (selectNearest && index >= 0) {
      _selectMatch(index, focus: false);
    }
  }

  void _selectMatch(int index, {bool focus = true}) {
    if (index < 0 || index >= _matches.length) return;
    final text = widget.session.controller.text;
    final match = _matches[index];
    if (match.end > text.length) return;
    setState(() => _matchIndex = index);
    widget.session.controller.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    if (focus) widget.session.focusNode.requestFocus();
  }

  void _goNext() {
    _recomputeMatches();
    if (_matches.isEmpty) return;
    final current = _matchIndex;
    final from = current < 0 ? 0 : _matches[current].end;
    _selectMatch(indexAtOrAfter(_matches, from));
  }

  void _goPrevious() {
    _recomputeMatches();
    if (_matches.isEmpty) return;
    final current = _matchIndex;
    final from = current < 0 ? 0 : _matches[current].start;
    _selectMatch(indexAtOrBefore(_matches, from));
  }

  void _replaceCurrent() {
    _recomputeMatches();
    if (_matches.isEmpty) {
      _toast('没有匹配到「${_queryController.text}」');
      return;
    }
    var index = _matchIndex;
    if (index < 0 || index >= _matches.length) {
      index = indexAtOrAfter(
        _matches,
        widget.session.controller.selection.baseOffset,
      );
    }
    if (index < 0) return;

    final match = _matches[index];
    final selection = widget.session.controller.selection;
    final exactlySelected = selection.baseOffset == match.start &&
        selection.extentOffset == match.end;
    if (!exactlySelected) {
      // 先跳到这处匹配，再按一次才是替换，避免误替换。
      _selectMatch(index);
      return;
    }

    final replacement = _replaceController.text;
    final outcome = replaceRangeWith(
      widget.session.controller.text,
      match,
      replacement,
    );
    if (outcome.count == 0) return;
    _applyText(outcome.text, caret: match.start + replacement.length);
    _recomputeMatches();
  }

  void _replaceAll() {
    final query = _queryController.text;
    if (query.isEmpty) {
      _toast('请先输入要查找的内容');
      return;
    }
    final outcome = replaceAllMatches(
      widget.session.controller.text,
      query,
      _replaceController.text,
      caseSensitive: _caseSensitive,
    );
    if (outcome.count == 0) {
      _toast('没有匹配到「$query」');
      return;
    }
    _applyText(outcome.text, caret: 0);
    _recomputeMatches();
    _toast('已替换 ${outcome.count} 处');
  }

  void _applyText(String text, {required int caret}) {
    var offset = caret;
    if (offset < 0) offset = 0;
    if (offset > text.length) offset = text.length;
    widget.session.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: <Widget>[
          if (widget.findVisible) _findBar(palette),
          Expanded(child: _editorField(palette)),
          _statusBar(palette),
        ],
      ),
    );
  }

  Widget _editorField(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        controller: widget.session.controller,
        focusNode: widget.session.focusNode,
        maxLines: null,
        minLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: palette.primary,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: palette.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: '在这里听写…停止输入后会自动保存到当前 TXT',
          hintStyle: TextStyle(fontSize: 14.5, color: palette.textSecondary),
        ),
      ),
    );
  }

  Widget _statusBar(AppPalette palette) {
    return AnimatedBuilder(
      animation: _statusListenable,
      builder: (context, _) {
        final session = widget.session;
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '字符 ${session.charCount} · 行 ${session.lineCount}'
                  ' · 光标 ${session.cursorLine}:${session.cursorColumn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                session.saveLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: session.saveError != null
                      ? Colors.redAccent
                      : palette.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _findBar(AppPalette palette) {
    final total = _matches.length;
    final position =
        _matchIndex >= 0 && _matchIndex < total ? _matchIndex + 1 : 0;
    return Container(
      color: palette.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _field(
                  palette: palette,
                  controller: _queryController,
                  hint: '查找',
                  onChanged: (_) => _recomputeMatches(selectNearest: true),
                  onSubmitted: (_) => _goNext(),
                ),
              ),
              const SizedBox(width: 6),
              _caseButton(palette),
              IconButton(
                tooltip: '关闭查找替换',
                icon: const Icon(Icons.close),
                color: palette.textSecondary,
                onPressed: widget.onCloseFind,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _field(
            palette: palette,
            controller: _replaceController,
            hint: '替换为',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              OutlinedButton(
                onPressed: _goPrevious,
                style: _smallButtonStyle(palette),
                child: const Text('上一个'),
              ),
              OutlinedButton(
                onPressed: _goNext,
                style: _smallButtonStyle(palette),
                child: const Text('下一个'),
              ),
              FilledButton.tonal(
                onPressed: _replaceCurrent,
                child: const Text('替换'),
              ),
              FilledButton.tonal(
                onPressed: _replaceAll,
                child: const Text('全部替换'),
              ),
              Text(
                total == 0 ? '没有匹配' : '$position / $total',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _smallButtonStyle(AppPalette palette) {
    return OutlinedButton.styleFrom(
      foregroundColor: palette.textPrimary,
      side: BorderSide(color: palette.border),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _caseButton(AppPalette palette) {
    return TextButton(
      onPressed: () {
        setState(() => _caseSensitive = !_caseSensitive);
        _recomputeMatches(selectNearest: true);
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: _caseSensitive ? palette.primary : palette.textSecondary,
        backgroundColor:
            _caseSensitive ? palette.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: _caseSensitive ? palette.primary : palette.border,
          ),
        ),
      ),
      child: const Text(
        'Aa',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _field({
    required AppPalette palette,
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 14, color: palette.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.5, color: palette.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: palette.surface,
        border: _outline(palette.border),
        enabledBorder: _outline(palette.border),
        focusedBorder: _outline(palette.primary),
      ),
    );
  }

  OutlineInputBorder _outline(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }
}
