# v1.0.4 — 跨端听写记事本 / Cross Dictation Notepad

## 新增：支持音频文件 / New: audio files are supported

有些听写素材本来就是音频（从直播/一图流里扒下来的 `.m4a`、`.mp3` 等），以前它们
根本不会出现在列表里（只按视频扩展名过滤）。现在：

- **「视频文件夹」改叫「视频/音频文件夹」**，里面既列视频也列音频；
- 认这些音频扩展名：`mp3 / m4a / m4b / aac / flac / wav / ogg / oga / opus / wma /
  mka / ape / aiff / aif / amr / wv / tta`（都是 mpv 能直接播的）；
- 播放纯音频时，上方**不再是一块黑框**，而是显示一块「♪ 音频播放中 + 文件名」的面板，
  下面那排 `±1s / ±3s / ±5s`、倍速、**可拖动的进度条**全部照常可用；
- 拖进度、调速、恢复上次进度、自动保存等等，对音频和视频完全一样。

> 视频容器里本来就没有画面轨的文件（比如只封了音轨的 mp4），扩展名判定不出音频，
> 会显示正常的播放区；如果你碰到这种文件想让它也走音频面板，告诉我再加"无视频轨自动识别"。

## 其它 / Other

- 版本号 1.0.3+4 → 1.0.4+5。
- 新增 `test/audio_extensions_test.dart`（5 组用例：常见音频格式、视频/文本不算音频、
  媒体判定、界面提示含音频格式、原有视频判定没被影响）。
- `flutter analyze` 零问题、`flutter test` **70/70** 全绿。

## 下载 / Downloads

| 平台 | 文件 |
| --- | --- |
| Android 手机 | `dictation-notepad-android-release.apk` |
| Windows 电脑 | `dictation-notepad-windows-x64.zip`（解压后双击 `dictation_notepad.exe`，整目录一起用） |
## 文件校验（SHA-256）/ Checksums

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| dictation-notepad-android-release.apk | 146.8 MB | `dc3a5d6e8f525cd8927a18564863216b0662d23a53c260e8aa9149f2846b4af2` |
| dictation-notepad-windows-x64.zip | 30.7 MB | `19dead843eaabea559eff66929ef1c924ca554c3efa7eb43ff520b664e8f0d07` |

Windows 上核对：`Get-FileHash .\dictation-notepad-android-release.apk -Algorithm SHA256`
## 许可证 / License

本项目采用 **MIT 许可证**（见仓库根目录 `LICENSE`）。第三方依赖保留各自许可证；
打包产物内含 libmpv（mpv）二进制，分发时请一并遵守其许可证。
