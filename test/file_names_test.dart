import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/core/file_names.dart';

void main() {
  group('视频扩展名', () {
    test('常见容器都认', () {
      expect(hasVideoExtension('a.mp4'), isTrue);
      expect(hasVideoExtension('a.MKV'), isTrue);
      expect(hasVideoExtension('第01课.avi'), isTrue);
      expect(hasVideoExtension('x.webm'), isTrue);
      expect(hasVideoExtension('x.m2ts'), isTrue);
    });

    test('非视频不认', () {
      expect(hasVideoExtension('a.txt'), isFalse);
      expect(hasVideoExtension('a.mp4.dtn-tmp'), isFalse);
      expect(hasVideoExtension('a'), isFalse);
      expect(hasVideoExtension('a.mp'), isFalse);
    });
  });

  group('TXT 文件名', () {
    test('扩展名判断与剥离', () {
      expect(hasTxtExtension('a.txt'), isTrue);
      expect(hasTxtExtension('a.TXT'), isTrue);
      expect(hasTxtExtension('a.md'), isFalse);
      expect(stripTxtExtension('a.TXT'), 'a');
      expect(stripTxtExtension('a.md'), 'a.md');
    });

    test('自动补 .txt', () {
      expect(ensureTxtExtension('第01课'), '第01课.txt');
      expect(ensureTxtExtension('第01课.txt'), '第01课.txt');
      expect(ensureTxtExtension('第01课.TXT'), '第01课.TXT');
      expect(ensureTxtExtension('  第01课  '), '第01课.txt');
    });
  });

  group('新建文本文件名校验', () {
    test('合法名字', () {
      expect(validateNewTextName('第01课'), isNull);
      expect(validateNewTextName('lesson 1'), isNull);
      expect(validateNewTextName('a.txt'), isNull);
      expect(validateNewTextName('听力-2024_01'), isNull);
    });

    test('空名字', () {
      expect(validateNewTextName(''), isNotNull);
      expect(validateNewTextName('   '), isNotNull);
      expect(validateNewTextName('.txt'), isNotNull);
    });

    test('路径分隔符与非法字符', () {
      expect(validateNewTextName('a/b'), isNotNull);
      expect(validateNewTextName(r'a\b'), isNotNull);
      expect(validateNewTextName('a:b'), isNotNull);
      expect(validateNewTextName('a*b'), isNotNull);
      expect(validateNewTextName('a?b'), isNotNull);
      expect(validateNewTextName('a"b'), isNotNull);
      expect(validateNewTextName('a<b'), isNotNull);
      expect(validateNewTextName('a|b'), isNotNull);
    });

    test('点号 / 空格结尾', () {
      expect(validateNewTextName('a.'), isNotNull);
      expect(validateNewTextName('a .txt'), isNotNull);
    });

    test('首尾空格会被自动去掉，不算非法', () {
      expect(validateNewTextName(' a'), isNull);
      expect(validateNewTextName('a '), isNull);
      expect(ensureTxtExtension(' a '), 'a.txt');
    });

    test('Windows 保留名', () {
      expect(validateNewTextName('con'), isNotNull);
      expect(validateNewTextName('CON'), isNotNull);
      expect(validateNewTextName('lpt1.txt'), isNotNull);
      expect(validateNewTextName('console'), isNull);
    });
  });

  group('compareNatural 自然排序', () {
    test('数字按数值比较', () {
      final names = <String>['第10课', '第2课', '第1课'];
      names.sort(compareNatural);
      expect(names, <String>['第1课', '第2课', '第10课']);
    });

    test('位数少的数字排前面', () {
      final names = <String>['02', '2', '1'];
      names.sort(compareNatural);
      expect(names, <String>['1', '2', '02']);
    });

    test('不区分大小写', () {
      final names = <String>['B', 'a', 'C'];
      names.sort(compareNatural);
      expect(names, <String>['a', 'B', 'C']);
    });

    test('纯文本按字典序', () {
      final names = <String>['b.txt', 'a.txt'];
      names.sort(compareNatural);
      expect(names, <String>['a.txt', 'b.txt']);
    });

    test('文件名的整体排序效果', () {
      final names = <String>[
        'Lesson10.mp4',
        'Lesson2.mp4',
        'Lesson1.mp4',
        'Lesson20.mp4',
      ];
      names.sort(compareNatural);
      expect(names, <String>[
        'Lesson1.mp4',
        'Lesson2.mp4',
        'Lesson10.mp4',
        'Lesson20.mp4',
      ]);
    });
  });
}
