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

/// 可拖动的播放进度条 + 时间显示。
///
/// 拖动（手机触摸 / 电脑鼠标）或直接点进度条上任意位置都能跳转，
/// 拖动过程中上方时间会跟着预览，松手才真正 seek 过去，避免一路上疯狂 seek。
/// `-1s / -3s / -5s` 那些按钮仍然保留，用于听写时的精调。
///
/// 这个组件**不依赖播放器**（位置、时长、回调都从外面传进来），
/// 所以可以直接写单元测试；界面里由 [VideoStage] 接上播放器的数据流。
class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.trailingLabel,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final String trailingLabel;

  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  /// 拖动中的目标位置（毫秒）；null 表示当前没在拖动。
  double? _dragMillis;

  /// 点击 / 拖动的有效高度：比进度条本身厚得多，手指才好按。
  static const double hitHeight = 26;
  static const double trackHeight = 5;
  static const double knobRadius = 6.5;

  double get _totalMillis => widget.duration.inMilliseconds.toDouble();

  /// 显示用的位置：拖动时用手指位置，否则用播放器位置。
  double get _shownMillis {
    final drag = _dragMillis;
    if (drag != null) return drag;
    final total = _totalMillis;
    final live = widget.position.inMilliseconds.toDouble();
    if (total <= 0) return live < 0 ? 0 : live;
    return live.clamp(0, total).toDouble();
  }

  void _setFromDx(double dx, double width) {
    final total = _totalMillis;
    if (total <= 0 || width <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0).toDouble();
    setState(() => _dragMillis = ratio * total);
  }

  void _commit() {
    final target = _dragMillis;
    setState(() => _dragMillis = null);
    if (target != null) {
      widget.onSeek(Duration(milliseconds: target.round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final total = _totalMillis;
    final shown = _shownMillis;
    final ratio = total <= 0
        ? 0.0
        : (shown / total).clamp(0.0, 1.0).toDouble();
    final shownDuration = Duration(milliseconds: shown.round());

    return Container(
      color: palette.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                key: const Key('playback-progress-bar'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _setFromDx(details.localPosition.dx, width);
                  _commit();
                },
                onHorizontalDragStart: (details) =>
                    _setFromDx(details.localPosition.dx, width),
                onHorizontalDragUpdate: (details) =>
                    _setFromDx(details.localPosition.dx, width),
                onHorizontalDragEnd: (_) => _commit(),
                onHorizontalDragCancel: _commit,
                child: SizedBox(
                  height: hitHeight,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        // 底槽
                        Container(
                          height: trackHeight,
                          decoration: BoxDecoration(
                            color: palette.border,
                            borderRadius: BorderRadius.circular(trackHeight / 2),
                          ),
                        ),
                        // 已播放部分
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: trackHeight,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              borderRadius: BorderRadius.circular(trackHeight / 2),
                            ),
                          ),
                        ),
                        // 滑块（提示"这个可以拖"）
                        Align(
                          alignment: Alignment(ratio * 2 - 1, 0),
                          child: Container(
                            width: knobRadius * 2,
                            height: knobRadius * 2,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.surfaceAlt,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            children: <Widget>[
              Text(
                '${formatClock(shownDuration)} / ${formatClock(widget.duration)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _dragMillis == null ? '可拖动跳转' : '松手跳到 ${formatClock(shownDuration)}',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  widget.trailingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
