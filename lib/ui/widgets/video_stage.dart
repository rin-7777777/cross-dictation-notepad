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
    this.audioOnly = false,
  });

  final PlayerSession session;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final String title;
  final String? errorMessage;

  /// 纯音频文件（mp3 / flac / m4a…）：不挂 `Video` 控件，改显示一块音频面板，
  /// 免得整个上方区域是一片黑框。
  final bool audioOnly;

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
                if (audioOnly)
                  _audioPanel(palette)
                else
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
          _SessionProgress(session: session, trailingLabel: title),
        ],
      ),
    );
  }

  /// 纯音频时替代画面的面板（不然上方就是一大块黑框）。
  Widget _audioPanel(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.graphic_eq, size: 44, color: palette.primary),
            const SizedBox(height: 12),
            Text(
              '音频播放中',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              '没有画面是正常的：这是纯音频文件，下面的进度条和 ±秒 按钮一样能用',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titlePill() {    return Container(
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

/// 把播放器的位置 / 时长数据流接到纯组件 [PlaybackProgress] 上。
class _SessionProgress extends StatelessWidget {
  const _SessionProgress({required this.session, required this.trailingLabel});

  final PlayerSession session;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: session.player.stream.position,
      initialData: session.player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: session.player.stream.duration,
          initialData: session.player.state.duration,
          builder: (context, durationSnapshot) {
            return PlaybackProgress(
              position: positionSnapshot.data ?? Duration.zero,
              duration: durationSnapshot.data ?? Duration.zero,
              onSeek: session.seek,
              trailingLabel: trailingLabel,
            );
          },
        );
      },
    );
  }
}
