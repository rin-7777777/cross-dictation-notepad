import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../player/player_session.dart';
import '../theme.dart';

/// 视频下方的一排按钮：-5s、-3s、-1s、播放/暂停、+1s、+3s、+5s，以及倍速选择。
///
/// 用 [Expanded] 平分宽度，任何手机宽度下都不会溢出，也不需要横向滚动。
class TransportBar extends StatelessWidget {
  const TransportBar({super.key, required this.session});

  final PlayerSession session;

  static const List<int> _backward = <int>[-5, -3, -1];
  static const List<int> _forward = <int>[1, 3, 5];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      color: palette.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
      child: Row(
        children: <Widget>[
          for (final seconds in _backward) _jumpButton(palette, seconds),
          Expanded(flex: 2, child: _playPauseButton(palette)),
          for (final seconds in _forward) _jumpButton(palette, seconds),
          const SizedBox(width: 4),
          _rateSelector(palette),
        ],
      ),
    );
  }

  Widget _jumpButton(AppPalette palette, int seconds) {
    final label = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          onPressed: () => session.jumpSeconds(seconds),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.textPrimary,
            backgroundColor: palette.surface,
            side: BorderSide(color: palette.border),
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 42),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _playPauseButton(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: StreamBuilder<bool>(
        stream: session.player.stream.playing,
        initialData: session.player.state.playing,
        builder: (context, snapshot) {
          final playing = snapshot.data ?? false;
          return FilledButton(
            onPressed: () => session.togglePlay(),
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 24),
          );
        },
      ),
    );
  }

  Widget _rateSelector(AppPalette palette) {
    return StreamBuilder<double>(
      stream: session.player.stream.rate,
      initialData: session.player.state.rate,
      builder: (context, snapshot) {
        final rate = snapshot.data ?? 1.0;
        return PopupMenuButton<double>(
          tooltip: '播放速度（0.25x ~ 2x）',
          initialValue: rate,
          onSelected: session.setRate,
          itemBuilder: (context) => <PopupMenuEntry<double>>[
            for (final value in kPlaybackRates)
              PopupMenuItem<double>(
                value: value,
                child: Row(
                  children: <Widget>[
                    if (value == rate)
                      Icon(Icons.check, size: 16, color: palette.primary)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(formatRate(value)),
                  ],
                ),
              ),
          ],
          child: Container(
            width: 58,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              formatRate(rate),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 播放进度条 + 时间显示（只读，不做拖动时间轴）。
class PlaybackProgress extends StatelessWidget {
  const PlaybackProgress({
    super.key,
    required this.session,
    required this.trailingLabel,
  });

  final PlayerSession session;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      color: palette.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: StreamBuilder<Duration>(
        stream: session.player.stream.position,
        initialData: session.player.state.position,
        builder: (context, positionSnapshot) {
          return StreamBuilder<Duration>(
            stream: session.player.stream.duration,
            initialData: session.player.state.duration,
            builder: (context, durationSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = durationSnapshot.data ?? Duration.zero;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progressRatio(position, duration),
                      minHeight: 4,
                      backgroundColor: palette.border,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      Text(
                        '${formatClock(position)} / ${formatClock(duration)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          trailingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
