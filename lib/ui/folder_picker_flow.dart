import 'package:flutter/material.dart';

import '../core/folder_service.dart';
import '../core/settings_store.dart';

/// 「申请存储权限 → 打开系统目录选择器」的公共流程。
///
/// 返回用户选中的文件夹路径；取消、或者没拿到权限时返回 null。
Future<String?> pickFolderFlow(
  BuildContext context, {
  required String dialogTitle,
  String? initialDirectory,
}) async {
  final access = await FolderService.ensureStorageAccess();
  if (!context.mounted) return null;

  if (access != StorageAccessResult.granted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要存储权限'),
        content: Text(
          access == StorageAccessResult.permanentlyDenied
              ? 'Android 需要「所有文件访问」权限，才能在重启之后依然按路径读写你选择的文件夹。\n\n'
                  '请到「系统设置 → 应用 → 听写记事本 → 权限」里打开「所有文件访问」'
                  '（Android 10 及以下打开「存储」），然后回来重新选择文件夹。'
              : '这次没有拿到存储权限，暂时读不到文件夹内容。请再试一次，'
                  '并在系统弹窗里选择「允许」。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
          if (access == StorageAccessResult.permanentlyDenied)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                FolderService.openSystemSettings();
              },
              child: const Text('去系统设置'),
            ),
        ],
      ),
    );
    return null;
  }

  final String? picked;
  try {
    picked = await FolderService.pickFolder(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  } on UnsupportedFolderException catch (error) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('这个位置不支持'),
        content: Text(
          '系统给回的是「${error.path}」，不是软件能直接读写的真实文件夹路径。\n\n'
          '请换一个位置再试一次。推荐用手机内部存储里的文件夹'
          '（例如内部存储根目录、Documents、Movies 下面新建一个）。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    return null;
  }
  return picked;
}

/// 选择并保存某一个文件夹（首页 / 设置里「更改」用）。
Future<String?> changeFolderFlow(
  BuildContext context, {
  required SettingsStore store,
  required bool isVideo,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await pickFolderFlow(
    context,
    dialogTitle: isVideo ? '选择视频/音频文件夹' : '选择文本文件夹',
    initialDirectory: isVideo ? store.videoFolder : store.textFolder,
  );
  if (picked == null) return null;
  if (isVideo) {
    await store.setVideoFolder(picked);
  } else {
    await store.setTextFolder(picked);
  }
  final word = isVideo ? '视频' : '文本';
  messenger.showSnackBar(
    SnackBar(content: Text('已更新$word文件夹：$picked')),
  );
  return picked;
}
