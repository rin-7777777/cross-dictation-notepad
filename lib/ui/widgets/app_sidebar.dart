import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../editor/editor_session.dart';
import '../theme.dart';

/// 工作区侧边栏：撤销、重做、查找替换、保存、设置、视频文件夹、文本文件夹。
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.editor,
    required this.store,
    required this.videoPath,
    required this.textPath,
    required this.onFindReplace,
    required this.onOpenSettings,
    required this.onChangeVideoFolder,
    required this.onChangeTextFolder,
  });

  final EditorSession editor;
  final SettingsStore store;
  final String videoPath;
  final String textPath;
  final VoidCallback onFindReplace;
  final VoidCallback onOpenSettings;
  final VoidCallback onChangeVideoFolder;
  final VoidCallback onChangeTextFolder;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _header(palette),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: <Widget>[
                  AnimatedBuilder(
                    animation: editor,
                    builder: (context, _) => _tile(
                      context,
                      palette,
                      icon: Icons.undo,
                      title: '撤销',
                      enabled: editor.canUndo,
                      onTap: editor.undo,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: editor,
                    builder: (context, _) => _tile(
                      context,
                      palette,
                      icon: Icons.redo,
                      title: '重做',
                      enabled: editor.canRedo,
                      onTap: editor.redo,
                    ),
                  ),
                  _tile(
                    context,
                    palette,
                    icon: Icons.find_replace,
                    title: '查找替换',
                    onTap: onFindReplace,
                  ),
                  AnimatedBuilder(
                    animation: editor,
                    builder: (context, _) => _tile(
                      context,
                      palette,
                      icon: Icons.save_outlined,
                      title: '保存',
                      subtitle: editor.saveLabel,
                      onTap: () => editor.save(force: true),
                    ),
                  ),
                  Divider(height: 1, color: palette.border),
                  _tile(
                    context,
                    palette,
                    icon: Icons.settings_outlined,
                    title: '设置',
                    onTap: onOpenSettings,
                  ),
                  Divider(height: 1, color: palette.border),
                  _folderTile(
                    context,
                    palette,
                    isVideo: true,
                    value: store.videoFolder,
                    onChange: onChangeVideoFolder,
                  ),
                  _folderTile(
                    context,
                    palette,
                    isVideo: false,
                    value: store.textFolder,
                    onChange: onChangeTextFolder,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '听写记事本 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '纯文本 · 无时间轴 · 无字幕格式 · 无网络同步',
                    style:
                        TextStyle(fontSize: 11.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppPalette palette) {
    return Container(
      width: double.infinity,
      color: palette.appBar,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.edit_note, color: palette.appBarForeground),
              const SizedBox(width: 8),
              Text(
                '听写记事本',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.appBarForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _pathLine(palette, '视频', _baseName(videoPath)),
          const SizedBox(height: 4),
          _pathLine(palette, '文本', _baseName(textPath)),
        ],
      ),
    );
  }

  Widget _pathLine(AppPalette palette, String label, String value) {
    return Row(
      children: <Widget>[
        Text(
          '$label：',
          style: TextStyle(fontSize: 11.5, color: palette.appBarForeground),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: palette.appBarForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    AppPalette palette, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon,
        size: 20,
        color: enabled ? palette.textPrimary : palette.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: enabled ? palette.textPrimary : palette.textSecondary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
            ),
      onTap: enabled
          ? () {
              Navigator.of(context).pop();
              onTap();
            }
          : null,
    );
  }

  Widget _folderTile(
    BuildContext context,
    AppPalette palette, {
    required bool isVideo,
    required String? value,
    required VoidCallback onChange,
  }) {
    void run() {
      Navigator.of(context).pop();
      onChange();
    }

    return ListTile(
      leading: Icon(
        isVideo ? Icons.movie_outlined : Icons.description_outlined,
        size: 20,
        color: palette.textPrimary,
      ),
      title: Text(
        isVideo ? '视频/音频文件夹' : '文本文件夹',
        style: TextStyle(fontSize: 14, color: palette.textPrimary),
      ),
      subtitle: Text(
        value ?? '还没有选择',
        maxLines: 2,
        style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
      ),
      trailing: TextButton(onPressed: run, child: const Text('更改')),
      onTap: run,
    );
  }

  static String _baseName(String path) {
    final index = path.lastIndexOf(RegExp(r'[\\/]'));
    return index < 0 ? path : path.substring(index + 1);
  }
}
