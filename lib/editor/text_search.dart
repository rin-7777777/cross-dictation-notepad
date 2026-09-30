/// 纯 Dart 的查找 / 替换引擎，方便单元测试，不依赖 Flutter。
///
/// 内部统一用 `RegExp`（而不是 `toLowerCase`）来匹配，这样即使文本里出现
/// 大小写转换会改变长度的字符，返回的下标也始终和编辑框的 UTF-16 偏移一致。
library;

/// 一处匹配。
class MatchRange {
  const MatchRange(this.start, this.length);

  final int start;
  final int length;

  int get end => start + length;

  @override
  bool operator ==(Object other) =>
      other is MatchRange && other.start == start && other.length == length;

  @override
  int get hashCode => Object.hash(start, length);

  @override
  String toString() => 'MatchRange($start, $length)';
}

/// 替换的结果。
class ReplaceOutcome {
  const ReplaceOutcome(this.text, this.count);

  final String text;
  final int count;
}

RegExp _pattern(String query, bool caseSensitive) => RegExp(
      RegExp.escape(query),
      caseSensitive: caseSensitive,
      unicode: true,
    );

/// 找出全部匹配（不重叠，按出现顺序）。
List<MatchRange> findAllMatches(
  String text,
  String query, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty || text.isEmpty) return const <MatchRange>[];
  final pattern = _pattern(query, caseSensitive);
  final result = <MatchRange>[];
  for (final match in pattern.allMatches(text)) {
    result.add(MatchRange(match.start, match.end - match.start));
  }
  return result;
}

/// 从 [offset] 起（含）的第一处匹配下标；都不满足时回到第一处（环绕）。
/// 没有任何匹配时返回 -1。
int indexAtOrAfter(List<MatchRange> matches, int offset) {
  if (matches.isEmpty) return -1;
  for (var i = 0; i < matches.length; i++) {
    if (matches[i].start >= offset) return i;
  }
  return 0;
}

/// [offset] 之前（含结束位置）的最后一处匹配下标；都不满足时回到最后一处（环绕）。
/// 没有任何匹配时返回 -1。
int indexAtOrBefore(List<MatchRange> matches, int offset) {
  if (matches.isEmpty) return -1;
  for (var i = matches.length - 1; i >= 0; i--) {
    if (matches[i].end <= offset) return i;
  }
  return matches.length - 1;
}

/// 全部替换（按字面量替换，`$` 之类的字符不会被当成引用）。
ReplaceOutcome replaceAllMatches(
  String text,
  String query,
  String replacement, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return ReplaceOutcome(text, 0);
  final pattern = _pattern(query, caseSensitive);
  var count = 0;
  final result = text.replaceAllMapped(pattern, (Match match) {
    count++;
    return replacement;
  });
  return ReplaceOutcome(result, count);
}

/// 把 [range] 这一段替换成 [replacement]（用于“替换当前”）。
ReplaceOutcome replaceRangeWith(
  String text,
  MatchRange range,
  String replacement,
) {
  if (range.start < 0 || range.end > text.length || range.start > range.end) {
    return ReplaceOutcome(text, 0);
  }
  return ReplaceOutcome(
    text.replaceRange(range.start, range.end, replacement),
    1,
  );
}
