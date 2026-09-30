import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../player/player_session.dart';
import '../theme.dart';
import 'transport_bar.dart';

/// 上方视频长方框：画面 + 文件名 + 全屏按钮 + 一排控制按钮 + 进度时间。
///
/// 注意：`Video` 控件在普通和全屏两种状态下都待在控件树的同一个位置
/// （`Column` 的第 0 个孩子），所以切换全屏不会重新挂载播放器。
class VideoStage extends StatelessWidget {
  const VideoStage({
    super.key,
    required this.session,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.title,
    this.errorMessage,
  });

  final PlayerSession session;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final String title;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: palette.videoBackground,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Video(
                  controller: session.controller,
                  fit: BoxFit.contain,
                  // 自己画控制条，不要播放器自带的控件（也就没有可拖的时间轴）。
                  controls: (_) => const SizedBox.shrink(),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _titlePill(),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: const Color(0x66000000),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: fullscreen ? '退出全屏' : '全屏（横屏播放）',
                      icon: Icon(
                        fullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                      ),
                      color: Colors.white,
                      onPressed: onToggleFullscreen,
                    ),
                  ),
                ),
                if (errorMessage != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _errorBox(palette, errorMessage!),
                  ),
              ],
            ),
          ),
          TransportBar(session: session),
          PlaybackProgress(session: session, trailingLabel: title),
        ],
      ),
    );
  }

  Widget _titlePill() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _errorBox(AppPalette palette, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '播放出错：$message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
