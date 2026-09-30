import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/ui/theme.dart';
import 'package:dictation_notepad/ui/widgets/transport_bar.dart';

/// 在 windows 目标平台下跑测试体（见 app_pages_test.dart 的说明）。
/// 必须在测试体内部还原，框架会在测试体结束时检查调试变量。
Future<void> onWindowsPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _host({
  required Duration position,
  required Duration duration,
  required ValueChanged<Duration> onSeek,
  String label = 'test.mp4',
}) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: PlaybackProgress(
          position: position,
          duration: duration,
          onSeek: onSeek,
          trailingLabel: label,
        ),
      ),
    ),
  );
}

const Key _barKey = Key('playback-progress-bar');

void main() {
  testWidgets('显示当前时间 / 总时长，并提示可以拖动', (tester) async {
    await onWindowsPlatform(() async {
      await tester.pumpWidget(
        _host(
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 90),
          onSeek: (_) {},
        ),
      );
      expect(find.textContaining('00:05'), findsOneWidget);
      expect(find.textContaining('01:30'), findsOneWidget);
      expect(find.text('可拖动跳转'), findsOneWidget);
      expect(find.byKey(_barKey), findsOneWidget);
    });
  });

  testWidgets('拖动进度条到一半，松手后 seek 到一半', (tester) async {
    await onWindowsPlatform(() async {
      Duration? seeked;
      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          onSeek: (value) => seeked = value,
        ),
      );

      final rect = tester.getRect(find.byKey(_barKey));
      final gesture = await tester.startGesture(
        Offset(rect.left + 2, rect.center.dy),
      );
      // 拖到中间：拖动过程中还不能 seek（避免一路上疯狂 seek）。
      await gesture.moveTo(Offset(rect.left + rect.width / 2, rect.center.dy));
      await tester.pump();
      expect(seeked, isNull);
      expect(find.text('松手跳到 00:50'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(seeked, isNotNull);
      expect(seeked!.inMilliseconds, closeTo(50000, 1500));
    });
  });

  testWidgets('直接点进度条 3/4 处也会跳过去', (tester) async {
    await onWindowsPlatform(() async {
      Duration? seeked;
      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          onSeek: (value) => seeked = value,
        ),
      );

      final rect = tester.getRect(find.byKey(_barKey));
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.75, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(seeked, isNotNull);
      expect(seeked!.inMilliseconds, closeTo(75000, 1500));
    });
  });

  testWidgets('总时长还是 0（还没解析出来）时拖动不崩、也不回调', (tester) async {
    await onWindowsPlatform(() async {
      var called = 0;
      await tester.pumpWidget(
        _host(
          position: Duration.zero,
          duration: Duration.zero,
          onSeek: (_) => called++,
        ),
      );
      final rect = tester.getRect(find.byKey(_barKey));
      await tester.tapAt(rect.center);
      await tester.pumpAndSettle();
      expect(called, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
