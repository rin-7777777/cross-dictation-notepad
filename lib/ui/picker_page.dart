import 'package:flutter/material.dart';

import '../core/file_names.dart';
import '../core/folder_service.dart';
import '../core/settings_store.dart';
import '../core/text_file_service.dart';
import 'theme.dart';
import 'widgets/theme_toggle_button.dart';

/// 首页「开始工作」后带回来的选择结果。
class WorkSelection {
  const WorkSelection({required this.videoPath, required this.textPath});

  final String videoPath;
  final String textPath;
}

/// 选择工作文件：视频文件夹里选视频，文本文件夹里选 TXT 或新建 TXT。
class PickerPage extends StatefulWidget {
  const PickerPage({super.key, required this.store});

  final SettingsStore store;

  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  final TextEditingController _nameController = TextEditingController();

  List<FileEntry> _videos = const <FileEntry>[];
  List<FileEntry> _texts = const <FileEntry>[];
  String? _videoPath;
  String? _textPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 默认预选上次用过的文件，省一次翻找。
    _videoPath = widget.store.lastVideoPath;
    _textPath = widget.store.lastTextPath;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 从 initState 调用时先让出一次事件循环，避免在构建期间调用 setState。
    await Future<void>.delayed(Duration.zero);
    final videoFolder = widget.store.videoFolder;
    final textFolder = widget.store.textFolder;
    try {
      final hasAccess = await FolderService.hasStorageAccess();
      final videos = videoFolder == null
          ? const <FileEntry>[]
          : await FolderService.listVideos(videoFolder);
      final texts = textFolder == null
          ? const <FileEntry>[]
          : await FolderService.listTexts(textFolder);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _texts = texts;
        _loading = false;
        if (!hasAccess) {
          _error = '没有存储权限，读不到文件夹里的内容。'
              '请点右边「检查权限」，或到系统设置里打开「所有文件访问」。';
        } else if (videoFolder == null || textFolder == null) {
          _error = '还没有设置视频文件夹或文本文件夹，请先到设置里选择。';
        } else {
          _error = null;
        }
        if (_videoPath == null || !videos.any((e) => e.path == _videoPath)) {
          _videoPath = null;
        }
        if (_textPath == null || !texts.any((e) => e.path == _textPath)) {
          _textPath = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取文件夹失败：$error';
      });
    }
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _startWork() {
    final video = _videoPath;
    final text = _textPath;
    if (video == null || text == null) return;
    Navigator.of(context).pop<WorkSelection>(
      WorkSelection(videoPath: video, textPath: text),
    );
  }

  Future<void> _createNewText() async {
    final folder = widget.store.textFolder;
    if (folder == null) return;

    _nameController.clear();
    String? error;
    final rawName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('新建文本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '文件名',
                  hintText: '例如：第01课',
                  errorText: error,
                  suffixText: '.txt',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final problem = validateNewTextName(_nameController.text);
                  if (problem != null) {
                    setDialogState(() => error = problem);
                    return;
                  }
                  Navigator.of(dialogContext).pop(_nameController.text.trim());
                },
              ),
              const SizedBox(height: 10),
              Text(
                '不用自己加 .txt，会自动补上；文件保存到文本文件夹。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppPalette.of(builderContext).textSecondary,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final problem = validateNewTextName(_nameController.text);
                if (problem != null) {
                  setDialogState(() => error = problem);
                  return;
                }
                Navigator.of(dialogContext).pop(_nameController.text.trim());
              },
              child: const Text('创建并打开'),
            ),
          ],
        ),
      ),
    );
    if (rawName == null || !mounted) return;

    try {
      final result = await TextFileService.create(folder, rawName);
      if (!mounted) return;
      if (!result.created) {
        final open = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('同名文件已存在'),
            content: Text('${result.file.path}\n\n直接打开它吗？'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('打开'),
              ),
            ],
          ),
        );
        if (open != true || !mounted) return;
      }
      await _load();
      if (!mounted) return;
      setState(() => _textPath = result.file.path);
      _tabController.animateTo(1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建文本失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final canStart = _videoPath != null && _textPath != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.appBar,
        foregroundColor: palette.appBarForeground,
        elevation: 0,
        title: const Text('选择工作文件'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新列表',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const ThemeToggleButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: palette.appBarForeground,
          unselectedLabelColor: const Color(0xB3FFFFFF),
          indicatorColor: palette.appBarForeground,
          tabs: <Widget>[
            Tab(text: '① 视频（${_videos.length}）'),
            Tab(text: '② 文本（${_texts.length}）'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_error != null) _errorBanner(palette),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _videoList(palette),
                        _textList(palette),
                      ],
                    ),
            ),
            _bottomBar(palette, canStart),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(AppPalette palette) {
    return Container(
      width: double.infinity,
      color: palette.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: palette.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: palette.textPrimary),
            ),
          ),
          if (FolderService.isAndroid)
            TextButton(
              onPressed: () async {
                await FolderService.ensureStorageAccess();
                if (!mounted) return;
                _refresh();
              },
              child: const Text('检查权限'),
            ),
        ],
      ),
    );
  }

  Widget _videoList(AppPalette palette) {
    if (_videos.isEmpty) {
      return _emptyHint(
        palette,
        '视频文件夹里还没有视频。\n把视频文件（$kVideoExtensionsHint）拷进视频文件夹，再点右上角刷新。',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _videos.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: palette.border),
      itemBuilder: (context, index) {
        final entry = _videos[index];
        final selected = entry.path == _videoPath;
        return ListTile(
          selected: selected,
          selectedTileColor: palette.primaryContainer,
          leading: Icon(
            selected ? Icons.check_circle : Icons.movie_outlined,
            color: selected ? palette.primary : palette.textSecondary,
          ),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
          ),
          subtitle: Text(
            entry.sizeLabel,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          onTap: () {
            setState(() => _videoPath = entry.path);
            _tabController.animateTo(1);
          },
        );
      },
    );
  }

  Widget _textList(AppPalette palette) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '只显示 .txt 文件',
                  style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _createNewText,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('新建文本'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _texts.isEmpty
              ? _emptyHint(
                  palette,
                  '文本文件夹里还没有 .txt。\n点上面的「新建文本」输入文件名即可创建。',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: _texts.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: palette.border),
                  itemBuilder: (context, index) {
                    final entry = _texts[index];
                    final selected = entry.path == _textPath;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: palette.primaryContainer,
                      leading: Icon(
                        selected ? Icons.check_circle : Icons.description_outlined,
                        color: selected ? palette.primary : palette.textSecondary,
                      ),
                      title: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: palette.textPrimary),
                      ),
                      subtitle: Text(
                        entry.sizeLabel,
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                      onTap: () => setState(() => _textPath = entry.path),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyHint(AppPalette palette, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.folder_open_outlined, size: 40, color: palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(AppPalette palette, bool canStart) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _selectionLine(
            palette,
            '视频',
            _videoPath == null ? '未选择' : _nameOf(_videos, _videoPath!),
            _videoPath != null,
          ),
          const SizedBox(height: 4),
          _selectionLine(
            palette,
            '文本',
            _textPath == null ? '未选择' : _nameOf(_texts, _textPath!),
            _textPath != null,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart ? _startWork : null,
              icon: const Icon(Icons.edit_note),
              label: const Text('开始工作'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                textStyle:
                    const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionLine(
    AppPalette palette,
    String label,
    String value,
    bool picked,
  ) {
    return Row(
      children: <Widget>[
        Icon(
          picked ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15,
          color: picked ? palette.primary : palette.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  static String _nameOf(List<FileEntry> entries, String path) {
    for (final entry in entries) {
      if (entry.path == path) return entry.name;
    }
    return path;
  }
}
