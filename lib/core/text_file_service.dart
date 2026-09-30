import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_names.dart';

/// 新建 TXT 的结果。
class CreateTextResult {
  const CreateTextResult({required this.file, required this.created});

  final File file;

  /// false 表示同名文件本来就存在。
  final bool created;
}

/// 纯文本读写。全程 UTF-8，不加 BOM。
class TextFileService {
  const TextFileService._();

  static const String _tempSuffix = '.dtn-tmp';

  static Future<bool> exists(String path) => File(path).exists();

  static Future<String> read(File file) async {
    if (!await file.exists()) return '';
    try {
      final bytes = await file.readAsBytes();
      return decode(bytes);
    } on FileSystemException {
      return '';
    }
  }

  /// 把字节解成字符串：跳过 UTF-8 BOM，坏字节用替换字符兜住，
  /// 这样误存的其它编码文件也不会让程序崩掉（内容会显示成乱码，但可编辑可覆盖保存）。
  static String decode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    if (start >= bytes.length) return '';
    final slice = start == 0 ? bytes : bytes.sublist(start);
    return utf8.decode(slice, allowMalformed: true);
  }

  /// 保存文本。先写临时文件再改名：Dart 的 `File.rename` 在 Android（rename(2)）
  /// 和 Windows（MoveFileEx + REPLACE_EXISTING）上都会替换同名目标，
  /// 所以这一步就是原子覆盖，写一半断电也不会毁掉原文。
  static Future<void> write(File file, String content) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final temp = File('${file.path}$_tempSuffix');
    await temp.writeAsString(content, flush: true);
    try {
      await temp.rename(file.path);
      return;
    } on FileSystemException {
      // 目标被别的程序占用等原因失败：退回直接覆盖写。
      // 注意绝不先删原文件——删了再改名失败就真丢内容了。
    }
    await file.writeAsString(content, flush: true);
    if (await temp.exists()) {
      try {
        await temp.delete();
      } on FileSystemException {
        // 临时文件删不掉也无所谓，下次会被覆盖。
      }
    }
  }

  /// 在文本文件夹里新建一个 TXT。同名已存在时不覆盖，只返回它。
  static Future<CreateTextResult> create(String folder, String rawName) async {
    final fileName = ensureTxtExtension(rawName);
    final file = File(p.join(folder, fileName));
    if (await file.exists()) {
      return CreateTextResult(file: file, created: false);
    }
    await write(file, '');
    return CreateTextResult(file: file, created: true);
  }

  /// 文件名是否已经被文本文件夹里的某个文件占用。
  static Future<bool> nameTaken(String folder, String rawName) async {
    final fileName = ensureTxtExtension(rawName);
    return File(p.join(folder, fileName)).exists();
  }
}
