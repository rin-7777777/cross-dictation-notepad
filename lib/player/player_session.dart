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
  PlayerSession({this.compatibilityMode = false}) {
    // 【必须在 open() 之前创建 VideoController，所以放在构造函数里立刻建】
    //
    // media_kit 的原生实现（Windows/Android 都是）只 *订阅*
    // `player.stream.videoParams`，并不读取"当前值"：
    //     videoParamsSubscription = player.stream.videoParams.listen(...SetSize...);
    // 一旦 controller 的创建晚于 `player.open()`，这个「视频尺寸」事件就被永久错过，
    // 纹理尺寸停留在 0x0，而 media_kit 的 VideoTexture 在尺寸 <= 1 时什么都不画 ——
    // 表现就是「有声音、进度和倍速都正常、但画面全黑」。
    //
    // 之前写成 `late final controller = VideoController(...)`（等 Video 控件第一次
    // 构建时才创建）就会踩到这个坑：_bootstrap() 里的 `await Future.delayed(Duration.zero)`
    // 只让出事件循环，并不保证首帧已经构建。
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !compatibilityMode,
      ),
    );
  }

  /// 渲染兼容模式：关掉硬件加速，改用 CPU 软件渲染。
  ///
  /// 默认关闭。只有极少数「有声音但画面全黑」的环境才需要打开；
  /// 画面全黑更常见的原因是 controller 创建时机（见构造函数注释）
  /// 或 media_kit_video 版本与 Flutter 版本不匹配（见 pubspec.yaml）。
  final bool compatibilityMode;

  final Player player = Player();

  late final VideoController controller;

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
