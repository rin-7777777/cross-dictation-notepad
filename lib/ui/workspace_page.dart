import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/file_names.dart';
import '../core/settings_store.dart';
import '../core/text_file_service.dart';
import '../core/time_format.dart';
import '../editor/editor_session.dart';
import '../player/player_session.dart';
import 'folder_picker_flow.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/editor_pane.dart';
import 'widgets/theme_toggle_button.dart';
import 'widgets/video_stage.dart';

/// 工作区：上方视频长方框（含 ±秒跳转、播放暂停、调速、进度时间、全屏），
/// 下方纯文本编辑区（撤销/重做/查找替换/自动保存）。
///
/// 顶栏：左上 ☰ 打开侧边栏，右侧依次是全屏退出（仅全屏时）、日间/夜间、Home。
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.store,
    required this.videoPath,
    required this.textPath,
    this.resume,
  });

  final SettingsStore store;
  final String videoPath;
  final String textPath;

  /// 从上次工作恢复时的进度与光标。
  final ResumeData? resume;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final PlayerSession _session;
  late final EditorSession _editor;

  Timer? _sessionTimer;
  bool _ready = false;
  bool _fullscreen = false;
  bool _showFind = false;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = PlayerSession(
      compatibilityMode: widget.store.videoCompatibilityMode,
    );
    _session.watchErrors((message) {
      if (!mounted) return;
      setState(() => _playerError = message);
    });
    _editor = EditorSession(
      file: File(widget.textPath),
      autoSaveDelay: Duration(milliseconds: widget.store.autoSaveMillis),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _sessionTimer = null;
    // 不 await：这里只需要把最后的进度/光标/文本落到内部配置和 TXT 里。
    _persistSession();
    _editor.save(force: true);
    if (_fullscreen) _applySystemUi(false);
    _session.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _editor.save();
      _persistSession();
    }
  }

  Future<void> _bootstrap() async {
    // 让出一次事件循环，避免在首帧构建期间 setState。
    await Future<void>.delayed(Duration.zero);
    final text = await TextFileService.read(File(widget.textPath));
    if (!mounted) return;
    final resume = widget.resume;
    _editor.load(
      text,
      selectionBase: resume?.selectionBase ?? 0,
      selectionExtent: resume?.selectionExtent ?? 0,
    );
    try {
      await _session.open(
        widget.videoPath,
        position: durationFromMillis(resume?.videoPositionMs),
        rate: resume?.rate ?? 1.0,
      );
    } catch (error) {
      if (mounted) setState(() => _playerError = '$error');
    }
    if (!mounted) return;
    setState(() => _ready = true);
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _persistSession(),
    );
  }

  Future<void> _persistSession() {
    final base = _editor.selectionBase;
    final extent = _editor.selectionExtent;
    return widget.store.saveSession(
      videoPath: widget.videoPath,
      textPath: widget.textPath,
      videoPositionMs: _session.position.inMilliseconds,
      rate: _session.rate,
      selectionBase: base < 0 ? 0 : base,
      selectionExtent: extent < 0 ? 0 : extent,
    );
  }

  void _openSidebar() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _setFullscreen(bool value) async {
    if (!mounted) return;
    setState(() => _fullscreen = value);
    await _applySystemUi(value);
  }

  /// 全屏时横屏 + 隐藏系统栏；退出时回到竖屏编辑。
  ///
  /// 只有 Android 需要这些调用；Windows 上是空操作。平时不锁方向，
  /// 所以不会「自动强制横屏」。
  Future<void> _applySystemUi(bool fullscreen) async {
    if (!Platform.isAndroid) return;
    try {
      if (fullscreen) {
        await SystemChrome.setPreferredOrientations(
          const <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setPreferredOrientations(
          const <DeviceOrientation>[
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ],
        );
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {
      // 个别设备不支持某些系统 UI 模式，忽略即可，不影响播放和编辑。
    }
  }

  Future<void> _goHome() async {
    await _editor.save(force: true);
    await _persistSession();
    if (!mounted) return;
    if (_fullscreen) {
      setState(() => _fullscreen = false);
      await _applySystemUi(false);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _toggleFind() => setState(() => _showFind = !_showFind);

  Future<void> _changeFolder({required bool isVideo}) async {
    await changeFolderFlow(context, store: widget.store, isVideo: isVideo);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: _fullscreen ? Colors.black : palette.appBar,
        foregroundColor:
            _fullscreen ? Colors.white : palette.appBarForeground,
        elevation: 0,
        toolbarHeight: _fullscreen ? 42 : kToolbarHeight,
        leading: IconButton(
          tooltip: '侧边栏',
          icon: const Icon(Icons.menu),
          onPressed: _openSidebar,
        ),
        title: Text(
          _fullscreen ? '全屏播放' : p.basename(widget.textPath),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: <Widget>[
          if (_fullscreen)
            IconButton(
              tooltip: '退出全屏（回到竖屏编辑）',
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: () => _setFullscreen(false),
            ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: '返回首页',
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
        ],
      ),
      drawer: AppSidebar(
        editor: _editor,
        store: widget.store,
        videoPath: widget.videoPath,
        textPath: widget.textPath,
        onFindReplace: _toggleFind,
        onOpenSettings: () =>
            showSettingsSheet(context, store: widget.store),
        onChangeVideoFolder: () => _changeFolder(isVideo: true),
        onChangeTextFolder: () => _changeFolder(isVideo: false),
      ),
      body: _ready
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      flex: _fullscreen ? 100 : 5,
                      child: VideoStage(
                        session: _session,
                        fullscreen: _fullscreen,
                        onToggleFullscreen: () => _setFullscreen(!_fullscreen),
                        title: p.basename(widget.videoPath),
                        errorMessage: _playerError,
                        audioOnly: hasAudioExtension(p.basename(widget.videoPath)),
                      ),
                    ),
                    if (!_fullscreen)
                      Expanded(
                        flex: 7,
                        child: EditorPane(
                          session: _editor,
                          findVisible: _showFind,
                          onCloseFind: () =>
                              setState(() => _showFind = false),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(
                    '正在打开视频和文本…',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
