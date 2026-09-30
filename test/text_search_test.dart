import 'package:flutter_test/flutter_test.dart';

import 'package:dictation_notepad/editor/text_search.dart';

void main() {
  group('findAllMatches', () {
    test('默认忽略大小写', () {
      final matches = findAllMatches('abcABCabc', 'abc');
      expect(matches.length, 3);
      expect(matches[0], const MatchRange(0, 3));
      expect(matches[1], const MatchRange(3, 3));
      expect(matches[2], const MatchRange(6, 3));
    });

    test('区分大小写时只匹配相同的形态', () {
      final matches = findAllMatches('abcABCabc', 'abc', caseSensitive: true);
      expect(matches.length, 2);
      expect(matches[0].start, 0);
      expect(matches[1].start, 6);
    });

    test('空查询或空文本返回空列表', () {
      expect(findAllMatches('abc', ''), isEmpty);
      expect(findAllMatches('', 'a'), isEmpty);
    });

    test('正则元字符按字面量处理', () {
      expect(findAllMatches('a.b', '.').length, 1);
      expect(findAllMatches('a.b', '.').first, const MatchRange(1, 1));
      expect(findAllMatches('a(b)', '(').first, const MatchRange(1, 1));
      expect(findAllMatches(r'a\b', r'\').first, const MatchRange(1, 1));
      expect(findAllMatches('a+b', '+').first, const MatchRange(1, 1));
      expect(findAllMatches('a?b', '?').first, const MatchRange(1, 1));
      expect(findAllMatches('a|b', '|').first, const MatchRange(1, 1));
      expect(findAllMatches('a[b]', '[').first, const MatchRange(1, 1));
    });

    test('中文与多字节字符的偏移是 UTF-16 下标', () {
      final matches = findAllMatches('今天天气不错，今天', '今天');
      expect(matches.length, 2);
      expect(matches[0], const MatchRange(0, 2));
      expect(matches[1], const MatchRange(7, 2));
    });

    test('不重叠匹配', () {
      final matches = findAllMatches('aaaa', 'aa');
      expect(matches.length, 2);
      expect(matches[0], const MatchRange(0, 2));
      expect(matches[1], const MatchRange(2, 2));
    });
  });

  group('indexAtOrAfter / indexAtOrBefore', () {
    final matches = <MatchRange>[
      const MatchRange(0, 3),
      const MatchRange(10, 3),
      const MatchRange(20, 3),
    ];

    test('向后找并且环绕', () {
      expect(indexAtOrAfter(matches, 0), 0);
      expect(indexAtOrAfter(matches, 5), 1);
      expect(indexAtOrAfter(matches, 12), 2);
      expect(indexAtOrAfter(matches, 100), 0);
    });

    test('向前找并且环绕', () {
      // 语义见实现注释：返回「结束位置 <= offset」的最后一处匹配。
      expect(indexAtOrBefore(matches, 23), 2); // 23 正好是第 3 处的结束位置
      expect(indexAtOrBefore(matches, 22), 1); // 20..23 还没结束，上一处是 10..13
      expect(indexAtOrBefore(matches, 13), 1); // 13 是第 2 处的结束位置
      expect(indexAtOrBefore(matches, 12), 0);
      expect(indexAtOrBefore(matches, 3), 0);
      expect(indexAtOrBefore(matches, 0), 2); // 都不满足 → 环绕到最后一处
    });

    test('空列表返回 -1', () {
      expect(indexAtOrAfter(const <MatchRange>[], 0), -1);
      expect(indexAtOrBefore(const <MatchRange>[], 0), -1);
    });
  });

  group('replaceAllMatches', () {
    test('统计替换数量', () {
      final outcome = replaceAllMatches('abcABCabc', 'abc', 'X');
      expect(outcome.count, 3);
      expect(outcome.text, 'XXX');
    });

    test('替换文本里的美元符号不会被当成引用', () {
      final outcome = replaceAllMatches('aaa', 'a', r'$1');
      expect(outcome.count, 3);
      expect(outcome.text, r'$1$1$1');
    });

    test('查找内容里的正则元字符按字面量处理', () {
      final outcome = replaceAllMatches('a.b.c', '.', '-');
      expect(outcome.count, 2);
      expect(outcome.text, 'a-b-c');
    });

    test('空查询不做任何事', () {
      final outcome = replaceAllMatches('abc', '', 'X');
      expect(outcome.count, 0);
      expect(outcome.text, 'abc');
    });

    test('替换成空串等于删除', () {
      final outcome = replaceAllMatches('a-b-c', '-', '');
      expect(outcome.count, 2);
      expect(outcome.text, 'abc');
    });
  });

  group('replaceRangeWith', () {
    test('替换指定区间', () {
      final outcome = replaceRangeWith('abcdef', const MatchRange(2, 2), 'XY');
      expect(outcome.count, 1);
      expect(outcome.text, 'abXYef');
    });

    test('区间越界时原样返回', () {
      final outcome = replaceRangeWith('abc', const MatchRange(2, 5), 'X');
      expect(outcome.count, 0);
      expect(outcome.text, 'abc');
    });
  });
}
