import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/core/file_names.dart';

void main() {
  group('音频扩展名', () {
    test('常见音频格式都认得', () {
      for (final name in <String>[
        'a.mp3',
        'b.M4A',
        'c.flac',
        'd.wav',
        'e.ogg',
        'f.opus',
        'g.aac',
        'h.wma',
        'i.mka',
        'j.ape',
        'k.aiff',
      ]) {
        expect(hasAudioExtension(name), isTrue, reason: name);
      }
    });

    test('视频与文本不算音频', () {
      for (final name in <String>['a.mp4', 'b.mkv', 'c.txt', 'd', 'e.mp3.txt']) {
        expect(hasAudioExtension(name), isFalse, reason: name);
      }
    });

    test('"视频/音频文件夹"里两者都算媒体', () {
      expect(hasMediaExtension('a.mp4'), isTrue);
      expect(hasMediaExtension('a.mkv'), isTrue);
      expect(hasMediaExtension('a.mp3'), isTrue);
      expect(hasMediaExtension('a.flac'), isTrue);
      expect(hasMediaExtension('a.txt'), isFalse);
      expect(hasMediaExtension('a.jpg'), isFalse);
      expect(hasMediaExtension('.hidden.mp3'), isTrue); // 点开头由列目录那层过滤
    });

    test('界面提示里包含音频格式', () {
      expect(kMediaExtensionsHint.contains('mp3'), isTrue);
      expect(kMediaExtensionsHint.contains('flac'), isTrue);
      expect(kMediaExtensionsHint.contains('mp4'), isTrue);
    });

    test('原有的视频判定没有被音频改动影响', () {
      expect(hasVideoExtension('a.mp4'), isTrue);
      expect(hasVideoExtension('a.mp3'), isFalse);
    });
  });
}
