# v1.0.0 — 跨端听写记事本 / Cross Dictation Notepad

第一个可用版本。播放本地视频，同时把原文听写进纯文本文件；Android 手机 + Windows 电脑同一套代码。

First working release. Play a local video while dictating the source text into a plain `.txt`;
one codebase for Android phones and Windows PCs.

最初のリリース。ローカル動画を再生しながら原文をプレーンテキストに聴写。Android と Windows を
1 つのコードでカバーします。

---

## 下载 / Downloads / ダウンロード

| 平台 | 文件 |
| --- | --- |
| Android 手机 | `dictation-notepad-android-release.apk`（直接安装；首次选文件夹时请允许「所有文件访问」） |
| Windows 电脑 | `dictation-notepad-windows-x64.zip`（解压后双击 `dictation_notepad.exe`；需要把整个文件夹一起复制） |

> Android APK 用调试证书签名（Flutter 模板默认），可以直装，不适合上架商店。
> The Android APK is signed with the Android debug key (Flutter's default): sideload it, don't publish it.

## 这个版本有什么 / Highlights

- 用户指定「视频文件夹」与「文本文件夹」，软件只读这两个文件夹，路径记忆、设置里可改
- 视频：media_kit / libmpv 本地播放，`-5s -3s -1s ⏯ +1s +3s +5s`，0.25x–2x 八档倍速，只读进度条 + 时间，全屏横屏
- 编辑：纯 TXT，撤销 / 重做 / 查找替换（大小写开关、全部替换）/ 自动保存，状态栏字数·行数·光标
- 布局：手机竖屏与电脑宽屏都是上视频下编辑；侧边栏含撤销/重做/查找替换/保存/设置/两个文件夹
- 恢复：下次启动自动回到上次的视频、播放进度、倍速、光标位置、日夜模式（存在软件内部配置，不写工作文件夹）
- 无网络、无同步、无导入导出、无时间轴、无字幕格式

## 实测状态 / Verified

- `flutter analyze`：**No issues found!**（零 error / warning / info）
- `flutter test`：**61/61 通过**
- `flutter build apk --release`：✅ 成功（含 `libmpv.so` 三个 ABI，`libapp.so` AOT）
- Windows 桌面版依赖 Visual Studio（MSVC），构建脚本见 `tool/build_windows.ps1`
- 真机 UI 尚未逐项点过，手工测试清单见 `docs/测试清单.md`

## 注意 / Notes

- **项目路径请用纯英文（ASCII）**：路径含中文会导致 `flutter analyze` 崩溃、release 构建失败
  （AOT 编译器读不到 `app.dill`）。详见 README。
- Android 需要「所有文件访问」权限（`MANAGE_EXTERNAL_STORAGE`），因此不适合上架 Google Play。
- 文本一律 UTF-8 读写。

**完整中文说明：[README.md](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.md) ·
English: [README.en.md](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.en.md) ·
日本語: [README.ja.md](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.ja.md)**
