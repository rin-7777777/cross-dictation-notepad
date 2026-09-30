import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'file_names.dart';

/// Android 存储授权的结论。
enum StorageAccessResult {
  /// 已经可以长期读写用户选择的文件夹。
  granted,

  /// 这次被拒绝，还可以再问。
  denied,

  /// 被“不再询问”拒绝，只能去系统设置里开。
  permanentlyDenied,
}

/// 用户选到了 dart:io 和 libmpv 都用不了的位置
/// （典型情况：file_picker 在 Android 上没能把 SAF 的 tree URI 反解成真实路径）。
class UnsupportedFolderException implements Exception {
  const UnsupportedFolderException(this.path);

  final String path;

  @override
  String toString() => '不支持的位置：$path';
}

/// 文件夹里的一个文件条目。
class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });

  final String path;
  final String name;
  final int size;
  final DateTime modified;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// 文件夹授权与列表。
///
/// Android 上使用“所有文件访问”（MANAGE_EXTERNAL_STORAGE）而不是只拿 SAF 的
/// 一次性授权，原因是：
///   1. 只有真实路径才能被 libmpv（media_kit）直接打开，SAF 的 content:// 不行；
///   2. 重启之后仍然能按路径访问，不需要用户每次重新授权；
///   3. Android 与 Windows 的代码路径完全一致，只用 dart:io。
class FolderService {
  const FolderService._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Android 系统版本号；解析不到时返回 0。
  static int get _apiLevel {
    final match = RegExp(r'API level (\d+)')
        .firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  /// Android：申请长期存储访问权限。其它平台直接算通过。
  static Future<StorageAccessResult> ensureStorageAccess() async {
    if (!isAndroid) return StorageAccessResult.granted;

    // Android 10（API 29）及以下没有「所有文件访问」，普通存储权限就够。
    final apiLevel = _apiLevel;
    if (apiLevel > 0 && apiLevel < 30) {
      final legacy = await Permission.storage.request();
      if (legacy.isGranted) return StorageAccessResult.granted;
      return legacy.isPermanentlyDenied
          ? StorageAccessResult.permanentlyDenied
          : StorageAccessResult.denied;
    }

    if (await Permission.manageExternalStorage.isGranted) {
      return StorageAccessResult.granted;
    }
    final modern = await Permission.manageExternalStorage.request();
    if (modern.isGranted) return StorageAccessResult.granted;

    // 「所有文件访问」只能在系统设置里手动打开：permission_handler 在 Android 11+
    // 不会把它判成 permanentlyDenied（它直接读 isExternalStorageManager）。
    // 所以这里直接按「必须去系统设置」处理，界面上才会给出那个入口，
    // 否则用户会卡在「再试一次」的死循环里。
    return StorageAccessResult.permanentlyDenied;
  }

  /// 打开系统目录选择器。用户取消时返回 null；
  /// 选到的位置不是真实绝对路径时抛 [UnsupportedFolderException]。
  static Future<String?> pickFolder({
    required String dialogTitle,
    String? initialDirectory,
  }) async {
    String? start = initialDirectory;
    if (start != null && !Directory(start).existsSync()) {
      start = null;
    }
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: start,
      lockParentWindow: true,
    );
    if (selected == null) return null;
    final trimmed = selected.trim();
    if (trimmed.isEmpty) return null;
    // Android 上 file_picker 偶尔会返回 content:// 的 tree URI（部分 SD 卡 /
    // 第三方 DocumentsProvider 反解不出真实路径），dart:io 与 libmpv 都用不了。
    if (trimmed.contains('://') || !p.isAbsolute(trimmed)) {
      throw UnsupportedFolderException(trimmed);
    }
    return trimmed;
  }

  /// Android：当前是否真的能访问用户选的文件夹。
  static Future<bool> hasStorageAccess() async {
    if (!isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    return Permission.storage.isGranted;
  }

  static Future<void> openSystemSettings() async {
    if (isAndroid) await openAppSettings();
  }

  /// 列出「视频/音频文件夹」里的视频与音频文件。
  static Future<List<FileEntry>> listMedia(String folder) =>
      _list(folder, hasMediaExtension);

  /// 列出文本文件夹里的 .txt。
  static Future<List<FileEntry>> listTexts(String folder) =>
      _list(folder, hasTxtExtension);

  static Future<List<FileEntry>> _list(
    String folder,
    bool Function(String name) accept,
  ) async {
    final directory = Directory(folder);
    if (!await directory.exists()) return const <FileEntry>[];

    final result = <FileEntry>[];
    // 不吞掉 FileSystemException：上层要能区分「文件夹是空的」和「读不到」。
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.isEmpty || name.startsWith('.')) continue;
      if (name.endsWith('.dtn-tmp')) continue;
      if (!accept(name)) continue;
      var size = 0;
      var modified = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final stat = await entity.stat();
        size = stat.size;
        modified = stat.modified;
      } catch (_) {
        // 读不到大小也照样列出来，播放时再报错。
      }
      result.add(FileEntry(
        path: entity.path,
        name: name,
        size: size,
        modified: modified,
      ));
    }

    result.sort((a, b) => compareNatural(a.name, b.name));
    return result;
  }
}
