import 'package:flutter/material.dart';

import '../app.dart';
import '../core/settings_store.dart';
import 'folder_picker_flow.dart';
import 'picker_page.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets/theme_toggle_button.dart';
import 'workspace_page.dart';

/// 进程级别的一次性标记：同一次启动里只自动恢复一次上次工作。
bool _autoRestoreConsumed = false;

/// 首页：开始工作、查看 / 更改两个文件夹、继续上次工作。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<ResumeData?>? _resumeFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoRestore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resumeFuture ??= SettingsScope.of(context).resumeData();
  }

  Future<void> _refreshResume() async {
    if (!mounted) return;
    final future = SettingsScope.of(context).resumeData();
    setState(() => _resumeFuture = future);
  }

  /// 启动时自动打开上次的视频和 TXT，并恢复播放进度与光标位置。
  Future<void> _maybeAutoRestore() async {
    if (_autoRestoreConsumed) return;
    _autoRestoreConsumed = true;
    if (!mounted) return;
    final store = SettingsScope.of(context);
    if (!store.restoreLastSession) return;
    final resume = await store.resumeData();
    if (!mounted || resume == null) return;
    await _openWorkspace(
      videoPath: resume.videoPath,
      textPath: resume.textPath,
      resume: resume,
    );
  }

  Future<void> _startWork() async {
    final store = SettingsScope.of(context);
    final navigator = Navigator.of(context);
    final selection = await navigator.push<WorkSelection>(
      MaterialPageRoute<WorkSelection>(
        builder: (_) => PickerPage(store: store),
      ),
    );
    if (!mounted || selection == null) return;
    await _openWorkspace(
      videoPath: selection.videoPath,
      textPath: selection.textPath,
    );
  }

  Future<void> _openWorkspace({
    required String videoPath,
    required String textPath,
    ResumeData? resume,
  }) async {
    final store = SettingsScope.of(context);
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkspacePage(
          store: store,
          videoPath: videoPath,
          textPath: textPath,
          resume: resume,
        ),
      ),
    );
    await _refreshResume();
  }

  @override
  Widget build(BuildContext context) {
    final store = SettingsScope.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.appBar,
        foregroundColor: palette.appBarForeground,
        elevation: 0,
        title: const Text('听写记事本'),
        actions: <Widget>[
          const ThemeToggleButton(),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsSheet(context, store: store),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '播放本地视频，同时把原文听写下来',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '纯文本、无时间轴、无字幕格式、不导入导出。视频和 TXT 都待在你自己的文件夹里。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startWork,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('开始工作'),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _folderCard(
                  context,
                  isVideo: true,
                  label: '视频文件夹',
                  icon: Icons.movie_outlined,
                  value: store.videoFolder,
                ),
                const SizedBox(height: 10),
                _folderCard(
                  context,
                  isVideo: false,
                  label: '文本文件夹',
                  icon: Icons.description_outlined,
                  value: store.textFolder,
                ),
                const SizedBox(height: 14),
                FutureBuilder<ResumeData?>(
                  future: _resumeFuture,
                  builder: (context, snapshot) {
                    final resume = snapshot.data;
                    if (resume == null) {
                      return AppCard(
                        color: palette.surfaceAlt,
                        child: Text(
                          '还没有上次工作记录。点「开始工作」选一个视频和一个 TXT 就能开始。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: palette.textSecondary,
                          ),
                        ),
                      );
                    }
                    return AppCard(
                      color: palette.surfaceAlt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '上次工作',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '视频：${_baseName(resume.videoPath)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          Text(
                            '文本：${_baseName(resume.textPath)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openWorkspace(
                              videoPath: resume.videoPath,
                              textPath: resume.textPath,
                              resume: resume,
                            ),
                            icon: const Icon(Icons.history, size: 18),
                            label: const Text('继续上次'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textPrimary,
                              side: BorderSide(color: palette.border),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  '换设备时，用系统文件管理器把「视频文件夹」和「文本文件夹」拷到新设备，'
                  '再在新设备上重新选择这两个文件夹即可；播放进度和光标位置不会跟着走。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _baseName(String path) {
    final index = path.lastIndexOf(RegExp(r'[\\/]'));
    return index < 0 ? path : path.substring(index + 1);
  }

  Widget _folderCard(
    BuildContext context, {
    required bool isVideo,
    required String label,
    required IconData icon,
    required String? value,
  }) {
    final palette = AppPalette.of(context);
    final store = SettingsScope.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? '还没有选择',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () =>
                changeFolderFlow(context, store: store, isVideo: isVideo),
            child: const Text('更改'),
          ),
        ],
      ),
    );
  }
}
