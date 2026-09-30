/// 视频扩展名白名单与 TXT 文件名规则（纯 Dart，可单元测试）。
library;

/// 视频文件夹里认作视频的扩展名。
const List<String> kVideoExtensions = <String>[
  '.mp4',
  '.mkv',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.webm',
  '.m4v',
  '.mpg',
  '.mpeg',
  '.ts',
  '.m2ts',
  '.3gp',
  '.rmvb',
  '.rm',
  '.ogv',
  '.vob',
  '.asf',
  '.f4v',
];

/// 供界面显示的扩展名提示。
const String kVideoExtensionsHint =
    'mp4 / mkv / avi / mov / wmv / flv / webm / m4v / mpg / mpeg / ts / m2ts / 3gp / rmvb / rm / ogv / vob / asf / f4v';

bool hasVideoExtension(String fileName) {
  final lower = fileName.toLowerCase();
  for (final extension in kVideoExtensions) {
    if (lower.endsWith(extension)) return true;
  }
  return false;
}

bool hasTxtExtension(String fileName) => fileName.toLowerCase().endsWith('.txt');

/// 去掉结尾的 `.txt`（大小写不敏感），其它情况原样返回。
String stripTxtExtension(String fileName) {
  if (hasTxtExtension(fileName)) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

/// 保证文件名以 `.txt` 结尾。调用前应先通过 [validateNewTextName]。
String ensureTxtExtension(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  if (hasTxtExtension(trimmed)) return trimmed;
  return '$trimmed.txt';
}

const Set<String> _reservedWindowsNames = <String>{
  'CON',
  'PRN',
  'AUX',
  'NUL',
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
};

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// 自然序比较：让「第2课」排在「第10课」前面，其余按不区分大小写的字典序。
///
/// 用不依赖 `dart:io` 的纯函数实现，方便单元测试，也保证 Android / Windows 上
/// 列表顺序一致。
int compareNatural(String a, String b) {
  final lowerA = a.toLowerCase();
  final lowerB = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < lowerA.length && j < lowerB.length) {
    final codeA = lowerA.codeUnitAt(i);
    final codeB = lowerB.codeUnitAt(j);
    final digitA = _isAsciiDigit(codeA);
    final digitB = _isAsciiDigit(codeB);
    if (digitA && digitB) {
      final startA = i;
      while (i < lowerA.length && _isAsciiDigit(lowerA.codeUnitAt(i))) {
        i++;
      }
      final startB = j;
      while (j < lowerB.length && _isAsciiDigit(lowerB.codeUnitAt(j))) {
        j++;
      }
      final numberA = int.tryParse(lowerA.substring(startA, i)) ?? 0;
      final numberB = int.tryParse(lowerB.substring(startB, j)) ?? 0;
      if (numberA != numberB) return numberA < numberB ? -1 : 1;
      final lengthA = i - startA;
      final lengthB = j - startB;
      if (lengthA != lengthB) return lengthA < lengthB ? -1 : 1;
      continue;
    }
    if (codeA != codeB) return codeA < codeB ? -1 : 1;
    i++;
    j++;
  }
  final restA = lowerA.length - i;
  final restB = lowerB.length - j;
  if (restA != restB) return restA < restB ? -1 : 1;
  return a.compareTo(b);
}

/// 校验用户输入的新文本文件名。
///
/// 返回 null 表示合法，否则返回可直接显示给用户的中文原因。
/// Windows 比 Android 严格，这里按 Windows 的规则卡，两个平台都能过。
String? validateNewTextName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return '文件名不能为空';
  if (name == '.' || name == '..') return '这个文件名无效';
  if (name.length > 100) return '文件名太长（最多 100 个字符）';
  if (RegExp(r'[\\/:*?"<>|]').hasMatch(name)) {
    return r'文件名不能包含 \ / : * ? " < > | 这些字符';
  }
  if (RegExp(r'[\x00-\x1F]').hasMatch(name)) return '文件名里有不可见字符';

  var base = name;
  if (hasTxtExtension(base)) {
    base = base.substring(0, base.length - 4);
  }
  if (base.trim().isEmpty) return '文件名不能为空';
  if (base.endsWith('.') || base.endsWith(' ')) {
    return '文件名不能以点号或空格结尾';
  }
  if (_reservedWindowsNames.contains(base.toUpperCase())) {
    return '「$base」是 Windows 保留名，请换一个';
  }
  return null;
}
