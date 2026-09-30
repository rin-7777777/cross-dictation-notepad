import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 界面上可选的播放倍速：0.25x ~ 2x。
const List<double> kPlaybackRates = <double>[
  0.25,
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
];

/// 把 media_kit 的 `Player` + `VideoController` 包一层，
/// 只暴露「打开 / 播放暂停 / ±秒跳转 / 调速 / 读进度」这些听写要用的能力。
class PlayerSession {
  PlayerSession();

  final Player player = Player();
  late final VideoController controller = VideoController(player);

  final List<StreamSubscription<String>> _errorSubscriptions =
      <StreamSubscription<String>>[];

  String? _lastError;

  String? get lastError => _lastError;

  Duration get position => player.state.position;
  Duration get duration => player.state.duration;
  bool get isPlaying => player.state.playing;
  bool get isCompleted => player.state.completed;
  double get rate => player.state.rate;

  /// 打开本地视频。先设倍速再打开，避免开头一小段用旧速度播。
  Future<void> open(
    String path, {
    Duration position = Duration.zero,
    double rate = 1.0,
  }) async {
    await player.setRate(rate);
    await player.open(Media(path), play: false);
    if (position > Duration.zero) {
      await player.seek(position);
    }
  }

  Future<void> togglePlay() => player.playOrPause();

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  /// 前进 / 后退若干秒（负数后退），并夹在 0 ~ 总时长之间。
  Future<void> jumpSeconds(int seconds) async {
    final current = player.state.position;
    final total = player.state.duration;
    var target = current + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    if (target == current) return;
    await player.seek(target);
  }

  Future<void> seek(Duration target) async {
    final total = player.state.duration;
    var value = target;
    if (value < Duration.zero) value = Duration.zero;
    if (total > Duration.zero && value > total) value = total;
    await player.seek(value);
  }

  Future<void> setRate(double value) async {
    await player.setRate(value);
  }

  /// 订阅播放错误，用来在视频区域给用户一个提示。
  void watchErrors(void Function(String message) onError) {
    _errorSubscriptions.add(
      player.stream.error.listen((message) {
        if (message.isEmpty) return;
        _lastError = message;
        onError(message);
      }),
    );
  }

  Future<void> dispose() async {
    for (final subscription in _errorSubscriptions) {
      await subscription.cancel();
    }
    _errorSubscriptions.clear();
    await player.dispose();
  }
}
