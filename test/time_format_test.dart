import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/core/time_format.dart';

void main() {
  group('formatClock', () {
    test('不足一小时用 mm:ss', () {
      expect(formatClock(Duration.zero), '00:00');
      expect(formatClock(const Duration(seconds: 7)), '00:07');
      expect(formatClock(const Duration(seconds: 59)), '00:59');
      expect(formatClock(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatClock(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('超过一小时用 hh:mm:ss', () {
      expect(
        formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(
        formatClock(const Duration(hours: 12, minutes: 0, seconds: 30)),
        '12:00:30',
      );
    });

    test('毫秒被截断，负数按 0 处理', () {
      expect(formatClock(const Duration(milliseconds: 1999)), '00:01');
      expect(formatClock(const Duration(seconds: -5)), '00:00');
    });
  });

  group('formatRate', () {
    test('常见倍速的显示文本', () {
      expect(formatRate(0.25), '0.25x');
      expect(formatRate(0.5), '0.5x');
      expect(formatRate(0.75), '0.75x');
      expect(formatRate(1.0), '1x');
      expect(formatRate(1.25), '1.25x');
      expect(formatRate(1.5), '1.5x');
      expect(formatRate(1.75), '1.75x');
      expect(formatRate(2.0), '2x');
    });
  });

  group('progressRatio', () {
    test('正常比例', () {
      expect(
        progressRatio(const Duration(seconds: 5), const Duration(seconds: 10)),
        closeTo(0.5, 1e-9),
      );
    });

    test('总时长为 0 时返回 0', () {
      expect(progressRatio(const Duration(seconds: 5), Duration.zero), 0);
    });

    test('超出范围时夹在 0~1', () {
      expect(
        progressRatio(const Duration(seconds: 20), const Duration(seconds: 10)),
        1,
      );
      expect(
        progressRatio(const Duration(seconds: -3), const Duration(seconds: 10)),
        0,
      );
    });
  });

  group('durationFromMillis', () {
    test('还原毫秒，非法值按 0', () {
      expect(durationFromMillis(null), Duration.zero);
      expect(durationFromMillis(-100), Duration.zero);
      expect(durationFromMillis(0), Duration.zero);
      expect(durationFromMillis(1500), const Duration(milliseconds: 1500));
      expect(durationFromMillis(1500.4), const Duration(milliseconds: 1500));
    });
  });
}
