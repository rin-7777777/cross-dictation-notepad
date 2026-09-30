/// 纯 Dart 的显示格式工具，不依赖 Flutter，可直接单元测试。
library;

/// 两位补零。
String twoDigits(int value) => value.toString().padLeft(2, '0');

/// 把时长格式化成 `mm:ss`（不足一小时）或 `hh:mm:ss`。
String formatClock(Duration duration) {
  var milliseconds = duration.inMilliseconds;
  if (milliseconds < 0) milliseconds = 0;
  final value = Duration(milliseconds: milliseconds);
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

/// 把播放倍速格式化成 `0.25x` / `1x` / `1.5x` / `2x` 这样的短文本。
String formatRate(double rate) {
  var text = rate.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return '${text}x';
}

/// 计算播放进度比例，结果始终落在 0~1。
double progressRatio(Duration position, Duration total) {
  final totalMs = total.inMilliseconds;
  if (totalMs <= 0) return 0;
  final value = position.inMilliseconds / totalMs;
  if (value.isNaN || value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

/// 把毫秒还原成 `Duration`，负数或非法值当作 0。
Duration durationFromMillis(num? millis) {
  if (millis == null) return Duration.zero;
  final value = millis.round();
  if (value <= 0) return Duration.zero;
  return Duration(milliseconds: value);
}
