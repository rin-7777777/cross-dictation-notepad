import 'package:flutter/material.dart';

import '../app.dart';
import '../core/file_names.dart';
import '../core/folder_service.dart';
import 'folder_picker_flow.dart';
import 'theme.dart';
import 'widgets/theme_toggle_button.dart';

/// 首次启动：分别选择「视频文件夹」和「文本文件夹」。
///
/// 两个都选好之后，[DictationApp] 会自动把首页换成 [HomePage]。
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  bool _busy = false;

  Future<void> _choose({required bool isVideo}) async {
    final store = SettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await pickFolderFlow(
        context,
        dialogTitle: isVideo ? '选择视频文件夹' : '选择文本文件夹',
        initialDirectory: isVideo ? store.videoFolder : store.textFolder,
      );
      if (picked == null) return;
      if (isVideo) {
        await store.setVideoFolder(picked);
      } else {
        await store.setTextFolder(picked);
      }
      final word = isVideo ? '视频' : '文本';
      messenger.showSnackBar(
        SnackBar(content: Text('已设置$word文件夹：$picked')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SettingsScope.of(context);
    final palette = AppPalette.of(context);
    final ready = store.hasBothFolders;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.appBar,
        foregroundColor: palette.appBarForeground,
        elevation: 0,
        title: const Text('初始设置'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Text(
              '选择两个文件夹',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '软件只读取这两个文件夹里的内容，路径会记住，之后可以在「设置」里更改。',
              style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            _FolderTile(
              icon: Icons.movie_outlined,
              label: '视频文件夹',
              hint: '放要听写的本地视频（$kVideoExtensionsHint）',
              value: store.videoFolder,
              busy: _busy,
              onChoose: () => _choose(isVideo: true),
            ),
            const SizedBox(height: 12),
            _FolderTile(
              icon: Icons.description_outlined,
              label: '文本文件夹',
              hint: '放听写原文，只认 .txt 文件',
              value: store.textFolder,
              busy: _busy,
              onChoose: () => _choose(isVideo: false),
            ),
            const SizedBox(height: 20),
            AppCard(
              color: palette.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        ready ? Icons.check_circle_outline : Icons.info_outline,
                        size: 18,
                        color: ready ? palette.primary : palette.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ready ? '两个文件夹都选好了，正在进入首页…' : '两个文件夹都选好后会自动进入首页',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    FolderService.isAndroid
                        ? 'Android 上第一次选择文件夹时会申请「所有文件访问」权限，'
                            '这是长期按路径读写你选的文件夹所必需的；'
                            '授权后重启软件依然有效。'
                        : 'Windows 上直接选择磁盘上的文件夹即可，'
                            '路径会保存在软件内部配置里。',
                    style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '软件不联网、不同步；换设备时只用系统文件管理器把这两个文件夹拷过去。',
                    style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.busy,
    required this.onChoose,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String? value;
  final bool busy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: busy ? null : onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(value == null ? '选择' : '更改'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value ?? hint,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: value == null ? palette.textSecondary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
