# v1.0.1 — 跨端听写记事本 / Cross Dictation Notepad

修一个致命 bug：**视频只有声音、画面全黑**（Windows 与 Android 都受影响）。
Fix for a critical bug: **video played audio but showed a black picture** (both Windows and Android).
致命的なバグ修正：**音声は出るのに映像が真っ黒**（Windows / Android 共通）。

如果你已经装了 v1.0.0，请换成这里的 v1.0.1 —— v1.0.0 的播放器画面是画不出来的。

---

## 修了什么 / What was fixed

**现象**：视频有声音、进度条和倍速都正常、播放也没报错，但画面区域一直是黑的。

**根因**（我自己代码的时序 bug，不是显卡/编码/系统的问题）：

media_kit 的原生实现只**订阅** `player.stream.videoParams` 事件、**不读当前值**：

```dart
videoParamsSubscription = player.stream.videoParams.listen(
  (event) => ... VideoOutputManager.SetSize(width, height) ...,
);
```

而我原本把 `VideoController` 写成 `late final controller = VideoController(...)`，
也就是等 `Video` 控件第一次构建时才创建；偏偏 `_bootstrap()` 的第一步是
`await Future<void>.delayed(Duration.zero)`，它只让出**事件循环**、并不保证首帧已经构建 ——
于是 `player.open()` 可能早于 controller 创建，那条「视频尺寸」事件被永久错过，
纹理尺寸停在 **0×0**，而 media_kit 的 `VideoTexture` 在尺寸 ≤ 1 时直接什么都不画。

**修复**：把 `VideoController` 的创建放进 `PlayerSession` 构造函数，保证订阅先于任何 `open()`。

**验证**：修复前日志里只有 `{..., rect: {height: 0, left: 0, top: 0, width: 0}}`；
修复后同一位置多出 `640 360`（测试视频的真实分辨率，说明 `VideoOutputManager.SetSize` 被正确调用）。

## 其它改动 / Other changes

- `media_kit_video` 由 `^1.2.0` 升到 `^2.0.0`（实际锁定 2.0.1）：
  1.x 的更新日志最晚只到 Flutter 3.37 左右，而 2.0.0 写明 `feat: flutter 3.38.x support`、
  2.0.1 是 `fix: flutter 3.38.x crash`；本项目用 Flutter 3.47.5，属于它声明支持的区间。
- 设置里新增「**视频渲染兼容模式**」（默认关闭）：极少数环境下若仍黑屏，可打开它改用 CPU 软件渲染。
- 版本号 1.0.0+1 → 1.0.1+2。

## 下载 / Downloads

| 平台 | 文件 |
| --- | --- |
| Android 手机 | `dictation-notepad-android-release.apk`（直接安装；首次选文件夹时请允许「所有文件访问」） |
| Windows 电脑 | `dictation-notepad-windows-x64.zip`（解压后双击 `dictation_notepad.exe`，整目录一起用） |

> Android APK 用调试证书签名（Flutter 模板默认），可以直装，不适合上架商店。
> The Android APK is signed with the Android debug key: sideload it, don't publish it.

**说明文档：[中文 README](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.md) ·
[English](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.en.md) ·
[日本語](https://github.com/rin-7777777/cross-dictation-notepad/blob/main/README.ja.md)**
