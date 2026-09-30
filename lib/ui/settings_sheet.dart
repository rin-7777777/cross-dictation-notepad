import 'package:flutter/material.dart';

import '../core/settings_store.dart';
import 'folder_picker_flow.dart';
import 'theme.dart';

/// 「设置」面板：主题、自动保存、启动恢复、两个文件夹。
Future<void> showSettingsSheet(
  BuildContext context, {
  required SettingsStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => _SettingsSheetBody(store: store),
  );
}

class _SettingsSheetBody extends StatelessWidget {
  const _SettingsSheetBody({required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                20 + media.viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text(
                        '设置',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '关闭',
                        icon: const Icon(Icons.close),
                        color: palette.textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _sectionLabel(context, '日间 / 夜间'),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      _choice(
                        context,
                        label: '日间',
                        selected: store.themeMode == ThemeMode.light,
                        onTap: () => store.setThemeMode(ThemeMode.light),
                      ),
                      _choice(
                        context,
                        label: '夜间',
                        selected: store.themeMode == ThemeMode.dark,
                        onTap: () => store.setThemeMode(ThemeMode.dark),
                      ),
                      _choice(
                        context,
                        label: '跟随系统',
                        selected: store.themeMode == ThemeMode.system,
                        onTap: () => store.setThemeMode(ThemeMode.system),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel(context, '自动保存'),
                  Text(
                    '停止输入后多久自动写入当前 TXT。',
                    style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      _choice(
                        context,
                        label: '快（0.6 秒）',
                        selected: store.autoSaveMillis == 600,
                        onTap: () => store.setAutoSaveMillis(600),
                      ),
                      _choice(
                        context,
                        label: '标准（1.2 秒）',
                        selected: store.autoSaveMillis == 1200,
                        onTap: () => store.setAutoSaveMillis(1200),
                      ),
                      _choice(
                        context,
                        label: '慢（2 秒）',
                        selected: store.autoSaveMillis == 2000,
                        onTap: () => store.setAutoSaveMillis(2000),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: store.restoreLastSession,
                    title: Text(
                      '启动时恢复上次工作',
                      style: TextStyle(fontSize: 14, color: palette.textPrimary),
                    ),
                    subtitle: Text(
                      '自动打开上次的视频和 TXT，并恢复播放进度与光标位置',
                      style:
                          TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                    onChanged: store.setRestoreLastSession,
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel(context, '文件夹'),
                  _folderRow(
                    context,
                    isVideo: true,
                    label: '视频文件夹',
                    value: store.videoFolder,
                  ),
                  const SizedBox(height: 10),
                  _folderRow(
                    context,
                    isVideo: false,
                    label: '文本文件夹',
                    value: store.textFolder,
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel(context, '内部记录'),
                  Text(
                    '播放进度、光标位置、日夜模式只存在软件内部配置里，'
                    '不会写进你的工作文件夹。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmClearSession(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清除上次工作记录'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '听写记事本 1.0.0 · 本地运行，无网络、无同步、不导入导出。',
                    style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.primary,
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = AppPalette.of(context);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: palette.surfaceAlt,
      selectedColor: palette.primaryContainer,
      side: BorderSide(color: selected ? palette.primary : palette.border),
      labelStyle: TextStyle(
        color: palette.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      showCheckmark: false,
    );
  }

  Widget _folderRow(
    BuildContext context, {
    required bool isVideo,
    required String label,
    required String? value,
  }) {
    final palette = AppPalette.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isVideo ? Icons.movie_outlined : Icons.description_outlined,
            size: 18,
            color: palette.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? '还没有选择',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => changeFolderFlow(
              context,
              store: store,
              isVideo: isVideo,
            ),
            child: const Text('更改'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除上次工作记录？'),
        content: const Text(
          '只会清掉软件内部记住的「上次视频 / 上次 TXT / 播放进度 / 光标位置」，'
          '两个文件夹和里面的文件都不受影响。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.clearSession();
  }
}
